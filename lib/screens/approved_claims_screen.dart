import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ApprovedClaimsScreen extends StatefulWidget {
  const ApprovedClaimsScreen({super.key});

  @override
  State<ApprovedClaimsScreen> createState() => _ApprovedClaimsScreenState();
}

class _ApprovedClaimsScreenState extends State<ApprovedClaimsScreen> {
  final _authService = AuthService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedHouseFilter = 'All';

  final List<String> _houseFilters = [
    'All',
    'Ruby',
    'Emerald',
    'Topaz',
    'Sapphire',
  ];

  void _showCertificateDialog(
    String certUrl,
    String activityTitle,
    String studentName,
    int points,
  ) {
    Widget imagePreview;
    if (certUrl.startsWith('data:image/')) {
      try {
        final commaIdx = certUrl.indexOf(',');
        final base64Str = certUrl.substring(commaIdx + 1);
        final bytes = base64Decode(base64Str);
        imagePreview = ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(
            child: Image.memory(bytes, fit: BoxFit.contain, height: 400),
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
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          child: Image.network(certUrl, fit: BoxFit.contain, height: 400),
        ),
      );
    } else {
      imagePreview = Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.verified_rounded, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Verified Achievement Record',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              certUrl.isNotEmpty
                  ? certUrl
                  : 'Official competition documentation attached & approved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                activityTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Approved +$points Points for $studentName',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(child: imagePreview),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Pinch or drag photo to zoom and inspect details.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close Preview',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Approved Achievements Gallery',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search approved student or scholar #...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.grey,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1A2338)
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _houseFilters.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final h = _houseFilters[idx];
                      final isSel = _selectedHouseFilter == h;
                      final houseColor = h == 'All'
                          ? Colors.green
                          : HouseColors.getHouseColor(h);
                      return InkWell(
                        onTap: () => setState(() => _selectedHouseFilter = h),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? houseColor
                                : (isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.grey[200]),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel ? houseColor : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            h == 'All' ? '🌟 All Houses' : '$h House',
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Approved Claims List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _authService.getApprovedClaimsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 72,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Approved Claims Yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Once council members or admins approve student competition submissions, the verified photos and records will appear in this gallery.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final raw = doc.data();
                  final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                  final name = (data['student_name'] ?? '')
                      .toString()
                      .toLowerCase();
                  final scholar = (data['scholar_no'] ?? '')
                      .toString()
                      .toLowerCase();
                  final title = (data['activity_title'] ?? '')
                      .toString()
                      .toLowerCase();
                  final house = (data['house_name'] ?? '')
                      .toString()
                      .toLowerCase();

                  // Search check
                  if (_searchQuery.isNotEmpty) {
                    if (!name.contains(_searchQuery) &&
                        !scholar.contains(_searchQuery) &&
                        !title.contains(_searchQuery)) {
                      return false;
                    }
                  }

                  // House filter check
                  if (_selectedHouseFilter != 'All') {
                    if (house != _selectedHouseFilter.toLowerCase()) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No approved achievements match your search or filter criteria.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final raw = docs[i].data();
                    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                    final scholarNo = data['scholar_no'] ?? 'N/A';
                    final studentName =
                        data['student_name'] ?? 'Unknown Student';
                    final house = (data['house_name'] ?? 'ruby').toString();
                    final activityTitle =
                        data['activity_title'] ?? 'Competition Achievement';
                    final points = (data['points'] as num?)?.toInt() ?? 0;
                    final certUrl = (data['cert_url'] ?? '').toString();

                    final houseColor = HouseColors.getHouseColor(house);
                    final houseDisplay = house.isNotEmpty
                        ? '${house[0].toUpperCase()}${house.substring(1)}'
                        : 'Ruby';

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: houseColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: houseColor.withValues(alpha: 0.08),
                            blurRadius: 16,
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
                                        color: houseColor.withValues(
                                          alpha: 0.15,
                                        ),
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
                                  color: Colors.green.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.green,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '+$points Pts Approved',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.green,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            activityTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verified for $studentName',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => _showCertificateDialog(
                              certUrl,
                              activityTitle,
                              studentName,
                              points,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.photo_library_rounded,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Inspect Approved Photo / Certificate',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
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
    );
  }
}
