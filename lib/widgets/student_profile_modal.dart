import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../models/player_sports_stats.dart';
import '../theme/app_theme.dart';
import '../screens/chat_room_screen.dart';
import 'managed_modal_scope.dart';

/// Universal Student Profile & Conduct Inspection Modal
///
/// If opened by an Admin, Council Member, or Teacher:
///   - Grants administrative conduct actions: Award Merits (+Points), Issue Demerits (-Points),
///     Review Medical Leaves, and Direct 1-on-1 messaging.
/// If opened by a Student:
///   - Strictly Read-Only mode displaying student's house pride, points contributed, and public accolades.
class StudentProfileModal extends StatefulWidget {
  final String scholarNo;
  final String studentName;
  final String houseName;
  final String? classLevel;
  final String? avatarUrl;

  const StudentProfileModal({
    super.key,
    this.scholarNo = '',
    required this.studentName,
    required this.houseName,
    this.classLevel,
    this.avatarUrl,
  });

  static void show(
    BuildContext context, {
    String scholarNo = '',
    required String studentName,
    required String houseName,
    String? classLevel,
    String? avatarUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentProfileModal(
        scholarNo: scholarNo,
        studentName: studentName,
        houseName: houseName,
        classLevel: classLevel,
        avatarUrl: avatarUrl,
      ),
    );
  }

  @override
  State<StudentProfileModal> createState() => _StudentProfileModalState();
}

