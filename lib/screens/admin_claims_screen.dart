import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../models/medical_leave_request.dart';
import '../theme/app_theme.dart';
import '../widgets/student_profile_modal.dart';
import 'chat_list_screen.dart';
import 'approved_claims_screen.dart';
import 'admin_academics_screen.dart';
import 'class_group_screen.dart';

class AdminClaimsScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const AdminClaimsScreen({super.key, this.isSuperAdmin = false});

  @override
  State<AdminClaimsScreen> createState() => _AdminClaimsScreenState();
}

class _AdminClaimsScreenState extends State<AdminClaimsScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final Set<String> _processingClaimIds = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _medicalStatusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  late TabController _tabController;
  bool _canReviewMedical = false;

  @override
  void initState() {
    super.initState();
    final profile = AuthService.getCachedProfile();
    final role = profile?['role']?.toString();
    final scholarNo = profile?['scholar_no']?.toString() ?? AuthService.getCachedScholarNo();
    _canReviewMedical = HierarchyService.isTeacherOrFaculty(role: role, scholarNo: scholarNo) ||
        HierarchyService.isSuperAdmin(role: role, scholarNo: scholarNo) ||
        HierarchyService.isSeniorAdmin(role: role, scholarNo: scholarNo);
    _tabController = TabController(length: _canReviewMedical ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleApprove(
    String claimId,
    String houseName,
    int points,
    String studentName,
    String scholarNo,
    String activityTitle,
  ) async {
    if (_processingClaimIds.contains(claimId)) return;
    final currentScholar =
        (AuthService.getCachedScholarNo() ?? '').trim().toLowerCase();
    if (currentScholar.isNotEmpty &&
        scholarNo.trim().toLowerCase() == currentScholar &&
        !widget.isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Self-approval is blocked: another reviewer must approve your claim.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _processingClaimIds.add(claimId));
    try {
      await _authService.approveClaim(
        claimId: claimId,
        houseName: houseName,
        points: points,
        scholarNo: scholarNo,
        studentName: studentName,
        activityTitle: activityTitle,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approved +$points Pts for $studentName ($houseName House)!',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving claim: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _processingClaimIds.remove(claimId);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _handleReject(String claimId, String studentName) async {
    if (_processingClaimIds.contains(claimId)) return;
    setState(() => _processingClaimIds.add(claimId));
    try {
      await _authService.rejectClaim(claimId, studentName: studentName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rejected claim submitted by $studentName.'),
          backgroundColor: Colors.orange[800],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting claim: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _processingClaimIds.remove(claimId);
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _getReviewerName() {
    final profile = AuthService.getCachedProfile();
    final name = (profile?['full_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = (profile?['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email;
    final sNo = AuthService.getCachedScholarNo();
    if (sNo != null && sNo.isNotEmpty) return 'Staff #$sNo';
    return 'School Staff';
  }

  void _handleApproveMedicalLeave(String requestId, String studentName) async {
    if (_processingClaimIds.contains(requestId)) return;
    setState(() => _processingClaimIds.add(requestId));
    try {
      final reviewer = _getReviewerName();
      final ok = await _authService.approveMedicalLeave(
        leaveId: requestId,
        reviewerName: reviewer,
        adminRemark: 'Approved - Medical Certificate Verified',
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved Medical Leave for $studentName!'),
            backgroundColor: Colors.teal[700],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error approving medical leave: Permission denied or network failure.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving medical leave: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _processingClaimIds.remove(requestId);
      if (mounted) setState(() {});
    }
  }

  void _handleRejectMedicalLeave(String requestId, String studentName) async {
    if (_processingClaimIds.contains(requestId)) return;
    setState(() => _processingClaimIds.add(requestId));
    try {
      final reviewer = _getReviewerName();
      final ok = await _authService.rejectMedicalLeave(
        leaveId: requestId,
        reviewerName: reviewer,
        adminRemark: 'Declined - Incomplete or illegible medical certificate',
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Declined Medical Leave request for $studentName.'),
            backgroundColor: Colors.orange[800],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error declining medical leave: Permission denied or network failure.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error declining medical leave: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _processingClaimIds.remove(requestId);
      if (mounted) setState(() {});
    }
  }

  void _showPrescriptionDialog(MedicalLeaveRequest leave) {
    Widget imagePreview;
    final photoData = leave.certificatePhotoBase64 ?? '';
    if (photoData.startsWith('data:image/') || photoData.length > 100) {
      try {
        final commaIdx = photoData.indexOf(',');
        final base64Str = commaIdx != -1 ? photoData.substring(commaIdx + 1) : photoData;
        final bytes = base64Decode(base64Str);
        imagePreview = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              height: 380,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
                ),
              ),
            ),
          ),
        );
      } catch (_) {
        imagePreview = const Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey);
      }
    } else {
      imagePreview = const Column(
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.teal),
          SizedBox(height: 12),
          Text('No Prescription Image Attached', style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '🏥 Prescription: ${leave.studentName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Doctor / Clinic: ${leave.doctorName.isNotEmpty ? leave.doctorName : "Unspecified"}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Duration: ${leave.formattedRange}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              const SizedBox(height: 4),
              Text('Reason: ${leave.reason}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[800])),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Center(child: imagePreview),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pinch or scroll to zoom in and examine the physician signature & clinic stamp.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showCertificateDialog(String certUrl, String activityTitle) {
    Widget imagePreview;
    if (certUrl.startsWith('data:image/')) {
      try {
        final commaIdx = certUrl.indexOf(',');
        final base64Str = certUrl.substring(commaIdx + 1);
        final bytes = base64Decode(base64Str);
        imagePreview = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              height: 350,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
                ),
              ),
            ),
          ),
        );
      } catch (_) {
        imagePreview = const Icon(
          Icons.broken_image_rounded,
          size: 64,
          color: Colors.grey,
        );
      }
    } else if (certUrl.startsWith('http')) {
      imagePreview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.network(
            certUrl,
            fit: BoxFit.contain,
            height: 350,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.grey),
              ),
            ),
          ),
        ),
      );
    } else {
      imagePreview = Column(
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 64,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          const Text(
            'Certificate File Attached',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            certUrl.isNotEmpty ? certUrl : 'No file attached',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          activityTitle,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Center(child: imagePreview),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please visually verify the institutional stamp and principal signature before approving points.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showCouncilRosterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CouncilRosterManagementDialog(
        authService: _authService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Icon(
              widget.isSuperAdmin
                  ? Icons.stars_rounded
                  : Icons.admin_panel_settings_rounded,
              color: Colors.amber,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.isSuperAdmin
                    ? '👑 Super Admin Portal'
                    : '🛡️ Council Review Portal',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApprovedClaimsScreen()),
            ),
            icon: const Icon(
              Icons.verified_rounded,
              color: Colors.green,
              size: 20,
            ),
            tooltip: 'Approved Gallery',
          ),
          const SizedBox(width: 8),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: HouseColors.ruby.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            ),
            icon: const Icon(
              Icons.chat_bubble_rounded,
              color: HouseColors.ruby,
              size: 20,
            ),
            tooltip: '1-on-1 Chats',
          ),
          const SizedBox(width: 8),
          if (widget.isSuperAdmin || _canReviewMedical) ...[
            IconButton(
              key: const Key('admin_portal_class_groups_button'),
              style: IconButton.styleFrom(
                backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClassGroupScreen()),
              ),
              icon: const Icon(
                Icons.school_rounded,
                color: Colors.indigoAccent,
                size: 20,
              ),
              tooltip: 'Class Groups & Messaging',
            ),
            const SizedBox(width: 8),
          ],
          if (widget.isSuperAdmin) ...[
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.amber.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _showCouncilRosterDialog(context),
              icon: const Icon(
                Icons.people_alt_rounded,
                color: Colors.amber,
                size: 20,
              ),
              tooltip: 'Council Roster',
            ),
            const SizedBox(width: 8),
          ],
          PopupMenuButton<String>(
            tooltip: 'Administrative Tools',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'class_groups') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClassGroupScreen(),
                  ),
                );
                return;
              }
              if (value == 'academic_management') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAcademicsScreen(),
                  ),
                );
                return;
              }
              if (value == 'migrate_contributors') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Starting legacy contributor migration...')),
                );
                final count = await AuthService.migrateLegacyContributorDocs();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Migration complete: $count legacy contributor record(s) merged into unified scheme.'),
                      backgroundColor: Colors.green[700],
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              if (widget.isSuperAdmin || _canReviewMedical)
                const PopupMenuItem(
                  value: 'class_groups',
                  child: Row(
                    children: [
                      Icon(Icons.forum_rounded, size: 20, color: Colors.indigoAccent),
                      SizedBox(width: 10),
                      Text('Class Groups & Messaging', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              if (_canReviewMedical)
                const PopupMenuItem(
                  value: 'academic_management',
                  child: Row(
                    children: [
                      Icon(Icons.school_rounded, size: 20, color: Colors.indigo),
                      SizedBox(width: 10),
                      Text('Academic Management', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'migrate_contributors',
                child: Row(
                  children: [
                    Icon(Icons.merge_type_rounded, size: 20, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text('Merge Legacy Contributors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: _canReviewMedical
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                indicatorWeight: 3,
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.verified_user_rounded, size: 20),
                    text: 'Point Claims',
                  ),
                  Tab(
                    icon: Icon(Icons.medical_services_rounded, size: 20),
                    text: 'Medical Reports',
                  ),
                ],
              )
            : null,
      ),
      body: _canReviewMedical
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildClaimsTab(),
                _buildMedicalReportsTab(),
              ],
            )
          : _buildClaimsTab(),
    );
  }

  Widget _buildClaimsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search pending claims by student, house, title...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? Semantics(
                      button: true,
                      label: 'Clear search',
                      child: IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    )
                  : null,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _authService.getPendingClaimsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 64,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'All Caught Up!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'There are currently no pending house points claims waiting for manual verification.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ApprovedClaimsScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text(
                            'View Approved Achievements Gallery',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final allDocs = snapshot.data!.docs;
              final docs = allDocs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final raw = doc.data();
                final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                final sName = (data['student_name'] ?? '').toString().toLowerCase();
                final sNo = (data['scholar_no'] ?? '').toString().toLowerCase();
                final title = (data['activity_title'] ?? '').toString().toLowerCase();
                final house = (data['house_name'] ?? '').toString().toLowerCase();
                return sName.contains(_searchQuery) ||
                    sNo.contains(_searchQuery) ||
                    title.contains(_searchQuery) ||
                    house.contains(_searchQuery);
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[400]),
                        const SizedBox(height: 14),
                        const Text(
                          'No Matching Claims',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No pending claims matched "$_searchQuery".',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final raw = doc.data();
                  final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                  final claimId = doc.id;
                  final studentName = data['student_name'] ?? 'Unknown Student';
                  final scholarNo = data['scholar_no'] ?? '---';
                  final houseName = (data['house_name'] ?? 'ruby')
                      .toString()
                      .toLowerCase();
                  final activityTitle =
                      data['activity_title'] ?? 'Competition Entry';
                  final points = (data['points'] as num?)?.toInt() ?? 10;
                  final certUrl = data['cert_url'] ?? 'Certificate Uploaded';
                  final isProcessing = _processingClaimIds.contains(claimId);

                  final houseColor = HouseColors.getHouseColor(houseName);
                  final houseDisplay = houseName.isNotEmpty
                      ? '${houseName[0].toUpperCase()}${houseName.substring(1)}'
                      : 'Unknown';

                  return Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => StudentProfileModal.show(
                                  context,
                                  scholarNo: scholarNo,
                                  studentName: studentName,
                                  houseName: houseName,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: houseColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$houseDisplay House',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: houseColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Scholar #$scholarNo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: houseColor,
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                '+$points Pts',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.amber[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          activityTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => StudentProfileModal.show(
                            context,
                            scholarNo: scholarNo,
                            studentName: studentName,
                            houseName: houseName,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Submitted by $studentName',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.cyanAccent
                                      : const Color(0xFF0369A1),
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.cyanAccent
                                    : const Color(0xFF0369A1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () =>
                              _showCertificateDialog(certUrl, activityTitle),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Inspect Attached Certificate',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (data['ai_status'] != null) ...[
                          const SizedBox(height: 10),
                          Builder(builder: (context) {
                            final aiStatus = data['ai_status']?.toString().toLowerCase();
                            final aiConfidence = (data['ai_confidence'] as num?)?.toDouble() ?? 0.0;
                            final aiSummary = data['ai_summary']?.toString() ?? '';

                            if (aiStatus == 'verified') {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.verified_rounded, color: Colors.green, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'AI Seal Matched (${aiConfidence.toInt()}% confidence)\n${aiSummary.isNotEmpty ? aiSummary : "Institutional marker detected"}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (aiStatus == 'unrecognized') {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'AI Warning: No official school seal detected. Manual staff inspection required.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Cloud Vision AI scanning certificate in background...',
                                      style: TextStyle(fontSize: 11, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }),
                        ],
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.redAccent,
                                        ),
                                      )
                                    : const Icon(Icons.close_rounded, size: 20),
                                label: Text(
                                  isProcessing ? 'Processing...' : 'Reject',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                onPressed: isProcessing
                                    ? null
                                    : () => _handleReject(claimId, studentName),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_rounded, size: 20),
                                label: Text(
                                  isProcessing ? 'Processing...' : 'Approve',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                onPressed: isProcessing
                                    ? null
                                    : () => _handleApprove(
                                        claimId,
                                        houseName,
                                        points,
                                        studentName,
                                        scholarNo,
                                        activityTitle,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildMedicalReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (val) =>
                setState(() => _searchQuery = val.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search medical leaves by student, doctor, diagnosis...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? Semantics(
                      button: true,
                      label: 'Clear search',
                      child: IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    )
                  : null,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<MedicalLeaveRequest>>(
            stream: _authService.getMedicalLeavesStream(),
            builder: (context, snapshot) {
              final leaves = snapshot.data ?? AuthService.getCachedMedicalLeaves();
              final pendingCount = leaves.where((l) => l.status == MedicalLeaveStatus.pending).length;
              final approvedCount = leaves.where((l) => l.status == MedicalLeaveStatus.approved).length;
              final rejectedCount = leaves.where((l) => l.status == MedicalLeaveStatus.rejected).length;

              // Filter by status tab
              List<MedicalLeaveRequest> statusFiltered = leaves;
              if (_medicalStatusFilter == 'pending') {
                statusFiltered = leaves.where((l) => l.status == MedicalLeaveStatus.pending).toList();
              } else if (_medicalStatusFilter == 'approved') {
                statusFiltered = leaves.where((l) => l.status == MedicalLeaveStatus.approved).toList();
              } else if (_medicalStatusFilter == 'rejected') {
                statusFiltered = leaves.where((l) => l.status == MedicalLeaveStatus.rejected).toList();
              }

              final filtered = statusFiltered.where((l) {
                if (_searchQuery.isEmpty) return true;
                return l.studentName.toLowerCase().contains(_searchQuery) ||
                    l.scholarNo.toLowerCase().contains(_searchQuery) ||
                    l.doctorName.toLowerCase().contains(_searchQuery) ||
                    l.reason.toLowerCase().contains(_searchQuery) ||
                    l.house.toLowerCase().contains(_searchQuery);
              }).toList();

              return Column(
                children: [
                  // Filter Chips Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text('All (${leaves.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            selected: _medicalStatusFilter == 'all',
                            onSelected: (val) {
                              if (val) setState(() => _medicalStatusFilter = 'all');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Pending ($pendingCount)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            selected: _medicalStatusFilter == 'pending',
                            selectedColor: Colors.amber.withValues(alpha: 0.3),
                            onSelected: (val) {
                              if (val) setState(() => _medicalStatusFilter = 'pending');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Approved ($approvedCount)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            selected: _medicalStatusFilter == 'approved',
                            selectedColor: Colors.teal.withValues(alpha: 0.3),
                            onSelected: (val) {
                              if (val) setState(() => _medicalStatusFilter = 'approved');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text('Declined ($rejectedCount)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            selected: _medicalStatusFilter == 'rejected',
                            selectedColor: Colors.redAccent.withValues(alpha: 0.3),
                            onSelected: (val) {
                              if (val) setState(() => _medicalStatusFilter = 'rejected');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.healing_rounded,
                                      size: 56,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _medicalStatusFilter == 'pending'
                                        ? 'No Pending Medical Reports'
                                        : 'No Medical Reports Found',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No records matched "$_searchQuery".'
                                        : 'No medical submissions in this filter category.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              return _buildMedicalLeaveCard(filtered[index]);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalLeaveCard(MedicalLeaveRequest leave) {
    final houseColor = HouseColors.getHouseColor(leave.house);
    final houseDisplay = leave.house.isNotEmpty
        ? '${leave.house[0].toUpperCase()}${leave.house.substring(1)}'
        : 'Ruby';
    final isProcessing = _processingClaimIds.contains(leave.id);
    final hasPhoto = leave.hasCertificatePhoto;
    final isApproved = leave.status == MedicalLeaveStatus.approved;
    final isRejected = leave.status == MedicalLeaveStatus.rejected;
    final isPending = leave.status == MedicalLeaveStatus.pending;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => StudentProfileModal.show(
                  context,
                  scholarNo: leave.scholarNo,
                  studentName: leave.studentName,
                  houseName: leave.house,
                  classLevel: leave.classLevel,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: houseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$houseDisplay House',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: houseColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Scholar #${leave.scholarNo}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: houseColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isApproved
                      ? Colors.green.withValues(alpha: 0.15)
                      : (isRejected
                          ? Colors.red.withValues(alpha: 0.15)
                          : Colors.teal.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved
                          ? Icons.check_circle_rounded
                          : (isRejected ? Icons.cancel_rounded : Icons.date_range_rounded),
                      size: 13,
                      color: isApproved ? Colors.green[700] : (isRejected ? Colors.redAccent : Colors.teal),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isApproved
                          ? 'Approved (${leave.durationDays}d)'
                          : (isRejected
                              ? 'Declined'
                              : '${leave.durationDays} ${leave.durationDays == 1 ? "Day" : "Days"}'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isApproved ? Colors.green[800] : (isRejected ? Colors.redAccent : Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => StudentProfileModal.show(
              context,
              scholarNo: leave.scholarNo,
              studentName: leave.studentName,
              houseName: leave.house,
              classLevel: leave.classLevel,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  leave.studentName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.cyanAccent
                        : const Color(0xFF0369A1),
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.cyanAccent
                      : const Color(0xFF0369A1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Class: ${leave.classLevel.isNotEmpty ? leave.classLevel : "Grade 11"} • Period: ${leave.formattedRange}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leave.doctorName.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.local_hospital_rounded, size: 14, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text(
                        'Physician: ${leave.doctorName}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  'Diagnosis / Reason: ${leave.reason}',
                  style: const TextStyle(fontSize: 13, height: 1.3),
                ),
                if (leave.adminRemark != null && leave.adminRemark!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isApproved ? Colors.green : Colors.redAccent).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Admin Review: ${leave.adminRemark}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isApproved ? Colors.green[800] : Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: hasPhoto ? () => _showPrescriptionDialog(leave) : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: hasPhoto ? Colors.teal.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasPhoto ? Colors.teal.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasPhoto ? Icons.photo_library_rounded : Icons.hide_image_outlined,
                    color: hasPhoto ? Colors.teal : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasPhoto ? 'Inspect Doctor Certificate & Prescription' : 'No Prescription Photo Attached',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hasPhoto ? Colors.teal : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.grey.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.redAccent,
                            ),
                          )
                        : const Icon(Icons.close_rounded, size: 18),
                    label: Text(
                      isProcessing ? 'Processing...' : 'Decline',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () => _handleRejectMedicalLeave(leave.id, leave.studentName),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      isProcessing ? 'Processing...' : 'Approve Leave',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () => _handleApproveMedicalLeave(leave.id, leave.studentName),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CouncilRosterManagementDialog extends StatefulWidget {
  final AuthService authService;

  const _CouncilRosterManagementDialog({
    required this.authService,
  });

  @override
  State<_CouncilRosterManagementDialog> createState() =>
      _CouncilRosterManagementDialogState();
}

class _CouncilRosterManagementDialogState
    extends State<_CouncilRosterManagementDialog> {
  String _selectedFilter = 'all'; // 'all', 'teacher', 'council', 'captain', 'prefect'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openDirectAssignDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _DirectRoleAssignDialog(
        authService: widget.authService,
      ),
    );
  }

  void _editRosterSlot(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => EditRosterSlotDialog(
        docId: docId,
        data: data,
        authService: widget.authService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.military_tech_rounded,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Faculty & Council Roster',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Dynamic Role & Authority Management',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
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
              const SizedBox(height: 16),

              // Action Buttons Row
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HouseColors.ruby,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () => _openDirectAssignDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text(
                      '➕ Assign Role & Position',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber[800],
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () async {
                      await widget.authService.seedAdminRoster();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Standard roster templates initialized!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text(
                      '⚡ Seed Templates',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Bar
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search scholar no, name, or title...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? Semantics(
                          button: true,
                          label: 'Clear search',
                          child: IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All Roster'),
                    const SizedBox(width: 6),
                    _buildFilterChip('teacher', '👨‍🏫 Faculty / Teachers'),
                    const SizedBox(width: 6),
                    _buildFilterChip('council', '🏛️ Executive Council'),
                    const SizedBox(width: 6),
                    _buildFilterChip('captain', '🏆 House Captains'),
                    const SizedBox(width: 6),
                    _buildFilterChip('prefect', '🎖️ Grade Prefects'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Roster Stream
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('admin_roster')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.folder_open_rounded,
                              size: 40,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No roster slots created yet.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => widget.authService.seedAdminRoster(),
                              child: const Text('Initialize Roster Slots'),
                            ),
                          ],
                        ),
                      );
                    }

                    final filtered = docs.where((doc) {
                      final raw = doc.data();
                      final data = raw is Map
                          ? Map<String, dynamic>.from(raw)
                          : <String, dynamic>{};
                      final role = (data['role'] ?? '').toString().toLowerCase();
                      final title = (data['title'] ?? '').toString().toLowerCase();
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final sNo = (data['scholar_no'] ?? '').toString().toLowerCase();

                      // Category filter
                      if (_selectedFilter == 'teacher' &&
                          !(role == 'teacher' ||
                              role == 'faculty' ||
                              role == 'faculty_advisor' ||
                              role == 'teacher_lead')) {
                        return false;
                      }
                      if (_selectedFilter == 'council' &&
                          !(role == 'council' ||
                              role == 'head_boy' ||
                              role == 'head_girl' ||
                              role == 'deputy_head_boy' ||
                              role == 'deputy_head_girl' ||
                              role == 'cultural_secretary')) {
                        return false;
                      }
                      if (_selectedFilter == 'captain' &&
                          !(role == 'captain' ||
                              role == 'house_captain' ||
                              role == 'sports_captain')) {
                        return false;
                      }
                      if (_selectedFilter == 'prefect' &&
                          !(role == 'prefect' || role == 'student_rep')) {
                        return false;
                      }

                      // Search filter
                      if (_searchQuery.isNotEmpty) {
                        final matches = title.contains(_searchQuery) ||
                            name.contains(_searchQuery) ||
                            sNo.contains(_searchQuery) ||
                            role.contains(_searchQuery);
                        if (!matches) return false;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'No matching roster slots found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final raw = filtered[i].data();
                        final data = raw is Map
                            ? Map<String, dynamic>.from(raw)
                            : <String, dynamic>{};
                        final title = data['title'] ?? 'Role Slot';
                        final name = data['name'] ?? 'Vacant';
                        final scholarNo = (data['scholar_no'] ?? '').toString();
                        final role = (data['role'] ?? 'council').toString();
                        final cls = data['class'] ?? '';
                        final isVacant =
                            scholarNo.isEmpty || name.toString().contains('Vacant');

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              _buildRoleAvatar(role, isVacant),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _buildRoleBadge(role),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cls.isNotEmpty
                                          ? '$name ($cls) • Scholar: ${scholarNo.isEmpty ? "Unassigned" : scholarNo}'
                                          : '$name • Scholar: ${scholarNo.isEmpty ? "Unassigned" : scholarNo}',
                                      style: TextStyle(
                                        color: isVacant
                                            ? Colors.red[400]
                                            : (isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700]),
                                        fontSize: 12,
                                        fontWeight: isVacant
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: scholarNo.isEmpty
                                      ? HouseColors.ruby
                                      : (isDark
                                          ? const Color(0xFF334155)
                                          : Colors.grey[800]),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(70, 34),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => _editRosterSlot(
                                  context,
                                  filtered[i].id,
                                  data,
                                ),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  size: 13,
                                ),
                                label: Text(
                                  scholarNo.isEmpty ? 'Assign' : 'Edit',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selectedColor: HouseColors.ruby,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    );
  }

  Widget _buildRoleAvatar(String role, bool isVacant) {
    Color bg;
    IconData icon;
    final r = role.toLowerCase();

    if (isVacant) {
      bg = Colors.grey.withValues(alpha: 0.2);
      icon = Icons.person_outline_rounded;
    } else if (r == 'teacher' || r == 'faculty') {
      bg = Colors.purple.withValues(alpha: 0.2);
      icon = Icons.school_rounded;
    } else if (r == 'captain') {
      bg = Colors.amber.withValues(alpha: 0.2);
      icon = Icons.military_tech_rounded;
    } else if (r == 'prefect') {
      bg = Colors.blue.withValues(alpha: 0.2);
      icon = Icons.verified_user_rounded;
    } else {
      bg = Colors.teal.withValues(alpha: 0.2);
      icon = Icons.stars_rounded;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Icon(
        icon,
        size: 18,
        color: isVacant
            ? Colors.grey
            : (r == 'teacher'
                ? Colors.purple
                : (r == 'captain'
                    ? Colors.amber[800]
                    : (r == 'prefect' ? Colors.blue : Colors.green))),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final r = role.toLowerCase();
    String text;
    Color color;

    if (r == 'teacher' || r == 'faculty') {
      text = 'FACULTY';
      color = Colors.purple;
    } else if (r == 'captain') {
      text = 'CAPTAIN';
      color = Colors.amber[800]!;
    } else if (r == 'prefect') {
      text = 'PREFECT';
      color = Colors.blue;
    } else if (r == 'super_admin' || r == 'admin') {
      text = 'ADMIN';
      color = Colors.red;
    } else {
      text = 'COUNCIL';
      color = Colors.teal;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

/// Direct Role Assignment Modal: Allows Super Admin to assign Teacher, Council, Captain,
/// or Prefect roles directly to ANY scholar number with designated custom positions.
class _DirectRoleAssignDialog extends StatefulWidget {
  final AuthService authService;

  const _DirectRoleAssignDialog({required this.authService});

  @override
  State<_DirectRoleAssignDialog> createState() =>
      _DirectRoleAssignDialogState();
}

class _DirectRoleAssignDialogState extends State<_DirectRoleAssignDialog> {
  final _formKey = GlobalKey<FormState>();
  final _scholarCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _positionTitleCtrl = TextEditingController();
  final _classCtrl = TextEditingController();

  String _selectedRole = 'teacher'; // 'teacher', 'council', 'captain', 'prefect', 'super_admin', 'student'
  String _selectedHouse = 'All'; // 'All', 'Ruby', 'Sapphire', 'Emerald', 'Topaz'
  bool _isSaving = false;

  @override
  void dispose() {
    _scholarCtrl.dispose();
    _nameCtrl.dispose();
    _positionTitleCtrl.dispose();
    _classCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAssign() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final success = await widget.authService.assignUserRoleAndPosition(
        scholarNo: _scholarCtrl.text.trim(),
        role: _selectedRole,
        name: _nameCtrl.text.trim(),
        positionTitle: _positionTitleCtrl.text.trim().isNotEmpty
            ? _positionTitleCtrl.text.trim()
            : null,
        houseName: _selectedHouse,
        classLevel: _classCtrl.text.trim().isNotEmpty
            ? _classCtrl.text.trim()
            : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Successfully assigned ${_selectedRole.toUpperCase()} role to ${_scholarCtrl.text.trim()}!'
                : '⚠️ Role registered in roster! (Will auto-link when user logs in)',
          ),
          backgroundColor: success ? Colors.green[700] : Colors.amber[800],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.assignment_ind_rounded, color: HouseColors.ruby),
          SizedBox(width: 8),
          Text(
            'Assign Official Role',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the scholar number and select the designated authority role and title.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),

              // Scholar Number
              TextFormField(
                controller: _scholarCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Scholar Number *',
                  hintText: 'e.g. 123456 or 11209',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a scholar number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Member Full Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Member Full Name *',
                  hintText: 'e.g. Mr. Rajiv Sharma or Sara Ahmed',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter member name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Role Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role Authority Level *',
                  prefixIcon: Icon(Icons.security_rounded, size: 20),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'teacher',
                    child: Text('👨‍🏫 Faculty / Teacher Lead'),
                  ),
                  DropdownMenuItem(
                    value: 'council',
                    child: Text('🏛️ Executive Council Officer'),
                  ),
                  DropdownMenuItem(
                    value: 'captain',
                    child: Text('🏆 House Captain / Vice Captain'),
                  ),
                  DropdownMenuItem(
                    value: 'prefect',
                    child: Text('🎖️ Grade Prefect / Student Rep'),
                  ),
                  DropdownMenuItem(
                    value: 'super_admin',
                    child: Text('👑 Super Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'student',
                    child: Text('🎓 Student Member'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                      if (_selectedRole == 'teacher' &&
                          _positionTitleCtrl.text.isEmpty) {
                        _positionTitleCtrl.text = 'Faculty Advisor';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              // Position / Designation Title
              TextFormField(
                controller: _positionTitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Designation / Position Title',
                  hintText: 'e.g. Senior Faculty Advisor, Head Boy, Sports Captain',
                  prefixIcon: Icon(Icons.title_rounded, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // House Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedHouse,
                decoration: const InputDecoration(
                  labelText: 'Assigned House',
                  prefixIcon: Icon(Icons.shield_outlined, size: 20),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Houses / School-Wide')),
                  DropdownMenuItem(value: 'Ruby', child: Text('🔴 Ruby House')),
                  DropdownMenuItem(value: 'Sapphire', child: Text('🔵 Sapphire House')),
                  DropdownMenuItem(value: 'Emerald', child: Text('🟢 Emerald House')),
                  DropdownMenuItem(value: 'Topaz', child: Text('🟡 Topaz House')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedHouse = val);
                },
              ),
              const SizedBox(height: 12),

              // Department / Grade Class
              TextFormField(
                controller: _classCtrl,
                decoration: const InputDecoration(
                  labelText: 'Class / Department (Optional)',
                  hintText: 'e.g. Faculty, Grade 11, Grade 12',
                  prefixIcon: Icon(Icons.class_outlined, size: 20),
                  border: OutlineInputBorder(),
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
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: HouseColors.ruby,
            foregroundColor: Colors.white,
            minimumSize: const Size(100, 42),
          ),
          onPressed: _isSaving ? null : _handleAssign,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Approve & Assign'),
        ),
      ],
    );
  }
}

/// Edit Roster Slot Dialog: Allows updating an existing slot, changing role/position, or vacating.
@visibleForTesting
class EditRosterSlotDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final AuthService authService;

  const EditRosterSlotDialog({
    super.key,
    required this.docId,
    required this.data,
    required this.authService,
  });

  @override
  State<EditRosterSlotDialog> createState() => _EditRosterSlotDialogState();
}

class _EditRosterSlotDialogState extends State<EditRosterSlotDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _scholarCtrl;
  late final TextEditingController _titleCtrl;
  late String _role;
  late String _house;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data['name'] ?? '');
    _scholarCtrl = TextEditingController(text: widget.data['scholar_no'] ?? '');
    _titleCtrl = TextEditingController(text: widget.data['title'] ?? '');
    _role = (widget.data['role'] ?? 'council').toString();
    _house = (widget.data['house'] ?? 'All').toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scholarCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final newName = _nameCtrl.text.trim();
      final newScholar = _scholarCtrl.text.trim();
      final newTitle = _titleCtrl.text.trim();

      await FirebaseFirestore.instance
          .collection('admin_roster')
          .doc(widget.docId)
          .update({
            'name': newName.isNotEmpty ? newName : 'Vacant Slot',
            'scholar_no': newScholar,
            'title': newTitle.isNotEmpty ? newTitle : widget.data['title'],
            'role': _role,
            'house': _house,
          });

      if (newScholar.isNotEmpty) {
        await widget.authService.syncRosterRoleToUser(
          scholarNo: newScholar,
          role: _role,
          name: newName,
          slotTitle: newTitle,
          houseName: _house,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update roster slot: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleVacate() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final storedScholar = (widget.data['scholar_no'] ?? '').toString().trim();
      final oldScholar =
          storedScholar.isNotEmpty ? storedScholar : _scholarCtrl.text.trim();
      await widget.authService.revokeUserRole(
        scholarNo: oldScholar,
        slotId: widget.docId,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slot vacated and privileges reset.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to vacate roster slot: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Edit ${widget.data['title'] ?? 'Slot'}',
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Position / Slot Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Member Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scholarCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Scholar Number (6 Digits)',
                hintText: 'e.g. 123456',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: ['teacher', 'council', 'captain', 'prefect', 'super_admin', 'student'].contains(_role)
                  ? _role
                  : 'council',
              decoration: const InputDecoration(
                labelText: 'Role Category',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'teacher', child: Text('👨‍🏫 Faculty / Teacher')),
                DropdownMenuItem(value: 'council', child: Text('🏛️ Executive Council')),
                DropdownMenuItem(value: 'captain', child: Text('🏆 House Captain')),
                DropdownMenuItem(value: 'prefect', child: Text('🎖️ Grade Prefect')),
                DropdownMenuItem(value: 'super_admin', child: Text('👑 Super Admin')),
                DropdownMenuItem(value: 'student', child: Text('🎓 Student Member')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _role = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        if (((widget.data['scholar_no'] ?? '').toString().trim()).isNotEmpty ||
            _scholarCtrl.text.trim().isNotEmpty)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _isSaving ? null : _handleVacate,
            icon: const Icon(Icons.person_remove_rounded, size: 16),
            label: const Text('Vacate / Revoke'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: HouseColors.ruby,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 40),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

