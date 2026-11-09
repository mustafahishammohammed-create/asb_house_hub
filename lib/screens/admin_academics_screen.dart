import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/academic_class.dart';
import '../models/class_timetable.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../services/timetable_service.dart';

/// Admin command center for academic management (M1, M7).
/// Staff manage sections, verify and transfer scholars, assign houses,
/// promote classes to the new academic year, approve submitted timetables,
/// view immutable audit logs, and manage user account statuses. All writes
/// are enforced admin-only by Firestore rules; this screen additionally
/// hides controls from non-staff roles.
class AdminAcademicsScreen extends StatefulWidget {
  const AdminAcademicsScreen({super.key});

  @override
  State<AdminAcademicsScreen> createState() => _AdminAcademicsScreenState();
}

class _AdminAcademicsScreenState extends State<AdminAcademicsScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _timetableService = TimetableService();
  late final TabController _tabController;
  final Set<String> _processing = {};
  String? _rosterClassId;
  bool _isStaff = false;

  // Promotion tab state
  String? _promotionSourceClassId;
  String? _promotionTargetClassId;
  bool _promotingBatch = false;
  final TextEditingController _individualScholarNoController = TextEditingController();
  String? _individualTargetClassId;
  bool _promotingIndividual = false;

  // Audit logs tab state
  String? _auditClassFilter;
  String _auditActionFilter = 'all';

  @override
  void initState() {
    super.initState();
    final profile = AuthService.getCachedProfile();
    final role = profile?['role']?.toString();
    final scholarNo =
        profile?['scholar_no']?.toString() ?? AuthService.getCachedScholarNo();
    _isStaff = HierarchyService.isTeacherOrFaculty(
          role: role,
          scholarNo: scholarNo,
        ) ||
        HierarchyService.isSuperAdmin(role: role, scholarNo: scholarNo);
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _individualScholarNoController.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red[700] : Colors.green[700],
      ),
    );
  }

  String _declaredClassId(Map<String, dynamic> profile) {
    final cid = (profile['class_id'] ?? '').toString().trim();
    if (cid.isNotEmpty && AcademicStructure.parseClassId(cid) != null) {
      return cid;
    }
    return AcademicStructure.classIdFrom(
      (profile['class_level'] ?? '').toString(),
      (profile['division'] ?? '').toString(),
    );
  }

  Future<void> _verifyScholar(Map<String, dynamic> profile) async {
    final scholarNo = (profile['scholar_no'] ?? '').toString().trim();
    final name = (profile['full_name'] ?? 'Scholar').toString();
    final classId = _declaredClassId(profile);
    if (scholarNo.isEmpty) return;
    if (classId.isEmpty) {
      _toast('No valid class on record for $name — use Transfer to assign one.',
          error: true);
      return;
    }
    final parsed = AcademicStructure.parseClassId(classId);
    final display = parsed != null
        ? ' (${AcademicStructure.displayClass(parsed.$1, parsed.$2)})'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Class Placement'),
        content: Text(
          'Confirm $name (Scholar #$scholarNo) belongs to $classId$display?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _processing.add(scholarNo));
    final ok = await _authService.verifyStudentClass(
      scholarNo: scholarNo,
      classId: classId,
    );
    if (!mounted) return;
    setState(() => _processing.remove(scholarNo));
    _toast(
      ok ? '$name verified in $classId.' : 'Verification failed for $name.',
      error: !ok,
    );
  }

  Future<void> _transferScholar(Map<String, dynamic> profile) async {
    final scholarNo = (profile['scholar_no'] ?? '').toString().trim();
    final name = (profile['full_name'] ?? 'Scholar').toString();
    if (scholarNo.isEmpty) return;

    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => _TransferDialog(
        authService: _authService,
        studentName: name,
        currentClassId: _declaredClassId(profile),
      ),
    );
    if (target == null || target.isEmpty || !mounted) return;
    setState(() => _processing.add(scholarNo));
    final ok = await _authService.transferStudentClass(
      scholarNo: scholarNo,
      classId: target,
    );
    if (!mounted) return;
    setState(() => _processing.remove(scholarNo));
    _toast(
      ok ? '$name transferred to $target.' : 'Transfer failed for $name.',
      error: !ok,
    );
  }

  Future<void> _changeHouse(Map<String, dynamic> profile) async {
    final scholarNo = (profile['scholar_no'] ?? '').toString().trim();
    final name = (profile['full_name'] ?? 'Scholar').toString();
    final currentHouse = (profile['house_name'] ?? '').toString();
    if (scholarNo.isEmpty) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _HouseAssignmentDialog(
        studentName: name,
        currentHouse: currentHouse,
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() => _processing.add(scholarNo));
    final ok = await _authService.assignStudentHouse(
      scholarNo: scholarNo,
      houseName: selected,
    );
    if (!mounted) return;
    setState(() => _processing.remove(scholarNo));
    _toast(
      ok ? '$name assigned to ${selected.toUpperCase()} House.' : 'House assignment failed for $name.',
      error: !ok,
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> profile) async {
    final scholarNo = (profile['scholar_no'] ?? '').toString().trim();
    final name = (profile['full_name'] ?? 'Scholar').toString();
    final currentStatus = (profile['status'] ?? 'active').toString();
    if (scholarNo.isEmpty) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _UserStatusDialog(
        studentName: name,
        currentStatus: currentStatus,
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() => _processing.add(scholarNo));
    final ok = await _authService.setUserStatus(
      scholarNo: scholarNo,
      status: selected,
    );
    if (!mounted) return;
    setState(() => _processing.remove(scholarNo));
    _toast(
      ok ? '$name account status set to $selected.' : 'Status update failed for $name.',
      error: !ok,
    );
  }

  Future<void> _approveSubmittedTimetable(ClassTimetableVersion version) async {
    final profile = AuthService.getCachedProfile();
    final uid = (profile?['uid'] ?? 'admin').toString();
    final name = (profile?['full_name'] ?? 'School Administration').toString();

    final ok = await _timetableService.publishTimetable(
      version,
      publisherUid: uid,
      publisherName: name,
      enforceConflicts: true,
    );
    if (!mounted) return;
    _toast(
      ok
          ? 'Approved and published ${version.classId} (${version.dayOfWeek}). Notifications sent.'
          : 'Could not approve timetable. Check for room or teacher conflicts.',
      error: !ok,
    );
    if (ok) {
      final fanOut = _timetableService.lastNotificationResult;
      if (fanOut != null && fanOut.warning != null) {
        _toast(
          fanOut.warning!,
          error: true,
        );
      }
    }
  }

  Future<void> _rejectSubmittedTimetable(ClassTimetableVersion version) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Timetable — ${version.classId} ${version.dayOfWeek}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'e.g. Schedule conflicts or missing teacher assignment.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;

    final profile = AuthService.getCachedProfile();
    final uid = (profile?['uid'] ?? 'admin').toString();
    final name = (profile?['full_name'] ?? 'School Administration').toString();

    final ok = await _timetableService.rejectTimetable(
      version,
      reason: reason,
      reviewerUid: uid,
      reviewerName: name,
    );
    if (!mounted) return;
    _toast(
      ok ? 'Rejected timetable version for ${version.classId}.' : 'Rejection failed.',
      error: !ok,
    );
  }

  Future<void> _addSection() async {
    final result = await showDialog<AcademicClass>(
      context: context,
      builder: (ctx) => const _SectionEditorDialog(),
    );
    if (result == null || !mounted) return;
    final ok = await _authService.saveAcademicClass(result);
    if (!mounted) return;
    _toast(
      ok
          ? 'Section ${result.classId} created.'
          : 'Could not create section ${result.classId}.',
      error: !ok,
    );
    if (ok) {
      setState(() {
        _rosterClassId = result.classId;
      });
      _tabController.animateTo(2);
    }
  }

  Future<void> _editClassTeacher(AcademicClass cls) async {
    final controller = TextEditingController(text: cls.classTeacher);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Class Teacher — ${cls.classId}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Class teacher name',
            hintText: 'e.g. Ms. Fatima Al Hasan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    final ok = await _authService.saveAcademicClass(
      cls.copyWith(classTeacher: name),
    );
    if (!mounted) return;
    _toast(
      ok ? 'Class teacher updated for ${cls.classId}.' : 'Update failed.',
      error: !ok,
    );
  }

  Future<void> _editClassCommunication(AcademicClass cls) async {
    final updated = await showDialog<AcademicClass>(
      context: context,
      builder: (ctx) => _ClassCommunicationDialog(cls: cls),
    );
    if (updated == null || !mounted) return;
    final ok = await _authService.saveAcademicClass(updated);
    if (!mounted) return;
    _toast(
      ok
          ? 'Class group settings updated for ${cls.classId}.'
          : 'Could not update class group settings for ${cls.classId}.',
      error: !ok,
    );
  }

  Future<void> _toggleClassActive(AcademicClass cls, bool active) async {
    final ok = await _authService.setClassActive(cls.classId, active);
    if (!mounted) return;
    _toast(
      ok
          ? '${cls.classId} ${active ? 'activated' : 'deactivated'}.'
          : 'Could not update ${cls.classId}.',
      error: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_isStaff) {
      return Scaffold(
        appBar: AppBar(title: const Text('Academic Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: scheme.error),
                const SizedBox(height: 16),
                Text(
                  'Academic management is restricted to school staff and administrators.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Academic Management',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Verify'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Classes'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'Rosters'),
            Tab(icon: Icon(Icons.upgrade_outlined), text: 'Promotion'),
            Tab(icon: Icon(Icons.pending_actions_outlined), text: 'Approvals'),
            Tab(icon: Icon(Icons.history_edu_outlined), text: 'Audit Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(scheme),
          _buildClassesTab(scheme),
          _buildRostersTab(scheme),
          _buildPromotionTab(scheme),
          _buildApprovalsTab(scheme),
          _buildAuditLogsTab(scheme),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSection,
        icon: const Icon(Icons.add),
        label: const Text('Add Section'),
      ),
    );
  }

  Widget _buildPendingTab(ColorScheme scheme) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _authService.getPendingClassVerificationsStream(),
      initialData: const <Map<String, dynamic>>[],
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = snap.data ?? [];
        if (pending.isEmpty) {
          return _emptyState(
            scheme,
            Icons.verified_outlined,
            'All scholars have verified class placements.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: pending.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = pending[i];
            final scholarNo = (p['scholar_no'] ?? '').toString();
            final name = (p['full_name'] ?? 'Scholar').toString();
            final house = (p['house_name'] ?? '').toString();
            final declared = _declaredClassId(p);
            final busy = _processing.contains(scholarNo);
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Scholar #$scholarNo'
                                '${house.isNotEmpty ? ' • ${house[0].toUpperCase()}${house.substring(1)} House' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: declared.isEmpty
                                ? scheme.errorContainer
                                : scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            declared.isEmpty ? 'No class' : declared,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: declared.isEmpty
                                  ? scheme.onErrorContainer
                                  : scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _transferScholar(p),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text('Transfer'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: busy || declared.isEmpty
                              ? null
                              : () => _verifyScholar(p),
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Verify'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClassesTab(ColorScheme scheme) {
    return StreamBuilder<List<AcademicClass>>(
      stream: _authService.getAcademicClassesStream(),
      initialData: AuthService.getCachedAcademicClasses(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rawClasses = snap.data ?? [];
        final uniqueMap = <String, AcademicClass>{};
        for (final c in rawClasses) {
          uniqueMap[c.classId] = c;
        }
        final classes = uniqueMap.values.toList();
        if (classes.isEmpty) {
          return _emptyState(
            scheme,
            Icons.school_outlined,
            'No sections registered yet. Use "Add Section" to create the first class.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: classes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final cls = classes[i];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cls.active
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  child: Text(
                    cls.classId,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cls.active
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                title: Text(
                  cls.displayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  cls.classTeacher.isEmpty
                      ? 'No class teacher assigned'
                      : 'Class teacher: ${cls.classTeacher}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit class teacher',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _editClassTeacher(cls),
                    ),
                    IconButton(
                      tooltip: 'Class group settings',
                      icon: const Icon(Icons.forum_outlined, size: 20),
                      onPressed: () => _editClassCommunication(cls),
                    ),
                    Switch(
                      value: cls.active,
                      onChanged: (v) => _toggleClassActive(cls, v),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRostersTab(ColorScheme scheme) {
    return StreamBuilder<List<AcademicClass>>(
      stream: _authService.getAcademicClassesStream(),
      initialData: AuthService.getCachedAcademicClasses(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rawClasses = (snap.data ?? [])
            .where((c) => c.active)
            .toList();
        final uniqueMap = <String, AcademicClass>{};
        for (final c in rawClasses) {
          uniqueMap[c.classId] = c;
        }
        final classes = uniqueMap.values.toList();
        if (classes.isEmpty) {
          return _emptyState(
            scheme,
            Icons.groups_outlined,
            'Create an active section first to browse its roster.',
          );
        }
        final selected = _rosterClassId != null &&
                classes.any((c) => c.classId == _rosterClassId)
            ? _rosterClassId!
            : classes.first.classId;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: DropdownButtonFormField<String>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Select class',
                  border: OutlineInputBorder(),
                ),
                items: classes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.classId,
                        child: Text('${c.classId} — ${c.displayLabel}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _rosterClassId = v),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _authService.getClassRosterStream(selected),
                initialData: const <Map<String, dynamic>>[],
                builder: (context, rosterSnap) {
                  if (rosterSnap.connectionState == ConnectionState.waiting && !rosterSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final roster = rosterSnap.data ?? [];
                  if (roster.isEmpty) {
                    return _emptyState(
                      scheme,
                      Icons.person_off_outlined,
                      'No scholars assigned to $selected yet.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: roster.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = roster[i];
                      final name = (p['full_name'] ?? 'Scholar').toString();
                      final scholarNo = (p['scholar_no'] ?? '').toString();
                      final verified = p['class_verified'] == true;
                      final status = (p['status'] ?? 'active').toString().toLowerCase();
                      final isSuspended = status == 'suspended';
                      final isDeactivated = status == 'deactivated';
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.secondaryContainer,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isSuspended || isDeactivated)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSuspended ? Colors.orange[100] : Colors.red[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSuspended ? Colors.orange[900] : Colors.red[900],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            'Scholar #$scholarNo • ${(p['house_name'] ?? '').toString()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                verified
                                    ? Icons.verified_rounded
                                    : Icons.pending_outlined,
                                size: 20,
                                color: verified ? Colors.green : Colors.orange,
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Scholar Actions',
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) {
                                  if (action == 'house') _changeHouse(p);
                                  if (action == 'transfer') _transferScholar(p);
                                  if (action == 'status') _changeStatus(p);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'house',
                                    child: Row(
                                      children: [
                                        Icon(Icons.shield_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Change House'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'transfer',
                                    child: Row(
                                      children: [
                                        Icon(Icons.swap_horiz_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('Transfer Class'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'status',
                                    child: Row(
                                      children: [
                                        Icon(Icons.manage_accounts_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Account Status'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState(ColorScheme scheme, IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionTab(ColorScheme scheme) {
    return StreamBuilder<List<AcademicClass>>(
      stream: _authService.getAcademicClassesStream(activeOnly: true),
      initialData: AuthService.getCachedAcademicClasses()
          .where((c) => c.active)
          .toList(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rawClasses = snap.data ?? [];
        final uniqueMap = <String, AcademicClass>{};
        for (final c in rawClasses) {
          uniqueMap[c.classId] = c;
        }
        final classes = uniqueMap.values.toList();
        if (classes.isEmpty) {
          return _emptyState(
            scheme,
            Icons.upgrade_outlined,
            'Create active sections first to perform academic year promotions.',
          );
        }

        final sourceClass = _promotionSourceClassId != null &&
                classes.any((c) => c.classId == _promotionSourceClassId)
            ? _promotionSourceClassId!
            : classes.first.classId;

        final autoTarget = AcademicStructure.nextClassId(sourceClass);
        final rawTarget = _promotionTargetClassId ?? autoTarget;
        final targetClass = (rawTarget != null && classes.any((c) => c.classId == rawTarget))
            ? rawTarget
            : (classes.any((c) => c.classId != sourceClass)
                ? classes.firstWhere((c) => c.classId != sourceClass).classId
                : null);

        final individualTarget = (_individualTargetClassId != null &&
                classes.any((c) => c.classId == _individualTargetClassId))
            ? _individualTargetClassId
            : (classes.isNotEmpty ? classes.first.classId : null);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: scheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Year Promotion (Spec §9.5)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Promoting advances students to their next grade and section. '
                            'Per institutional policy, house assignments (Ruby, Sapphire, Emerald, Topaz) '
                            'are strictly preserved and never mutated during promotion.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Promote Class Section',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: sourceClass,
                      decoration: const InputDecoration(
                        labelText: 'Source Class',
                        border: OutlineInputBorder(),
                      ),
                      items: classes
                          .map((c) => DropdownMenuItem(
                                value: c.classId,
                                child: Text('${c.classId} — ${c.displayLabel}'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _promotionSourceClassId = v;
                            _promotionTargetClassId = AcademicStructure.nextClassId(v);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: targetClass,
                      decoration: InputDecoration(
                        labelText: 'Target Class',
                        border: const OutlineInputBorder(),
                        helperText: autoTarget != null
                            ? 'Auto-suggested progression: $autoTarget'
                            : 'No next grade (Final Grade 12 graduating batch)',
                      ),
                      items: classes
                          .map((c) => DropdownMenuItem(
                                value: c.classId,
                                child: Text('${c.classId} — ${c.displayLabel}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _promotionTargetClassId = v),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _authService.getClassRosterStream(sourceClass),
                      builder: (ctx, rosterSnap) {
                        final count = (rosterSnap.data ?? [])
                            .where((p) => p['class_verified'] == true)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '$count verified scholars ready in $sourceClass',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (_promotingBatch || targetClass == null || targetClass == sourceClass)
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Confirm Section Promotion'),
                                    content: Text(
                                      'Promote verified scholars in $sourceClass to $targetClass? '
                                      'House assignments will remain completely intact.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Promote Section'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !mounted) return;
                                setState(() => _promotingBatch = true);
                                final res = await _authService.promoteClassSection(
                                  sourceClassId: sourceClass,
                                  targetClassId: targetClass,
                                );
                                if (!mounted) return;
                                setState(() => _promotingBatch = false);
                                if (res.hasError) {
                                  _toast(
                                    'Could not read the $sourceClass roster: ${res.error}',
                                    error: true,
                                  );
                                } else if (res.isCompleteSuccess) {
                                  _toast(
                                    'Successfully promoted ${res.promoted} scholars to $targetClass. Houses preserved.',
                                  );
                                } else if (res.hasFailures) {
                                  _toast(
                                    'Partial promotion: ${res.promoted} promoted, ${res.failed} failed (${res.failedScholarNumbers.join(', ')}).',
                                    error: true,
                                  );
                                } else {
                                  _toast(
                                    'No eligible verified scholars found in $sourceClass.',
                                    error: true,
                                  );
                                }
                              },
                        icon: _promotingBatch
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upgrade_rounded),
                        label: Text('Promote Section to ${targetClass ?? ''}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Promote Individual Scholar',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _individualScholarNoController,
                      decoration: const InputDecoration(
                        labelText: 'Scholar Number',
                        hintText: 'e.g. 11209',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: individualTarget,
                      decoration: const InputDecoration(
                        labelText: 'Target Class',
                        border: OutlineInputBorder(),
                      ),
                      items: classes
                          .map((c) => DropdownMenuItem(
                                value: c.classId,
                                child: Text('${c.classId} — ${c.displayLabel}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _individualTargetClassId = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: (_promotingIndividual || _individualTargetClassId == null)
                            ? null
                            : () async {
                                final sNo = _individualScholarNoController.text.trim();
                                if (sNo.isEmpty) {
                                  _toast('Enter a valid scholar number', error: true);
                                  return;
                                }
                                setState(() => _promotingIndividual = true);
                                final ok = await _authService.promoteScholar(
                                  scholarNo: sNo,
                                  targetClassId: _individualTargetClassId!,
                                );
                                if (!mounted) return;
                                setState(() => _promotingIndividual = false);
                                _toast(
                                  ok
                                      ? 'Scholar #$sNo promoted to $_individualTargetClassId. House preserved.'
                                      : 'Promotion failed for #$sNo.',
                                  error: !ok,
                                );
                                if (ok) _individualScholarNoController.clear();
                              },
                        icon: _promotingIndividual
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_rounded),
                        label: const Text('Promote Scholar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildApprovalsTab(ColorScheme scheme) {
    return StreamBuilder<List<ClassTimetableVersion>>(
      stream: _timetableService.getSubmittedTimetableQueueStream(),
      initialData: _timetableService.getAllCachedSubmittedVersions(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return _emptyState(
            scheme,
            Icons.task_alt_outlined,
            'No timetable versions awaiting administrative approval.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final v = list[i];
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            v.classId,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          v.dayOfWeek,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v${v.version}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        if (v.isTemporary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Override',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: Colors.amber[900],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted by: ${v.createdByName.isNotEmpty ? v.createdByName : 'Teacher'} (${v.createdByUid.isNotEmpty ? v.createdByUid : 'UID'})',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      'Schedule: ${v.slots.length} periods • Break after Period ${v.breakAfterPeriod}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _rejectSubmittedTimetable(v),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _approveSubmittedTimetable(v),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Approve & Publish'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditLogsTab(ColorScheme scheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final action in [
                  'all',
                  'publish',
                  'submit',
                  'reject',
                  'restore',
                  'override',
                  'substitute',
                  'copy',
                  'promotion',
                  'transfer',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _auditActionFilter == action,
                      label: Text(action == 'all' ? 'All Actions' : action[0].toUpperCase() + action.substring(1)),
                      onSelected: (selected) {
                        if (selected) setState(() => _auditActionFilter = action);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _timetableService.getAllTimetableAuditsStream(
              classId: _auditClassFilter,
              actionFilter: _auditActionFilter,
            ),
            initialData: _timetableService.getAllCachedAudits(
              classId: _auditClassFilter,
              actionFilter: _auditActionFilter,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snap.data ?? [];
              if (logs.isEmpty) {
                return _emptyState(
                  scheme,
                  Icons.history_outlined,
                  'No audit log records match the current filter.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: logs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final log = logs[i];
                  final action = (log['action'] ?? '').toString();
                  final classId = (log['class_id'] ?? '').toString();
                  final actorName = (log['actor_name'] ?? 'Staff').toString();
                  final actorUid = (log['actor_uid'] ?? '').toString();
                  final details = (log['details'] ?? '').toString();
                  final ts = log['timestamp'];
                  final timeLabel = ts is Timestamp
                      ? ts.toDate().toLocal().toString().split('.').first
                      : (ts ?? '').toString().split('.').first;

                  Color chipColor;
                  switch (action) {
                    case 'publish':
                    case 'approve':
                      chipColor = Colors.green;
                      break;
                    case 'reject':
                      chipColor = Colors.red;
                      break;
                    case 'submit':
                      chipColor = Colors.orange;
                      break;
                    case 'restore':
                      chipColor = Colors.blue;
                      break;
                    case 'override':
                      chipColor = Colors.purple;
                      break;
                    case 'promotion':
                      chipColor = Colors.indigo;
                      break;
                    case 'substitute':
                      chipColor = Colors.amber;
                      break;
                    default:
                      chipColor = Colors.teal;
                  }

                  return Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: chipColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  action.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: chipColor,
                                  ),
                                ),
                              ),
                              if (classId.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    classId,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                timeLabel,
                                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            details,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'By $actorName ($actorUid)',
                                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.lock_outline, size: 12, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                'Immutable Audit',
                                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HouseAssignmentDialog extends StatefulWidget {
  final String studentName;
  final String currentHouse;

  const _HouseAssignmentDialog({
    required this.studentName,
    required this.currentHouse,
  });

  @override
  State<_HouseAssignmentDialog> createState() => _HouseAssignmentDialogState();
}

class _HouseAssignmentDialogState extends State<_HouseAssignmentDialog> {
  late String _selected;

  static const _houses = [
    ('ruby', 'Ruby House', Colors.red),
    ('sapphire', 'Sapphire House', Colors.blue),
    ('emerald', 'Emerald House', Colors.green),
    ('topaz', 'Topaz House', Colors.amber),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentHouse.toLowerCase();
    if (!_houses.any((h) => h.$1 == _selected)) {
      _selected = 'ruby';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('House Assignment — ${widget.studentName}'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select house assignment. Academic class placement will remain unchanged.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (final (id, label, color) in _houses)
              ListTile(
                dense: true,
                leading: CircleAvatar(backgroundColor: color, radius: 10),
                title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                trailing: _selected == id ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : const Icon(Icons.circle_outlined, size: 20),
                onTap: () => setState(() => _selected = id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save House'),
        ),
      ],
    );
  }
}

class _UserStatusDialog extends StatefulWidget {
  final String studentName;
  final String currentStatus;

  const _UserStatusDialog({
    required this.studentName,
    required this.currentStatus,
  });

  @override
  State<_UserStatusDialog> createState() => _UserStatusDialogState();
}

class _UserStatusDialogState extends State<_UserStatusDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStatus.toLowerCase();
    if (!['active', 'suspended', 'deactivated'].contains(_selected)) {
      _selected = 'active';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Account Status — ${widget.studentName}'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Suspended and deactivated users are blocked from app actions.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ListTile(
              dense: true,
              title: const Text('Active', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              subtitle: const Text('Full system access permitted.'),
              trailing: _selected == 'active' ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : const Icon(Icons.circle_outlined, size: 20),
              onTap: () => setState(() => _selected = 'active'),
            ),
            ListTile(
              dense: true,
              title: const Text('Suspended', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              subtitle: const Text('Temporary access hold.'),
              trailing: _selected == 'suspended' ? const Icon(Icons.check_circle, color: Colors.orange, size: 20) : const Icon(Icons.circle_outlined, size: 20),
              onTap: () => setState(() => _selected = 'suspended'),
            ),
            ListTile(
              dense: true,
              title: const Text('Deactivated', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              subtitle: const Text('Account disabled.'),
              trailing: _selected == 'deactivated' ? const Icon(Icons.check_circle, color: Colors.red, size: 20) : const Icon(Icons.circle_outlined, size: 20),
              onTap: () => setState(() => _selected = 'deactivated'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Update Status'),
        ),
      ],
    );
  }
}

class _TransferDialog extends StatefulWidget {
  final AuthService authService;
  final String studentName;
  final String currentClassId;

  const _TransferDialog({
    required this.authService,
    required this.studentName,
    required this.currentClassId,
  });

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Transfer ${widget.studentName}'),
      content: SizedBox(
        width: 320,
        child: StreamBuilder<List<AcademicClass>>(
          stream: widget.authService.getAcademicClassesStream(activeOnly: true),
          initialData: AuthService.getCachedAcademicClasses()
              .where((c) => c.active)
              .toList(),
          builder: (context, snap) {
            final classes = snap.data ?? [];
            if (classes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No active sections registered. Create a section first.',
                ),
              );
            }
            final uniqueMap = <String, AcademicClass>{};
            for (final c in classes) {
              if (c.classId != widget.currentClassId) {
                uniqueMap[c.classId] = c;
              }
            }
            final available = uniqueMap.values.toList();
            if (available.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No other active sections available to transfer to.'),
              );
            }
            final validSelected = (_selected != null && available.any((c) => c.classId == _selected))
                ? _selected
                : available.first.classId;
            return DropdownButtonFormField<String>(
              initialValue: validSelected,
              decoration: const InputDecoration(
                labelText: 'Destination class',
                border: OutlineInputBorder(),
              ),
              items: available
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.classId,
                      child: Text('${c.classId} — ${c.displayLabel}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selected = v),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Transfer'),
        ),
      ],
    );
  }
}

class _SectionEditorDialog extends StatefulWidget {
  const _SectionEditorDialog();

  @override
  State<_SectionEditorDialog> createState() => _SectionEditorDialogState();
}

class _SectionEditorDialogState extends State<_SectionEditorDialog> {
  String _grade = 'Grade 11';
  String _section = 'A';
  final _teacherController = TextEditingController();

  static const List<String> _sections = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  @override
  void dispose() {
    _teacherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classId = AcademicStructure.classIdFrom(_grade, _section);
    return AlertDialog(
      title: const Text('Add Class Section'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _grade,
              decoration: const InputDecoration(
                labelText: 'Grade level',
                border: OutlineInputBorder(),
              ),
              items: AcademicStructure.gradeLevels
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _grade = v ?? _grade),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _section,
              decoration: const InputDecoration(
                labelText: 'Section',
                border: OutlineInputBorder(),
              ),
              items: _sections
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _section = v ?? _section),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: 'Class teacher (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Canonical class ID: $classId',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            AcademicClass(
              classId: classId,
              grade: _grade,
              section: _section,
              classTeacher: _teacherController.text.trim(),
            ),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Admin editor for the class-group permissions stored on the class registry.
/// These values are the authoritative assignments checked by firestore.rules.
class _ClassCommunicationDialog extends StatefulWidget {
  final AcademicClass cls;

  const _ClassCommunicationDialog({required this.cls});

  @override
  State<_ClassCommunicationDialog> createState() =>
      _ClassCommunicationDialogState();
}

class _ClassCommunicationDialogState extends State<_ClassCommunicationDialog> {
  late final TextEditingController _teacherNameController;
  late final TextEditingController _teacherUidController;
  late final TextEditingController _subjectUidsController;
  late bool _studentPostingEnabled;

  @override
  void initState() {
    super.initState();
    _teacherNameController =
        TextEditingController(text: widget.cls.classTeacher);
    _teacherUidController =
        TextEditingController(text: widget.cls.classTeacherUid ?? '');
    _subjectUidsController = TextEditingController(
      text: widget.cls.subjectTeacherUids.join(', '),
    );
    _studentPostingEnabled = widget.cls.studentPostingEnabled;
  }

  @override
  void dispose() {
    _teacherNameController.dispose();
    _teacherUidController.dispose();
    _subjectUidsController.dispose();
    super.dispose();
  }

  List<String> _parseUids(String raw) {
    final seen = <String>{};
    for (final part in raw.split(',')) {
      final uid = part.trim();
      if (uid.isNotEmpty) seen.add(uid);
    }
    return seen.toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Class Group — ${widget.cls.classId}'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _teacherNameController,
                decoration: const InputDecoration(
                  labelText: 'Class teacher name',
                  hintText: 'e.g. Ms. Fatima Al Hasan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _teacherUidController,
                decoration: const InputDecoration(
                  labelText: 'Class teacher UID',
                  hintText: 'Firebase Auth UID for class-group access',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectUidsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Subject teacher UIDs',
                  hintText: 'Comma-separated Firebase Auth UIDs',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _studentPostingEnabled,
                title: const Text('Allow student posting'),
                subtitle: const Text(
                  'Default is read-only. Class representatives can always post.',
                ),
                onChanged: (v) =>
                    setState(() => _studentPostingEnabled = v),
              ),
              const SizedBox(height: 4),
              Text(
                'These assignments are enforced by Firestore rules. Subject teachers only see the classes listed here.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.cls.copyWith(
              classTeacher: _teacherNameController.text.trim(),
              classTeacherUid: _teacherUidController.text.trim(),
              subjectTeacherUids: _parseUids(_subjectUidsController.text),
              studentPostingEnabled: _studentPostingEnabled,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}