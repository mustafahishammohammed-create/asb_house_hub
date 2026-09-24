import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'chat_list_screen.dart';
import 'approved_claims_screen.dart';

class AdminClaimsScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const AdminClaimsScreen({super.key, this.isSuperAdmin = false});

  @override
  State<AdminClaimsScreen> createState() => _AdminClaimsScreenState();
}

class _AdminClaimsScreenState extends State<AdminClaimsScreen> {
  final _authService = AuthService();

  void _handleApprove(
    String claimId,
    String houseName,
    int points,
    String studentName,
    String scholarNo,
    String activityTitle,
  ) async {
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
    }
  }

  void _handleReject(String claimId, String studentName) async {
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
    }
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
          child: Image.memory(bytes, fit: BoxFit.contain, height: 350),
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
        child: Image.network(certUrl, fit: BoxFit.contain, height: 350),
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
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 550,
          height: 600,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Council & Admin Roster',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Assign Scholar Numbers or edit member names below.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
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
                        return const Center(
                          child: Text('No roster slots seeded yet.'),
                        );
                      }
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final title = data['title'] ?? 'Slot';
                          final name = data['name'] ?? 'Vacant';
                          final scholarNo = data['scholar_no'] ?? '';
                          final cls = data['class'] ?? '';
                          final isVacant = name.toString().contains('Vacant');

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isVacant
                                      ? Colors.grey[200]
                                      : Colors.amber.withValues(alpha: 0.2),
                                  child: Icon(
                                    isVacant
                                        ? Icons.person_outline_rounded
                                        : Icons.person_rounded,
                                    color: isVacant
                                        ? Colors.grey
                                        : Colors.amber[800],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cls.isNotEmpty
                                            ? '$name ($cls) • Scholar No: ${scholarNo.isEmpty ? "Unassigned" : scholarNo}'
                                            : '$name • Scholar No: ${scholarNo.isEmpty ? "Unassigned" : scholarNo}',
                                        style: TextStyle(
                                          color: isVacant
                                              ? Colors.red[400]
                                              : Colors.grey[700],
                                          fontSize: 13,
                                          fontWeight: isVacant
                                              ? FontWeight.w500
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
                                        : Colors.grey[800],
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(80, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () => _editRosterSlot(
                                    context,
                                    docs[i].id,
                                    data,
                                  ),
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                  ),
                                  label: Text(
                                    scholarNo.isEmpty ? 'Assign' : 'Edit',
                                    style: const TextStyle(
                                      fontSize: 12,
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
      ),
    );
  }

  void _editRosterSlot(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final scholarCtrl = TextEditingController(text: data['scholar_no'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${data['title']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Member Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: scholarCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Scholar Number (6 Digits)',
                hintText: 'e.g. 123456',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newScholar = scholarCtrl.text.trim();
              await FirebaseFirestore.instance
                  .collection('admin_roster')
                  .doc(docId)
                  .update({
                    'name': newName,
                    'scholar_no': newScholar,
                  });

              // Synchronize role directly into the user's profile and notify them
              if (newScholar.isNotEmpty) {
                final slotRole = (data['role'] ?? 'council').toString();
                final slotTitle =
                    (data['title'] ?? 'Council Officer').toString();
                await _authService.syncRosterRoleToUser(
                  scholarNo: newScholar,
                  role: slotRole,
                  name: newName,
                  slotTitle: slotTitle,
                );
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
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
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _authService.getPendingClaimsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(36),
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

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
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
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
                    Text(
                      'Submitted by $studentName',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
                            icon: const Icon(Icons.close_rounded, size: 20),
                            label: const Text(
                              'Reject',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: () =>
                                _handleReject(claimId, studentName),
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
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: const Text(
                              'Approve',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            onPressed: () => _handleApprove(
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
    );
  }
}
