import 'package:flutter/material.dart';
import '../models/academic_class.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';

/// Admin command center for the canonical academic structure (M1).
/// Staff verify scholar class placements, manage sections per grade, and
/// browse class rosters. All writes are enforced admin-only by Firestore
/// rules; this screen additionally hides controls from non-staff roles.
class AdminAcademicsScreen extends StatefulWidget {
  const AdminAcademicsScreen({super.key});

  @override
  State<AdminAcademicsScreen> createState() => _AdminAcademicsScreenState();
}

class _AdminAcademicsScreenState extends State<AdminAcademicsScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late final TabController _tabController;
  final Set<String> _processing = {};
  String? _rosterClassId;
  bool _isStaff = false;

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Class Placement'),
        content: Text(
          'Confirm $name (Scholar #$scholarNo) belongs to $classId '
          '(${AcademicStructure.displayClass(
            AcademicStructure.parseClassId(classId)!.$1,
            AcademicStructure.parseClassId(classId)!.$2,
          )})?',
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
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Verify'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Classes'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'Rosters'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(scheme),
          _buildClassesTab(scheme),
          _buildRostersTab(scheme),
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
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
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
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final classes = snap.data ?? [];
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
      builder: (context, snap) {
        final classes = (snap.data ?? [])
            .where((c) => c.active)
            .toList();
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
                builder: (context, rosterSnap) {
                  if (rosterSnap.connectionState == ConnectionState.waiting) {
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
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Scholar #$scholarNo • ${(p['house_name'] ?? '').toString()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Icon(
                            verified
                                ? Icons.verified_rounded
                                : Icons.pending_outlined,
                            size: 20,
                            color: verified ? Colors.green : Colors.orange,
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
            final available = classes
                .where((c) => c.classId != widget.currentClassId)
                .toList();
            return DropdownButtonFormField<String>(
              initialValue: _selected,
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