import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class HouseLeaderboardScreen extends StatefulWidget {
  final String initialHouse;
  final int initialPoints;

  const HouseLeaderboardScreen({
    super.key,
    required this.initialHouse,
    this.initialPoints = 0,
  });

  @override
  State<HouseLeaderboardScreen> createState() => _HouseLeaderboardScreenState();
}

class _HouseLeaderboardScreenState extends State<HouseLeaderboardScreen> {
  final _authService = AuthService();
  late String _selectedHouse;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _houses = ['Ruby', 'Emerald', 'Sapphire', 'Topaz'];

  final Map<String, Map<String, String>> _houseDetails = {
    'Ruby': {
      'motto': 'Courage, Passion & Victory',
      'captain': 'Ruby House Captain Council',
      'icon': '🛡️',
    },
    'Emerald': {
      'motto': 'Wisdom, Growth & Honor',
      'captain': 'Emerald House Captain Council',
      'icon': '🌿',
    },
    'Sapphire': {
      'motto': 'Integrity, Loyalty & Truth',
      'captain': 'Sapphire House Captain Council',
      'icon': '💎',
    },
    'Topaz': {
      'motto': 'Brilliance, Strength & Unity',
      'captain': 'Topaz House Captain Council',
      'icon': '⚡',
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedHouse = widget.initialHouse.isNotEmpty
        ? '${widget.initialHouse[0].toUpperCase()}${widget.initialHouse.substring(1).toLowerCase()}'
        : 'Ruby';
    _authService.seedSampleContributors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showStudentContributionModal(Map<String, dynamic> contributor, Color houseColor) {
    final name = contributor['student_name'] ?? 'Student';
    final scholar = contributor['scholar_no'] ?? 'N/A';
    final points = contributor['total_contributed'] ?? 0;
    final merits = contributor['merits_count'] ?? 0;
    final demerits = contributor['demerits_count'] ?? 0;
    final cls = contributor['class_level'] ?? 'Senior Tier';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 32,
              backgroundColor: houseColor.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: houseColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(
              'Scholar #$scholar • $_selectedHouse House • $cls',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Metrics row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: houseColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '+$points Pts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: houseColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Total Contributed',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$merits',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Merits / Rewards',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$demerits',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Demerit Penalties',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: houseColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseColor = HouseColors.getHouseColor(_selectedHouse);
    final darkColor = HouseColors.getHouseDarkColor(_selectedHouse);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = _houseDetails[_selectedHouse] ?? _houseDetails['Ruby']!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          '$_selectedHouse House Leaderboard',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // House Switcher Pill Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: _houses.map((h) {
                final isSel = _selectedHouse == h;
                final c = HouseColors.getHouseColor(h);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _selectedHouse = h),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel
                              ? c
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            h,
                            style: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Main Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // House Hero Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [houseColor, darkColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: houseColor.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(info['icon']!, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_selectedHouse.toUpperCase()} HOUSE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('house_points')
                                  .doc(_selectedHouse.toLowerCase())
                                  .snapshots(),
                              builder: (context, snap) {
                                final pts = snap.hasData && snap.data!.exists
                                    ? ((snap.data!.data() as Map<String, dynamic>?)?['total_points'] ?? widget.initialPoints)
                                    : widget.initialPoints;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$pts Pts Total',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$_selectedHouse House Roster',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Motto: "${info['motto']}"',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'House Captain: ${info['captain']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search Filter
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search $_selectedHouse student name or scholar #...',
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
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
                      fillColor: isDark ? const Color(0xFF151D2E) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Contributor Stream & Podium
                  StreamBuilder<QuerySnapshot>(
                    stream: _authService.getHouseContributorsStream(_selectedHouse),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      var docs = snapshot.data?.docs.map((d) {
                        final raw = d.data();
                        if (raw is Map<String, dynamic>) return raw;
                        if (raw is Map) return Map<String, dynamic>.from(raw);
                        return <String, dynamic>{};
                      }).where((m) => m.isNotEmpty).toList() ?? [];

                      // Sort by total_contributed descending
                      docs.sort((a, b) {
                        final ptsA = (a['total_contributed'] as num?)?.toInt() ?? 0;
                        final ptsB = (b['total_contributed'] as num?)?.toInt() ?? 0;
                        return ptsB.compareTo(ptsA);
                      });

                      // Apply search filter
                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((d) {
                          final name = (d['student_name'] ?? '').toString().toLowerCase();
                          final scholar = (d['scholar_no'] ?? '').toString().toLowerCase();
                          return name.contains(_searchQuery) || scholar.contains(_searchQuery);
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline_rounded, size: 54, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'No contributors found for $_selectedHouse House.',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Top 3 Podium if at least 3 students exist and no search query
                      final showPodium = docs.length >= 3 && _searchQuery.isEmpty;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showPodium) ...[
                            const Row(
                              children: [
                                Text('🏆 Top Contributors Podium', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildPodium(docs.take(3).toList(), houseColor, isDark),
                            const SizedBox(height: 28),
                          ],

                          // All Contributors Ranked List
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'All Contributors (${docs.length})',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                              Text(
                                'Tap row for breakdown',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = docs[index];
                              final rank = index + 1;
                              final name = item['student_name'] ?? 'Student';
                              final scholar = item['scholar_no'] ?? 'N/A';
                              final points = (item['total_contributed'] as num?)?.toInt() ?? 0;
                              final cls = item['class_level'] ?? 'Senior';

                              return InkWell(
                                onTap: () => _showStudentContributionModal(item, houseColor),
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF151D2E) : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: rank == 1
                                          ? Colors.amber.withValues(alpha: 0.5)
                                          : Colors.grey.withValues(alpha: 0.2),
                                      width: rank == 1 ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Rank Badge
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: rank == 1
                                              ? Colors.amber.withValues(alpha: 0.2)
                                              : (rank == 2
                                                  ? const Color(0xFFC0C0C0).withValues(alpha: 0.2)
                                                  : (rank == 3
                                                      ? const Color(0xFFCD7F32).withValues(alpha: 0.2)
                                                      : Colors.grey.withValues(alpha: 0.1))),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            rank == 1 ? '🥇' : (rank == 2 ? '🥈' : (rank == 3 ? '🥉' : '#$rank')),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: rank <= 3 ? 16 : 13,
                                              color: rank <= 3 ? null : Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Avatar
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: houseColor.withValues(alpha: 0.15),
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                          style: TextStyle(
                                            color: houseColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                            ),
                                            Text(
                                              'Scholar #$scholar • $cls',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Points Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: houseColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '+$points Pts',
                                          style: TextStyle(
                                            color: houseColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> topThree, Color houseColor, bool isDark) {
    // topThree[0] = 1st, topThree[1] = 2nd, topThree[2] = 3rd
    final first = topThree[0];
    final second = topThree[1];
    final third = topThree[2];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd Place
        Expanded(
          child: _buildPodiumColumn(
            item: second,
            rank: 2,
            medal: '🥈',
            color: const Color(0xFF94A3B8),
            height: 120,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),

        // 1st Place (Tallest)
        Expanded(
          child: _buildPodiumColumn(
            item: first,
            rank: 1,
            medal: '🥇',
            color: Colors.amber,
            height: 155,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),

        // 3rd Place
        Expanded(
          child: _buildPodiumColumn(
            item: third,
            rank: 3,
            medal: '🥉',
            color: const Color(0xFFCD7F32),
            height: 105,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required Map<String, dynamic> item,
    required int rank,
    required String medal,
    required Color color,
    required double height,
    required bool isDark,
  }) {
    final name = item['student_name'] ?? 'Student';
    final points = item['total_contributed'] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '+$points Pts',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
