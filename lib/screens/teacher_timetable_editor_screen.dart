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

  const TeacherTimetableEditorScreen({
    super.key,
    required this.classId,
    this.initialDay,
    this.academicClass,
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

  @override
  void initState() {
    super.initState();
    _selectedDay = (widget.initialDay != null &&
            kTimetableWeekDays.contains(widget.initialDay))
        ? widget.initialDay!
        : kTimetableWeekDays.first;

    final now = DateTime.now();
    _effectiveFrom = DateTime(now.year, now.month, now.day);
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

    _loadDayVersion(_selectedDay);
  }

  void _loadDayVersion(String day) {
    for (final c in _slotControllers) {
      c.dispose();
    }
    _slotControllers.clear();

    final cachedActive = _timetableService.getCachedActiveVersion(widget.classId, day);
    final history = _timetableService.getCachedVersions(widget.classId, day);
    final current = (history.isNotEmpty ? history.first : cachedActive) ??
        ClassTimetableVersion.template(
          classId: widget.classId,
          dayOfWeek: day,
          effectiveFrom: _effectiveFrom,
        );

    _breakAfterPeriod = current.breakAfterPeriod;
    _breakStartMinute = current.breakStartMinute >= 0 ? current.breakStartMinute : 645;
    _effectiveFrom = current.effectiveFrom;

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
      ));
    }

    if (mounted) setState(() {});
  }

  ClassTimetableVersion _buildCurrentVersion({String status = TimetableStatus.draft, int versionNumber = 1}) {
    final profile = AuthService.getCachedProfile();
    final uid = (profile?['uid'] ?? profile?['id'] ?? '').toString();
    final name = (profile?['full_name'] ?? profile?['name'] ?? 'Class Teacher').toString();

    final slots = _slotControllers.map((c) => c.toSlot()).toList();

    return ClassTimetableVersion(
      classId: widget.classId,
      dayOfWeek: _selectedDay,
      status: status,
      effectiveFrom: _effectiveFrom,
      version: versionNumber,
      breakAfterPeriod: _breakAfterPeriod,
      breakStartMinute: _breakStartMinute,
      slots: slots,
      createdByUid: uid,
      createdByName: name,
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

    setState(() => _saving = true);
    final ok = await _timetableService.saveTimetableDraft(current);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Draft for ${widget.classId} · $_selectedDay saved successfully!'
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

    setState(() => _saving = true);
    bool ok;
    if (requiresApproval && !isSenior) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(requiresApproval && !isSenior
                ? 'Timetable submitted for principal review.'
                : 'Version $nextVersionNum published and recurring live!'),
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
                            'Version ${v.version} · ${v.status.toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Effective: ${v.effectiveFrom.toIso8601String().split('T').first} '
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
                final v = _timetableService.getCachedActiveVersion(widget.classId, day);
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

                      // Effective Date Selector
                      InkWell(
                        onTap: _pickEffectiveDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Effective From: ${_effectiveFrom.toIso8601String().split('T').first}',
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
  })  : subjectController = TextEditingController(text: subject),
        teacherController = TextEditingController(text: teacherName),
        roomController = TextEditingController(text: room),
        notesController = TextEditingController(text: notes);

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
    );
  }

  void dispose() {
    subjectController.dispose();
    teacherController.dispose();
    roomController.dispose();
    notesController.dispose();
  }
}
