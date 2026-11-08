import 'package:flutter/material.dart';

import '../models/academic_class.dart';
import '../models/class_timetable.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../services/timetable_service.dart';
import '../widgets/academic_image.dart';

/// Full-featured Teacher Timetable Editor for managing 6-day recurring weekly schedules (Module M2).
/// Enforces: 8 periods × 45 min each + 30 min break, derived end times, overlap/chronology checks,
/// draft/publish workflows, version history and restoration.
class TeacherTimetableEditorScreen extends StatefulWidget {
  final String classId;
  final String? initialDay;
  final AcademicClass? academicClass;

  /// Enables one-day override mode immediately. Production callers leave this
  /// null and pick a date through the editor; tests use it to avoid driving the
  /// platform date picker.
  final DateTime? initialOverrideDate;

  const TeacherTimetableEditorScreen({
    super.key,
    required this.classId,
    this.initialDay,
    this.academicClass,
    this.initialOverrideDate,
  });

  @override
  State<TeacherTimetableEditorScreen> createState() =>
      _TeacherTimetableEditorScreenState();
}

class _TeacherTimetableEditorScreenState
    extends State<TeacherTimetableEditorScreen> {
  final TimetableService _timetableService = TimetableService();
  late String _selectedDay;
  late DateTime _effectiveFrom;
  int _breakAfterPeriod = kDefaultBreakAfterPeriod;
  int _breakStartMinute = 645; // 10:45 AM
  final List<_SlotController> _slotControllers = [];
  bool _saving = false;
  AcademicClass? _resolvedClass;
  bool _canEdit = false;
  DateTime? _overrideDate;

  bool get _isOverrideMode => _overrideDate != null;

  @override
  void initState() {
    super.initState();
    final initialOverride = widget.initialOverrideDate;
    if (initialOverride != null && initialOverride.weekday != DateTime.friday) {
      _overrideDate = DateTime(
        initialOverride.year,
        initialOverride.month,
        initialOverride.day,
      );
    }

    if (_overrideDate != null) {
      _selectedDay = timetableDayForWeekday(_overrideDate!.weekday);
    } else if (widget.initialDay != null &&
        kTimetableWeekDays.contains(widget.initialDay)) {
      _selectedDay = widget.initialDay!;
    } else {
      _selectedDay = kTimetableWeekDays.first;
    }

    final now = DateTime.now();
    _effectiveFrom = _overrideDate ?? DateTime(now.year, now.month, now.day);
    _resolvedClass = widget.academicClass ??
        AuthService.getCachedAcademicClasses().cast<AcademicClass?>().firstWhere(
              (c) => c?.classId.toUpperCase() == widget.classId.toUpperCase(),
              orElse: () => null,
            );

    // Rules remain the backstop, but the editor must not offer Save/Publish to
    // an unassigned teacher (Acceptance Test 35). No fallback class is used.
    _canEdit = HierarchyService.canEditTimetable(
      profile: AuthService.getCachedProfile(),
      classId: widget.classId,
      academicClass: _resolvedClass,
    );

    _loadDayVersion(_selectedDay, overrideDate: _overrideDate);
  }

  void _loadDayVersion(String day, {DateTime? overrideDate}) {
    for (final c in _slotControllers) {
      c.dispose();
    }
    _slotControllers.clear();

    final history = _timetableService.getCachedVersions(widget.classId, day);
    final recurring = history.where((v) => !v.isTemporary).toList()
      ..sort((a, b) => b.version.compareTo(a.version));

    ClassTimetableVersion? current;
    if (overrideDate != null) {
      final matching = history
          .where((v) => _isSameDate(v.overrideDate, overrideDate))
          .toList()
        ..sort((a, b) => b.version.compareTo(a.version));
      if (matching.isNotEmpty) {
        current = matching.first;
      } else {
        current = ClassTimetableVersion.activeForDate(recurring, overrideDate) ??
            (recurring.isNotEmpty ? recurring.first : null);
      }
    } else {
      current = recurring.isNotEmpty ? recurring.first : null;
    }

    current ??= ClassTimetableVersion.template(
      classId: widget.classId,
      dayOfWeek: day,
      effectiveFrom: overrideDate ?? _effectiveFrom,
    );

    _overrideDate = overrideDate;
    _breakAfterPeriod = current.breakAfterPeriod;
    _breakStartMinute = current.breakStartMinute >= 0 ? current.breakStartMinute : 645;
    _effectiveFrom = overrideDate ?? current.effectiveFrom;

    final sortedSlots = [...current.slots]
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

    // Ensure exactly 8 slot controllers
    for (var i = 1; i <= kTeachingPeriodCount; i++) {
      final existing = sortedSlots.cast<TimetableSlot?>().firstWhere(
            (s) => s?.periodNumber == i,
            orElse: () => null,
          );
      _slotControllers.add(_SlotController(
        periodNumber: i,
        startMinute: existing?.startMinute ?? (465 + (i - 1) * 45),
        subject: existing?.subject ?? '',
        teacherName: existing?.teacherName ?? '',
        teacherUid: existing?.teacherUid ?? '',
        room: existing?.room ?? '',
        imageUrl: existing?.imageUrl ?? '',
        notes: existing?.notes ?? '',
        substituteTeacherName: existing?.substituteTeacherName ?? '',
        substituteTeacherUid: existing?.substituteTeacherUid ?? '',
      ));
    }

    if (mounted) setState(() {});
  }

  static bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  ClassTimetableVersion _buildCurrentVersion({String status = TimetableStatus.draft, int versionNumber = 1}) {
    final profile = AuthService.getCachedProfile();
    final uid = (profile?['uid'] ?? profile?['id'] ?? '').toString();
    final name = (profile?['full_name'] ?? profile?['name'] ?? 'Class Teacher').toString();

    var slots = _slotControllers.map((c) => c.toSlot()).toList();
    if (_overrideDate == null) {
      // Substitutions are date-specific and must never leak into a recurring
      // weekly version.
      slots = slots
          .map((s) => s.copyWith(
                substituteTeacherName: '',
                substituteTeacherUid: '',
              ))
          .toList();
    }

    return ClassTimetableVersion(
      classId: widget.classId,
      dayOfWeek: _selectedDay,
      status: status,
      effectiveFrom: _overrideDate ?? _effectiveFrom,
      version: versionNumber,
      breakAfterPeriod: _breakAfterPeriod,
      breakStartMinute: _breakStartMinute,
      slots: slots,
      createdByUid: uid,
      createdByName: name,
      overrideDate: _overrideDate,
    );
  }

  void _applyStandardTimes() {
    final template = ClassTimetableVersion.template(
      classId: widget.classId,
      dayOfWeek: _selectedDay,
      dayStartMinute: 465, // 07:45
      breakAfterPeriod: _breakAfterPeriod,
      effectiveFrom: _effectiveFrom,
    );

    _breakStartMinute = template.breakStartMinute;
    for (var i = 0; i < _slotControllers.length; i++) {
      if (i < template.slots.length) {
        _slotControllers[i].startMinute = template.slots[i].startMinute;
      }
    }
    setState(() {});
  }

  Future<void> _pickStartTime(_SlotController controller) async {
    final initialTime = controller.startMinute >= 0
        ? TimeOfDay(
            hour: (controller.startMinute ~/ 60) % 24,
            minute: controller.startMinute % 60,
          )
        : const TimeOfDay(hour: 7, minute: 45);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select Start Time for Period ${controller.periodNumber}',
    );

    if (picked != null) {
      setState(() {
        controller.startMinute = picked.hour * 60 + picked.minute;
      });
    }
  }

  Future<void> _pickBreakStartTime() async {
    final initialTime = _breakStartMinute >= 0
        ? TimeOfDay(
            hour: (_breakStartMinute ~/ 60) % 24,
            minute: _breakStartMinute % 60,
          )
        : const TimeOfDay(hour: 10, minute: 45);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select Break Start Time (30 Minutes Fixed)',
    );

    if (picked != null) {
      setState(() {
        _breakStartMinute = picked.hour * 60 + picked.minute;
      });
    }
  }

  Future<void> _pickEffectiveDate() async {
    if (_isOverrideMode) {
      await _pickOverrideDate();
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Effective Starting Date',
    );
    if (picked != null) {
      setState(() => _effectiveFrom = picked);
    }
  }

  Future<void> _pickOverrideDate() async {
    final firstDate = DateTime(2026, 1, 1);
    final lastDate = DateTime(2030, 12, 31);
    var initialDate = _overrideDate ?? DateTime.now();
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'One-Day Override Date',
    );
    if (picked == null || !mounted) return;

    if (picked.weekday == DateTime.friday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Friday is not a school day. Choose Saturday to Thursday.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final day = timetableDayForWeekday(picked.weekday);
    _selectedDay = day;
    _loadDayVersion(
      day,
      overrideDate: DateTime(picked.year, picked.month, picked.day),
    );
  }

  void _exitOverrideMode() {
    _overrideDate = null;
    _loadDayVersion(_selectedDay);
  }

  Future<void> _handleSaveDraft() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not assigned to edit this class timetable.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final current = _buildCurrentVersion(status: TimetableStatus.draft);
    final errors = current.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot save invalid draft: ${errors.first}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final profile = AuthService.getCachedProfile();
    final uid = (profile?['uid'] ?? profile?['id'] ?? '').toString();
    final name = (profile?['full_name'] ?? profile?['name'] ?? 'Class Teacher').toString();

    setState(() => _saving = true);
    bool ok;
    if (_isOverrideMode) {
      final saved = await _timetableService.saveTimetableOverride(
        current,
        date: _overrideDate!,
        actorUid: uid,
        actorName: name,
        publish: false,
      );
      ok = saved != null;
    } else {
      ok = await _timetableService.saveTimetableDraft(current);
    }

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        _loadDayVersion(_selectedDay, overrideDate: _overrideDate);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? _isOverrideMode
                  ? 'One-day override draft for ${_dateLabel(_overrideDate!)} saved!'
                  : 'Draft for ${widget.classId} · $_selectedDay saved successfully!'
              : 'Failed to save draft. Check permissions.'),
          backgroundColor: ok ? const Color(0xFF10B981) : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handlePublishOrSubmit() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not assigned to publish this class timetable.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final profile = AuthService.getCachedProfile();
    final uid = (profile?['uid'] ?? profile?['id'] ?? '').toString();
    final name = (profile?['full_name'] ?? profile?['name'] ?? 'Class Teacher').toString();

    final requiresApproval = _resolvedClass?.timetableRequiresApproval == true;
    final isSenior = HierarchyService.isSeniorAdmin(
      scholarNo: profile?['scholar_no']?.toString(),
      role: profile?['role']?.toString(),
    );

    final history = _timetableService.getCachedVersions(widget.classId, _selectedDay);
    var nextVersionNum = 1;
    for (final v in history) {
      if (v.version >= nextVersionNum) nextVersionNum = v.version + 1;
    }

    final current = _buildCurrentVersion(
      status: (requiresApproval && !isSenior)
          ? TimetableStatus.submitted
          : TimetableStatus.published,
      versionNumber: nextVersionNum,
    );

    final errors = current.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Validation issue: ${errors.first}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Cross-class double-booking preflight (M3 tests 18–19). The service also
    // enforces this inside publishTimetable, but checking here lets us show the
    // exact teacher/room conflict before attempting a write.
    final checkDate = _overrideDate ?? _effectiveFrom;
    List<TimetableConflict> conflicts;
    try {
      conflicts = await _timetableService.findTimetableConflicts(
        current,
        date: checkDate,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify teacher/room conflicts. Try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    if (conflicts.isNotEmpty) {
      await _showConflictDialog(conflicts);
      return;
    }

    setState(() => _saving = true);
    bool ok;
    if (_isOverrideMode) {
      if (requiresApproval && !isSenior) {
        ok = await _timetableService.submitTimetable(current);
      } else {
        final saved = await _timetableService.saveTimetableOverride(
          current,
          date: _overrideDate!,
          actorUid: uid,
          actorName: name,
          publish: true,
        );
        ok = saved != null;
      }
    } else if (requiresApproval && !isSenior) {
      ok = await _timetableService.submitTimetable(current);
    } else {
      ok = await _timetableService.publishTimetable(
        current,
        publisherUid: uid,
        publisherName: name,
      );
    }

    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        _loadDayVersion(_selectedDay, overrideDate: _overrideDate);
        final String successMessage;
        if (_isOverrideMode) {
          successMessage = requiresApproval && !isSenior
              ? 'One-day override for ${_dateLabel(_overrideDate!)} submitted for principal review.'
              : 'One-day override for ${_dateLabel(_overrideDate!)} published!';
        } else {
          successMessage = requiresApproval && !isSenior
              ? 'Timetable submitted for principal review.'
              : 'Version $nextVersionNum published and recurring live!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operation failed. Check permissions and network.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _showConflictDialog(List<TimetableConflict> conflicts) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('timetable_conflict_dialog'),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('${conflicts.length} Scheduling Conflict${conflicts.length == 1 ? '' : 's'}'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resolve these teacher or room double-bookings before publishing:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...conflicts.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• ${c.message}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkConflicts() async {
    final current = _buildCurrentVersion();
    final checkDate = _overrideDate ?? _effectiveFrom;
    try {
      final conflicts = await _timetableService.findTimetableConflicts(
        current,
        date: checkDate,
      );
      if (conflicts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No teacher or room conflicts found.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        return;
      }
      await _showConflictDialog(conflicts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify teacher/room conflicts. Try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _showCopyToDaysDialog() async {
    if (_isOverrideMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exit one-day override mode before copying a recurring day.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final source = _buildCurrentVersion();
    final targets = <String>{};
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final otherDays =
              kTimetableWeekDays.where((d) => d != _selectedDay).toList();
          return AlertDialog(
            key: const Key('copy_timetable_dialog'),
            title: Text('Copy $_selectedDay Configuration'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Copy all 8 periods and the break to the selected days. '
                      'Each target receives a new draft; existing schedules are never overwritten.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ...otherDays.map((day) {
                      final existing = _timetableService
                          .getCachedRecurringActiveVersion(
                        widget.classId,
                        day,
                        _effectiveFrom,
                      );
                      return CheckboxListTile(
                        key: Key('copy_target_$day'),
                        value: targets.contains(day),
                        onChanged: (value) {
                          setLocalState(() {
                            if (value == true) {
                              targets.add(day);
                            } else {
                              targets.remove(day);
                            }
                          });
                        },
                        title: Text(
                          day,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          existing == null
                              ? 'No published schedule yet'
                              : 'Published v${existing.version} stays live until the new draft is published',
                          style: const TextStyle(fontSize: 11),
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('copy_timetable_confirm_button'),
                onPressed: targets.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, targets.toList()),
                child: Text(
                  'Copy to ${targets.length} Day${targets.length == 1 ? '' : 's'}',
                ),
              ),
            ],
          );
        },
      ),
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    final profile = AuthService.getCachedProfile();
    final uid = (profile?['uid'] ?? profile?['id'] ?? '').toString();
    final name = (profile?['full_name'] ?? profile?['name'] ?? 'Class Teacher').toString();

    setState(() => _saving = true);
    final results = await _timetableService.copyTimetableToDays(
      source: source,
      targetDays: selected,
      actorUid: uid,
      actorName: name,
    );
    if (!mounted) return;

    setState(() => _saving = false);
    final successes =
        results.entries.where((e) => e.value).map((e) => e.key).toList();
    final failures =
        results.entries.where((e) => !e.value).map((e) => e.key).toList();

    final message = failures.isEmpty
        ? 'Copied to ${successes.join(', ')} as drafts. Publish each day to make it live.'
        : successes.isEmpty
            ? 'Copy failed for ${failures.join(', ')}. Check permissions.'
            : 'Copied to ${successes.join(', ')}; failed: ${failures.join(', ')}.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            successes.isEmpty ? Colors.redAccent : const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _assignSubstitute(_SlotController slotController) async {
    if (!_isOverrideMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable One-Day Override to assign a substitute.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selection = await showDialog<({String name, String uid})>(
      context: context,
      builder: (ctx) => _SubstituteDialog(
        periodNumber: slotController.periodNumber,
        regularTeacher: slotController.teacherController.text.trim(),
        initialName: slotController.substituteTeacherName,
        initialUid: slotController.substituteTeacherUid,
      ),
    );

    if (selection != null) {
      setState(() {
        slotController.substituteTeacherName = selection.name;
        slotController.substituteTeacherUid = selection.uid;
      });
    }
  }

  void _clearSubstitute(_SlotController slotController) {
    setState(() {
      slotController.substituteTeacherName = '';
      slotController.substituteTeacherUid = '';
    });
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final versions = _timetableService.getCachedVersions(widget.classId, _selectedDay);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${widget.classId} · $_selectedDay Versions',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                if (versions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No previous versions saved.')),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: versions.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final v = versions[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Version ${v.version} · ${v.status.toUpperCase()}'
                            '${v.isTemporary ? ' · ONE-DAY OVERRIDE' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Effective: ${v.effectiveFrom.toIso8601String().split('T').first} '
                            '${v.isTemporary ? '• Override ${v.overrideDate != null ? _dateLabel(v.overrideDate!) : ''} ' : ''}'
                            '${v.createdByName.isNotEmpty ? '• By ${v.createdByName}' : ''}',
                          ),
                          trailing: FilledButton.tonal(
                            key: Key('restore_version_${v.version}'),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final profile = AuthService.getCachedProfile();
                              final uid = (profile?['uid'] ?? profile?['id'] ?? '').toString();
                              final name = (profile?['full_name'] ?? profile?['name'] ?? 'Class Teacher').toString();

                              final restored = await _timetableService.restoreTimetableVersion(
                                targetVersion: v,
                                newEffectiveFrom: DateTime.now(),
                                actorUid: uid,
                                actorName: name,
                                publishImmediately: true,
                              );
                              if (restored != null && mounted) {
                                _loadDayVersion(_selectedDay);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Restored as Version ${restored.version}!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            },
                            child: const Text('Restore', style: TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullWeekPreview() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${widget.classId} 6-Day Timetable Preview'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: kTimetableWeekDays.map((day) {
                final v = _timetableService.getCachedRecurringActiveVersion(
                  widget.classId,
                  day,
                  _effectiveFrom,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      if (v == null)
                        const Text('No published schedule.', style: TextStyle(color: Colors.grey, fontSize: 12))
                      else
                        ...v.slots.map(
                          (s) => Text(
                            'P${s.periodNumber} (${s.timeSlot}): ${s.subject.isEmpty ? 'Free' : s.subject} ${s.room.isNotEmpty ? '[${s.room}]' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      const Divider(height: 16),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = _buildCurrentVersion();
    final errors = current.validate();

    final requiresApproval = _resolvedClass?.timetableRequiresApproval == true;

    if (!_canEdit) {
      return Scaffold(
        key: const Key('timetable_editor_unauthorized'),
        appBar: AppBar(title: Text('${widget.classId} Timetable Editor')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'You are not assigned to edit this class timetable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  'Ask an administrator to assign you as class teacher or timetable editor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.classId} Timetable Editor'),
        actions: [
          IconButton(
            key: const Key('copy_timetable_days_button'),
            tooltip: 'Copy Day to Selected Days',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: _showCopyToDaysDialog,
          ),
          IconButton(
            key: const Key('check_timetable_conflicts_button'),
            tooltip: 'Check Teacher/Room Conflicts',
            icon: const Icon(Icons.shield_outlined),
            onPressed: _checkConflicts,
          ),
          IconButton(
            key: const Key('timetable_override_button'),
            tooltip: _isOverrideMode ? 'Change Override Date' : 'One-Day Override',
            icon: Icon(
              _isOverrideMode
                  ? Icons.event_available_rounded
                  : Icons.event_busy_rounded,
            ),
            onPressed: _pickOverrideDate,
          ),
          IconButton(
            key: const Key('full_week_preview_button'),
            tooltip: 'Preview Full Week',
            icon: const Icon(Icons.calendar_view_week_rounded),
            onPressed: _showFullWeekPreview,
          ),
          IconButton(
            key: const Key('timetable_history_button'),
            tooltip: 'Version History',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistoryModal,
          ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. Day of Week Selector
                Container(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: kTimetableWeekDays.map((day) {
                        final isSelected = _selectedDay == day;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(day),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                _overrideDate = null;
                                setState(() {
                                  _selectedDay = day;
                                  _loadDayVersion(day);
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // One-Day Override Banner (M3)
                if (_isOverrideMode)
                  Container(
                    key: const Key('timetable_override_banner'),
                    width: double.infinity,
                    color: Colors.orange.withValues(alpha: 0.15),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy_rounded,
                            color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ONE-DAY OVERRIDE · ${_dateLabel(_overrideDate!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Only this date changes. The recurring $_selectedDay schedule stays intact.',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          key: const Key('timetable_exit_override_button'),
                          onPressed: _exitOverrideMode,
                          child: const Text('Exit Override'),
                        ),
                      ],
                    ),
                  ),

                // Approval Banner
                if (requiresApproval)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Administrative approval required for live publishing.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. Main Slots List & Timing Controls
                Expanded(
                  child: ListView(
                    key: const Key('teacher_timetable_editor_list'),
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Header with Quick Helpers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_selectedDay Configuration',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          TextButton.icon(
                            key: const Key('load_standard_timing_button'),
                            onPressed: _applyStandardTimes,
                            icon: const Icon(Icons.auto_fix_high, size: 16),
                            label: const Text('Standard 07:45', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Effective Date / One-Day Override Date Selector
                      InkWell(
                        key: const Key('timetable_effective_date_selector'),
                        onTap: _isOverrideMode
                            ? _pickOverrideDate
                            : _pickEffectiveDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _isOverrideMode
                                  ? Colors.orange.withValues(alpha: 0.6)
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isOverrideMode
                                    ? 'Override Date: ${_dateLabel(_overrideDate!)}'
                                    : 'Effective From: ${_effectiveFrom.toIso8601String().split('T').first}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Periods & Break Insertion
                      for (var i = 0; i < _slotControllers.length; i++) ...[
                        _buildPeriodCard(_slotControllers[i], isDark),
                        if (_slotControllers[i].periodNumber == _breakAfterPeriod) ...[
                          const SizedBox(height: 10),
                          _buildBreakCard(isDark),
                          const SizedBox(height: 10),
                        ] else
                          const SizedBox(height: 10),
                      ],

                      const SizedBox(height: 12),

                      // Live Validation Status Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: errors.isEmpty
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: errors.isEmpty ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  errors.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                                  color: errors.isEmpty ? Colors.green : Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  errors.isEmpty
                                      ? 'Timetable Valid (8 Periods × 45m + 30m Break)'
                                      : 'Configuration Needs Adjustment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: errors.isEmpty ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            if (errors.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              ...errors.map(
                                (err) => Text(
                                  '• $err',
                                  style: const TextStyle(fontSize: 11, color: Colors.red),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Bottom Action Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('save_timetable_draft_button'),
                          onPressed: _handleSaveDraft,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('publish_timetable_button'),
                          onPressed: errors.isEmpty ? _handlePublishOrSubmit : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            requiresApproval ? 'Submit Review' : 'Publish',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPeriodCard(_SlotController controller, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Number + Derived Timing Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF4338CA),
                      child: Text(
                        'P${controller.periodNumber}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Period ${controller.periodNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),

                // Timing Button: Start time is clickable, End time is strictly auto-derived
                InkWell(
                  key: Key('period_${controller.periodNumber}_time_button'),
                  onTap: () => _pickStartTime(controller),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${TimetableSlot.formatMinute(controller.startMinute)} - ${TimetableSlot.formatMinute(controller.endMinute)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Subject & Room Inputs
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: controller.subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: controller.roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Teacher Name & Notes
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.teacherController,
                    decoration: const InputDecoration(
                      labelText: 'Teacher Name',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller.notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Topic',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            // Date-specific substitution action (M3). Only offered inside
            // one-day override mode so recurring schedules stay untouched.
            if (_isOverrideMode) ...[
              const SizedBox(height: 8),
              if (controller.hasSubstitute)
                Container(
                  key: Key('period_${controller.periodNumber}_substitute_banner'),
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Substitute: ${controller.substituteTeacherName}'
                          '${controller.teacherController.text.trim().isNotEmpty ? ' (regular: ${controller.teacherController.text.trim()})' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key(
                          'period_${controller.periodNumber}_clear_substitute_button',
                        ),
                        tooltip: 'Clear Substitute',
                        icon: const Icon(Icons.close_rounded, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _clearSubstitute(controller),
                      ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: Key(
                      'period_${controller.periodNumber}_substitute_button',
                    ),
                    onPressed: () => _assignSubstitute(controller),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text(
                      'Assign Substitute',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],

            // Attached Photo Field
            const SizedBox(height: 6),
            AcademicImageUploadField(
              value: controller.imageUrl.isEmpty ? null : controller.imageUrl,
              label: 'Period Attachment / Board Photo',
              onChanged: (url) => controller.imageUrl = url ?? '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakCard(bool isDark) {
    final breakEndMinute = _breakStartMinute + kBreakMinutes;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.coffee_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('School Break (30 min fixed)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(
                    'After Period $_breakAfterPeriod',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            key: const Key('break_time_button'),
            onTap: _pickBreakStartTime,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    '${TimetableSlot.formatMinute(_breakStartMinute)} - ${TimetableSlot.formatMinute(breakEndMinute)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotController {
  final int periodNumber;
  int startMinute;
  String imageUrl;
  String substituteTeacherName;
  String substituteTeacherUid;
  final TextEditingController subjectController;
  final TextEditingController teacherController;
  final TextEditingController roomController;
  final TextEditingController notesController;
  final String teacherUid;

  _SlotController({
    required this.periodNumber,
    required this.startMinute,
    String subject = '',
    String teacherName = '',
    this.teacherUid = '',
    String room = '',
    this.imageUrl = '',
    String notes = '',
    this.substituteTeacherName = '',
    this.substituteTeacherUid = '',
  })  : subjectController = TextEditingController(text: subject),
        teacherController = TextEditingController(text: teacherName),
        roomController = TextEditingController(text: room),
        notesController = TextEditingController(text: notes);

  bool get hasSubstitute =>
      substituteTeacherName.trim().isNotEmpty ||
      substituteTeacherUid.trim().isNotEmpty;

  int get endMinute => startMinute < 0 ? -1 : startMinute + kTeachingPeriodMinutes;

  TimetableSlot toSlot() {
    return TimetableSlot(
      periodNumber: periodNumber,
      startMinute: startMinute,
      subject: subjectController.text.trim(),
      teacherName: teacherController.text.trim(),
      teacherUid: teacherUid,
      room: roomController.text.trim(),
      imageUrl: imageUrl.trim(),
      notes: notesController.text.trim(),
      substituteTeacherName: substituteTeacherName.trim(),
      substituteTeacherUid: substituteTeacherUid.trim(),
    );
  }

  void dispose() {
    subjectController.dispose();
    teacherController.dispose();
    roomController.dispose();
    notesController.dispose();
  }
}

/// Dialog that owns its text controllers so they outlive the closing
/// animation. Disposing them as soon as `showDialog` returns crashes the
/// still-mounted `EditableText`s during the reverse transition.
class _SubstituteDialog extends StatefulWidget {
  const _SubstituteDialog({
    required this.periodNumber,
    required this.regularTeacher,
    required this.initialName,
    required this.initialUid,
  });

  final int periodNumber;
  final String regularTeacher;
  final String initialName;
  final String initialUid;

  @override
  State<_SubstituteDialog> createState() => _SubstituteDialogState();
}

class _SubstituteDialogState extends State<_SubstituteDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _uidController =
      TextEditingController(text: widget.initialUid);

  @override
  void dispose() {
    _nameController.dispose();
    _uidController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      (name: name, uid: _uidController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('substitute_dialog'),
      title: Text('Substitute for Period ${widget.periodNumber}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.regularTeacher.isEmpty
                ? 'Regular teacher is not set.'
                : 'Regular teacher: ${widget.regularTeacher}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('substitute_name_field'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Substitute Teacher Name',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('substitute_uid_field'),
            controller: _uidController,
            decoration: const InputDecoration(
              labelText: 'Substitute UID (optional)',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The recurring weekly teacher is unchanged. This substitution applies only to the selected override date.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('substitute_confirm_button'),
          onPressed: _submit,
          child: const Text('Assign Substitute'),
        ),
      ],
    );
  }
}