class _StudentProfileModalState extends State<StudentProfileModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  bool _isProcessingAction = false;

  String? _dynamicScholarNo;
  String? _dynamicClassLevel;
  String? _dynamicAvatarUrl;
  String? _dynamicHouseName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dynamicScholarNo = widget.scholarNo.isNotEmpty && widget.scholarNo != 'unknown' ? widget.scholarNo : null;
    _dynamicClassLevel = widget.classLevel;
    _dynamicAvatarUrl = widget.avatarUrl;
    _dynamicHouseName = widget.houseName;
    _resolveStudentMetadata();
  }

  Future<void> _resolveStudentMetadata() async {
    try {
      QuerySnapshot snap;
      final cleanScholar = widget.scholarNo.trim();
      final cleanName = widget.studentName.trim();
      if (cleanScholar.isNotEmpty && cleanScholar != 'unknown') {
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('scholar_no', isEqualTo: cleanScholar)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 3));
      } else if (cleanName.isNotEmpty) {
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('full_name', isEqualTo: cleanName)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 3));
      } else {
        return;
      }

      if (snap.docs.isNotEmpty && mounted) {
        final data = snap.docs.first.data() as Map<String, dynamic>;
        setState(() {
          if (data['scholar_no'] != null && (_dynamicScholarNo == null || _dynamicScholarNo!.isEmpty)) {
            _dynamicScholarNo = data['scholar_no'].toString();
          }
          final cLevel = data['class_level'] ?? data['class'];
          final div = data['division'] ?? '';
          if (cLevel != null && (_dynamicClassLevel == null || _dynamicClassLevel!.isEmpty)) {
            _dynamicClassLevel = '$cLevel $div'.trim();
          }
          if (data['avatar_url'] != null) {
            _dynamicAvatarUrl = data['avatar_url'].toString();
          }
          final h = AuthService.extractHouse(data);
          if (h != null && (_dynamicHouseName == null || _dynamicHouseName!.isEmpty)) {
            _dynamicHouseName = h;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _checkIsAdminUser() {
    final cachedProfile = AuthService.getCachedProfile();
    final role = cachedProfile?['role']?.toString().toLowerCase() ?? 'student';
    final currentScholar = AuthService.getCachedScholarNo() ?? '';
    final isCouncilOrTeacher = HierarchyService.isCouncilOrTeacher(
      scholarNo: currentScholar,
      role: role,
      fullName: cachedProfile?['full_name']?.toString() ?? '',
    );
    return isCouncilOrTeacher ||
        HierarchyService.isAdmin(scholarNo: currentScholar, role: role) ||
        currentScholar.toLowerCase() == 'admin';
  }

  void _showAwardMeritDialog(BuildContext context, Color houseColor) {
    final parentContext = context;
    final parentMessenger = ScaffoldMessenger.of(parentContext);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reasonController = TextEditingController();
    int selectedPoints = 10;

    final presetReasons = [
      ('Academic Excellence', 10),
      ('Inter-House Sports Win', 25),
      ('Leadership & Service', 15),
      ('School Assembly Presentation', 10),
      ('Outstanding Discipline', 5),
      ('Championship MVP', 50),
    ];

    showDialog(
      context: context,
      builder: (ctx) => ManagedModalScope(
        controllers: [reasonController],
        child: StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Award House Merits',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                      Text(
                        'To ${widget.studentName} (#${widget.scholarNo})',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Points Value:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 15, 25, 50].map((pts) {
                      final isSel = selectedPoints == pts;
                      return ChoiceChip(
                        label: Text('+$pts PTS', style: TextStyle(fontWeight: FontWeight.w800, color: isSel ? Colors.white : Colors.green[800])),
                        selected: isSel,
                        selectedColor: Colors.green[600],
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedPoints = pts);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Quick Presets:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presetReasons.map((p) {
                      return ActionChip(
                        label: Text(p.$1, style: const TextStyle(fontSize: 11)),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        onPressed: () {
                          setDialogState(() {
                            reasonController.text = p.$1;
                            selectedPoints = p.$2;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Official Citation / Reason',
                      hintText: 'e.g. Demonstrated exceptional teamwork in Inter-House Quiz',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text('Award +$selectedPoints PTS'),
                onPressed: () async {
                  final reason = reasonController.text.trim().isEmpty
                      ? 'Commendable House Contribution'
                      : reasonController.text.trim();
                  Navigator.pop(ctx);

                  setState(() => _isProcessingAction = true);
                  final adminProfile = AuthService.getCachedProfile();
                  final reviewer = adminProfile?['full_name']?.toString() ?? 'Faculty Lead';

                  await _authService.recordStudentConduct(
                    scholarNo: widget.scholarNo,
                    studentName: widget.studentName,
                    houseName: widget.houseName,
                    type: 'merit',
                    points: selectedPoints,
                    reason: reason,
                    teacherName: reviewer,
                    classLevel: widget.classLevel ?? 'Senior',
                  );

                  if (mounted) {
                    setState(() => _isProcessingAction = false);
                  }

                  parentMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Awarded +$selectedPoints PTS to ${widget.studentName} (${widget.houseName.toUpperCase()})!'),
                      backgroundColor: Colors.green[700],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

  void _showIssueDemeritDialog(BuildContext context) {
    final parentContext = context;
    final parentMessenger = ScaffoldMessenger.of(parentContext);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reasonController = TextEditingController();
    int selectedPoints = 5;

    final presetReasons = [
      ('Late to Morning Assembly', 5),
      ('Improper School Uniform', 5),
      ('Classroom Disruption', 10),
      ('Incomplete Academic Assignment', 10),
      ('Unauthorized Area Access', 15),
      ('Severe Code of Conduct Violation', 25),
    ];

    showDialog(
      context: context,
      builder: (ctx) => ManagedModalScope(
        controllers: [reasonController],
        child: StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Issue Conduct Demerit',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                      Text(
                        'To ${widget.studentName} (#${widget.scholarNo})',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Penalty Points:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 15, 25].map((pts) {
                      final isSel = selectedPoints == pts;
                      return ChoiceChip(
                        label: Text('-$pts PTS', style: TextStyle(fontWeight: FontWeight.w800, color: isSel ? Colors.white : Colors.red[800])),
                        selected: isSel,
                        selectedColor: Colors.redAccent,
                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                        onSelected: (val) {
                          if (val) setDialogState(() => selectedPoints = pts);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Infraction Presets:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presetReasons.map((p) {
                      return ActionChip(
                        label: Text(p.$1, style: const TextStyle(fontSize: 11)),
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        onPressed: () {
                          setDialogState(() {
                            reasonController.text = p.$1;
                            selectedPoints = p.$2;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Infraction Explanation',
                      hintText: 'e.g. Repeatedly late to Period 1 without authorized pass',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: Text('Deduct -$selectedPoints PTS'),
                onPressed: () async {
                  final reason = reasonController.text.trim().isEmpty
                      ? 'Conduct Infraction'
                      : reasonController.text.trim();
                  Navigator.pop(ctx);

                  setState(() => _isProcessingAction = true);
                  final adminProfile = AuthService.getCachedProfile();
                  final reviewer = adminProfile?['full_name']?.toString() ?? 'Faculty Lead';

                  await _authService.recordStudentConduct(
                    scholarNo: widget.scholarNo,
                    studentName: widget.studentName,
                    houseName: widget.houseName,
                    type: 'demerit',
                    points: selectedPoints,
                    reason: reason,
                    teacherName: reviewer,
                    classLevel: widget.classLevel ?? 'Senior',
                  );

                  if (mounted) {
                    setState(() => _isProcessingAction = false);
                  }

                  parentMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Issued -$selectedPoints PTS Demerit to ${widget.studentName} (${widget.houseName.toUpperCase()}).'),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

  void _openDirectChat(BuildContext context) async {
    final currentUid = AuthService.getCachedProfile()?['uid']?.toString() ?? '';
    final myHouse = AuthService.getCachedHouse() ?? 'ruby';

    // Find student UID if possible
    String otherUid = 'student_${widget.scholarNo}';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('scholar_no', isEqualTo: widget.scholarNo)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 3));
      if (snap.docs.isNotEmpty) {
        otherUid = snap.docs.first.id;
      }
    } catch (_) {}

    final uids = [currentUid.isNotEmpty ? currentUid : 'admin', otherUid]..sort();
    final roomId = '${uids[0]}_${uids[1]}';

    if (!context.mounted) return;
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          roomId: roomId,
          otherUserName: widget.studentName,
          otherUserRole: 'Scholar #${widget.scholarNo}',
          otherUserId: otherUid,
          otherUserHouse: widget.houseName,
          myUserHouse: myHouse,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveHouse = _dynamicHouseName ?? widget.houseName;
    final houseColor = HouseColors.getHouseColor(effectiveHouse);
    final isAdmin = _checkIsAdminUser();
    final hName = effectiveHouse.toUpperCase();
    final effectiveScholar = _dynamicScholarNo ?? (widget.scholarNo.isNotEmpty && widget.scholarNo != 'unknown' ? widget.scholarNo : 'Registered Scholar');
    final isSuper = HierarchyService.isSuperAdmin(scholarNo: effectiveScholar);
    final isFaculty = HierarchyService.isTeacherOrFaculty(scholarNo: effectiveScholar);
    final String effectiveClass;
    if (isSuper || isFaculty) {
      effectiveClass = 'Administration / Faculty';
    } else {
      final raw = (_dynamicClassLevel ?? widget.classLevel ?? '').trim();
      if (raw.isEmpty || raw == '--') {
        effectiveClass = 'Senior Secondary';
      } else {
        effectiveClass = raw.startsWith('Grade') ? raw : 'Grade $raw';
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 14),

          // Header Profile Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [houseColor.withValues(alpha: 0.25), const Color(0xFF1E293B)]
                      : [houseColor.withValues(alpha: 0.12), const Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: houseColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: houseColor,
                    backgroundImage: (_dynamicAvatarUrl != null && _dynamicAvatarUrl!.trim().isNotEmpty)
                        ? NetworkImage(_dynamicAvatarUrl!.trim())
                        : null,
                    child: (_dynamicAvatarUrl == null || _dynamicAvatarUrl!.trim().isEmpty)
                        ? Text(
                            widget.studentName.isNotEmpty ? widget.studentName[0].toUpperCase() : 'S',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.studentName,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: houseColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hName,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scholar #$effectiveScholar • $effectiveClass',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close dialog',
                    child: IconButton(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Admin Conduct Action Buttons Bar (Only for Admins/Faculty Leads)
          if (isAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.stars_rounded, size: 18),
                      label: const Text('Award Merits', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      onPressed: _isProcessingAction ? null : () => _showAwardMeritDialog(context, houseColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1,
                      ),
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: const Text('Issue Demerits', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      onPressed: _isProcessingAction ? null : () => _showIssueDemeritDialog(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openDirectChat(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: houseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: houseColor.withValues(alpha: 0.4)),
                      ),
                      child: Icon(Icons.chat_bubble_outline_rounded, color: houseColor, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Segmented Tabs (2 Tabs: Merits & Accolades, Conduct Ledger)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              dividerHeight: 0,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: houseColor,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black87,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: '🏆 Merits & Accolades'),
                Tab(text: '📋 Conduct Ledger'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tab Views Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMeritsAndAccoladesTab(isDark, houseColor, effectiveScholar),
                _buildConductLedgerTab(isDark, houseColor, effectiveScholar),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeritsAndAccoladesTab(bool isDark, Color houseColor, String effectiveScholar) {
    return StreamBuilder<List<PlayerSportsStats>>(
      stream: _authService.getPlayerSportsStatsStream(),
      builder: (context, statsSnap) {
        final allStats = statsSnap.data ?? AuthService.getCachedPlayerSportsStats();
        final studentStats = allStats.where((s) => s.scholarNo == effectiveScholar.trim()).toList();
        final contrib = AuthService.getCachedStudentContribution(effectiveScholar);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Contribution Metrics Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Points Contributed', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('+${contrib.totalPoints} PTS', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Merits Logged', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('${contrib.merits} Merits', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Sports & Extracurricular Accolades
            Text(
              '🏅 Tournament Accolades & Trophies',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            if (studentStats.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'No tournament accolades logged yet for ${widget.studentName}.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...studentStats.map((s) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: houseColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: houseColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(s.sportType.emoji, style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.sportType.displayName} Player',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            Text(
                              '${s.matchesPlayed} Matches • ${s.mvpAwardsCount} MVP Awards • ${s.goalsScored + s.basketsScored + s.trackPoints} Score Points',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildConductLedgerTab(bool isDark, Color houseColor, String effectiveScholar) {
    final isAdmin = _checkIsAdminUser();
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _authService.getStudentConductStream(effectiveScholar),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_turned_in_rounded, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text('Clean Conduct Record', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('No merits or demerits recorded yet.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final data = docs[idx].data() as Map<String, dynamic>? ?? {};
            final type = data['type']?.toString().toLowerCase() ?? 'merit';
            final isMerit = type == 'merit';
            final pts = (data['points'] as num?)?.toInt() ?? 0;
            final reason = data['reason']?.toString() ?? 'Conduct citation';
            final teacher = data['teacher_name']?.toString() ?? 'Faculty Lead';

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isMerit
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.redAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isMerit ? Colors.green : Colors.redAccent).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMerit ? Icons.star_rounded : Icons.warning_rounded,
                      color: isMerit ? Colors.green : Colors.redAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reason, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('Recorded by $teacher', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isMerit ? Colors.green : Colors.redAccent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isMerit ? '+$pts PTS' : '$pts PTS',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: isMerit ? Colors.green[800] : Colors.redAccent,
                      ),
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      tooltip: 'Revoke Mistaken Entry',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Revoke Conduct Entry?'),
                            content: Text(
                              'Are you sure you want to revoke this $type entry ("$reason", $pts PTS)?\n'
                              'This will reverse points and remove it from the scholar\'s record.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Revoke Entry'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final ok = await _authService.revokeConductRecord(
                            recordId: docs[idx].id,
                            scholarNo: effectiveScholar,
                            points: pts,
                            isMerit: isMerit,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? '✓ Mistaken conduct entry revoked successfully.'
                                      : 'Failed to revoke entry.',
                                ),
                                backgroundColor: ok ? Colors.green[700] : Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
