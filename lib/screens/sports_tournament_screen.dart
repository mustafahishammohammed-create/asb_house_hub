// lib/screens/sports_tournament_screen.dart
import 'package:flutter/material.dart';
import '../models/sports_tournament.dart';
import '../models/player_sports_stats.dart';
import '../models/sports_trophy.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../services/pass_document_exporter.dart';
import '../theme/app_theme.dart';
import '../widgets/managed_modal_scope.dart';
import '../widgets/student_profile_modal.dart';
import 'live_match_hud_screen.dart';

class SportsTournamentScreen extends StatefulWidget {
  final String userHouse;
  const SportsTournamentScreen({
    super.key,
    required this.userHouse,
  });

  @override
  State<SportsTournamentScreen> createState() => _SportsTournamentScreenState();
}

class _SportsTournamentScreenState extends State<SportsTournamentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  SportType? _selectedSportFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _canAdministerSports {
    final profile = AuthService.getCachedProfile();
    final role = (profile?['role'] ?? '').toString();
    final scholar = (profile?['scholar_no'] ?? '').toString();
    final name = (profile?['full_name'] ?? '').toString();
    return HierarchyService.isCouncilOrTeacher(
      scholarNo: scholar,
      role: role,
      fullName: name,
    );
  }

  Color _getHouseColor(String house) {
    switch (house.toLowerCase()) {
      case 'sapphire':
        return HouseColors.sapphire;
      case 'emerald':
        return HouseColors.emerald;
      case 'topaz':
        return HouseColors.topaz;
      case 'ruby':
      default:
        return HouseColors.ruby;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cachedFixtures = AuthService.getCachedSportsFixtures();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Inter-House Sports League'),
        actions: [
          if (_canAdministerSports)
            PopupMenuButton<String>(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
              tooltip: 'Sports Admin & Match Actions',
              onSelected: (val) {
                if (val == 'fixture') {
                  _showCreateFixtureDialog();
                } else if (val == 'accolade') {
                  _showAwardAccoladeDialog();
                } else if (val == 'trophy') {
                  _showAwardTrophyDialog();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'fixture',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline_rounded, color: HouseColors.emerald, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Schedule Match Fixture',
                          style: TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'accolade',
                  child: Row(
                    children: [
                      Icon(Icons.military_tech_rounded, color: Colors.amber, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Award Accolade / MVP',
                          style: TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'trophy',
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Crown Champion & Trophy',
                          style: TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          dividerHeight: 0,
          indicatorWeight: 3,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: const [
            Tab(text: '🏆 Fixtures & Live', icon: Icon(Icons.sports_score_rounded, size: 20)),
            Tab(text: '📊 League Table', icon: Icon(Icons.leaderboard_rounded, size: 20)),
            Tab(text: '🏅 Accolades & MVPs', icon: Icon(Icons.military_tech_rounded, size: 20)),
            Tab(text: '🛡️ Trophy Cabinet', icon: Icon(Icons.shield_rounded, size: 20)),
          ],
        ),
      ),
      body: StreamBuilder<List<SportsMatchFixture>>(
        stream: _authService.getSportsFixturesStream(_selectedSportFilter),
        initialData: cachedFixtures,
        builder: (context, snapshot) {
          final allFixtures = snapshot.data ?? [];
          final displayedFixtures = _selectedSportFilter == null
              ? allFixtures
              : allFixtures.where((f) => f.sportType == _selectedSportFilter).toList();

          return Column(
            children: [
              _buildSportFilterBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFixturesTab(displayedFixtures),
                    _buildLeagueTableTab(allFixtures),
                    _buildAccoladesTab(_selectedSportFilter ?? SportType.football, allFixtures),
                    _buildTrophyCabinetTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSportFilterBar() {
    final filters = [
      (label: 'All Sports', sport: null, emoji: '🏅'),
      (label: 'Football', sport: SportType.football, emoji: '⚽'),
      (label: 'Basketball', sport: SportType.basketball, emoji: '🏀'),
      (label: 'Volleyball', sport: SportType.volleyball, emoji: '🏐'),
      (label: 'Track & Field', sport: SportType.trackAndField, emoji: '🏃'),
    ];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];
          final isSelected = _selectedSportFilter == item.sport;

          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: FilterChip(
              materialTapTargetSize: MaterialTapTargetSize.padded,
              avatar: Text(item.emoji, style: const TextStyle(fontSize: 14)),
              label: Text(
                item.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedSportFilter = item.sport);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFixturesTab(List<SportsMatchFixture> fixtures) {
    if (fixtures.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_volleyball_rounded, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No Match Fixtures Scheduled',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Official inter-house football, basketball, volleyball and track fixtures will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: fixtures.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final f = fixtures[index];
        final colA = _getHouseColor(f.houseA);
        final colB = _getHouseColor(f.houseB);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LiveMatchHudScreen(
                    fixture: f,
                    userHouse: widget.userHouse,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(f.sportType.emoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                f.sportType.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: f.isLive
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          f.status.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: f.isLive ? Colors.redAccent : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colA.withValues(alpha: 0.2),
                              child: Text(
                                f.houseA.isNotEmpty ? f.houseA[0].toUpperCase() : '?',
                                style: TextStyle(color: colA, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f.houseA.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          f.isCompleted || f.isLive ? f.formattedScore : 'VS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: f.isLive ? Colors.redAccent : null,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colB.withValues(alpha: 0.2),
                              child: Text(
                                f.houseB.isNotEmpty ? f.houseB[0].toUpperCase() : '?',
                                style: TextStyle(color: colB, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f.houseB.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '📍 ${f.venue}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${f.scheduledAt.day}/${f.scheduledAt.month} • ${f.scheduledAt.hour.toString().padLeft(2, '0')}:${f.scheduledAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeagueTableTab(List<SportsMatchFixture> fixtures) {
    final standings = HouseLeagueStanding.calculateStandings(fixtures);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Official House Standings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Win = 3 PTS • Draw = 1 PT • Loss = 0 PTS',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 16,
                headingRowHeight: 44,
                columns: const [
                  DataColumn(label: Text('House', style: TextStyle(fontWeight: FontWeight.w900))),
                  DataColumn(label: Text('P', style: TextStyle(fontWeight: FontWeight.w900)), numeric: true),
                  DataColumn(label: Text('W', style: TextStyle(fontWeight: FontWeight.w900)), numeric: true),
                  DataColumn(label: Text('D', style: TextStyle(fontWeight: FontWeight.w900)), numeric: true),
                  DataColumn(label: Text('L', style: TextStyle(fontWeight: FontWeight.w900)), numeric: true),
                  DataColumn(label: Text('GD', style: TextStyle(fontWeight: FontWeight.w900)), numeric: true),
                  DataColumn(label: Text('PTS', style: TextStyle(fontWeight: FontWeight.w900)), numeric: true),
                ],
                rows: standings.map((s) {
                  final col = _getHouseColor(s.houseName);
                  return DataRow(
                    onSelectChanged: (_) => _showHouseMatchLogsModal(context, s, fixtures),
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(s.houseName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(Text('${s.matchesPlayed}')),
                      DataCell(Text('${s.won}')),
                      DataCell(Text('${s.drawn}')),
                      DataCell(Text('${s.lost}')),
                      DataCell(Text('${s.goalDifference}')),
                      DataCell(Text('${s.points}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.amber))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccoladesTab(SportType sport, List<SportsMatchFixture> fixtures) {
    final accolade = SportAccoladeType.forSport(sport);
    final cachedPlayers = AuthService.getCachedPlayerSportsStats(sport);
    final mvpFixtures = fixtures.where((f) => f.sportType == sport && f.mvpName != null).toList();

    return StreamBuilder<List<PlayerSportsStats>>(
      stream: _authService.getPlayerSportsStatsStream(sport),
      initialData: cachedPlayers,
      builder: (context, snapshot) {
        final allPlayers = snapshot.data ?? [];
        final topPerformers = PlayerSportsStats.sortTopPerformers(allPlayers, sport);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Accolade Category Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4), width: 1.2),
                ),
                child: Row(
                  children: [
                    Text(accolade.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accolade.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${sport.displayName} Individual Performance Race',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. Individual Scoring Race Leaderboard
              Text(
                'Top ${sport.displayName} Performers',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),

              if (topPerformers.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.military_tech_rounded, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          const Text(
                            'No Player Statistics Recorded Yet',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Individual scoring and MVP awards will populate as matches conclude.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topPerformers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = topPerformers[index];
                    final houseColor = _getHouseColor(p.houseName);
                    final isRank1 = index == 0;

                    return InkWell(
                      onTap: () => StudentProfileModal.show(
                        context,
                        scholarNo: p.scholarNo,
                        studentName: p.studentName,
                        houseName: p.houseName,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        elevation: isRank1 ? 3 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isRank1
                              ? const BorderSide(color: Colors.amber, width: 1.5)
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // Rank Badge
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isRank1
                                      ? Colors.amber
                                      : (index == 1
                                          ? const Color(0xFFC0C0C0)
                                          : (index == 2
                                              ? const Color(0xFFCD7F32)
                                              : Colors.grey.withValues(alpha: 0.2))),
                                ),
                                child: Center(
                                  child: Text(
                                    '#${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: isRank1 || index < 3 ? Colors.black : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // House Crest & Player Info
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: houseColor.withValues(alpha: 0.2),
                                child: Text(
                                  p.houseName.isNotEmpty ? p.houseName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: houseColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.studentName,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p.houseName.toUpperCase()} • #${p.scholarNo}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),

                              // Primary Stat + MVP Count
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${p.primaryStat} ${p.statLabel}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  if (p.mvpAwardsCount > 0)
                                    Text(
                                      '${p.mvpAwardsCount} ⭐ MVP',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10.5,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // 3. Match Day MVPs Section
              Text(
                'Certified Match Day MVPs ⭐',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),

              if (mvpFixtures.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No Match MVPs awarded yet for ${sport.displayName}.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mvpFixtures.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final f = mvpFixtures[index];
                    final houseColor = _getHouseColor(f.houseA);

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        onTap: () {
                          if (f.mvpName != null && f.mvpName!.isNotEmpty) {
                            StudentProfileModal.show(
                              context,
                              scholarNo: (f.mvpScholarNo ?? '').trim(),
                              studentName: f.mvpName!,
                              houseName: f.scoreB > f.scoreA ? f.houseB : f.houseA,
                            );
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: houseColor.withValues(alpha: 0.2),
                          child: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        ),
                        title: Text(
                          f.mvpName ?? 'MVP Scholar',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${f.tournamentTitle} (${f.formattedScore}) • ${f.houseA.toUpperCase()} vs ${f.houseB.toUpperCase()}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            'MVP 🏅',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrophyCabinetTab() {
    final cachedTrophies = AuthService.getCachedSportsTrophies();

    return StreamBuilder<List<SportsTrophyRecord>>(
      stream: _authService.getSportsTrophiesStream(),
      initialData: cachedTrophies,
      builder: (context, snapshot) {
        final trophies = snapshot.data ?? [];

        if (trophies.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 72, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Trophy Cabinet Is Empty',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Championship cups and house point bonuses (+100 PTS) will be commemorated here upon tournament completion.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: trophies.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final t = trophies[index];
            final winnerCol = _getHouseColor(t.winningHouse);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showTrophyDetailsModal(context, t),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        winnerCol.withValues(alpha: 0.25),
                        const Color(0xFF0F172A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.amber, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: winnerCol.withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(t.trophyTier.emoji, style: const TextStyle(fontSize: 28)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.trophyTier.title,
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          t.sportType.displayName,
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.greenAccent),
                              ),
                              child: Text(
                                '+${t.pointsAwarded} PTS',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white12, height: 24),
                        Text(
                          t.tournamentTitle.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '🏆 Champions: ${t.winningHouse.toUpperCase()} HOUSE (+${t.pointsAwarded} PTS)\n🥈 Runners-Up: ${t.runnerUpHouse.toUpperCase()} HOUSE (+${t.runnerUpPoints} PTS)',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                        if (t.mvpName != null && t.mvpName!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '⭐ Tournament MVP: ${t.mvpName}',
                            style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Awarded: ${t.awardedAt.day}/${t.awardedAt.month}/${t.awardedAt.year}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Certified: ${t.commissionerName}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateFixtureDialog() {
    final parentMessenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController(text: 'Inter-House Championship 2026');
    final venueController = TextEditingController(text: 'Main Sports Arena');
    SportType selectedSport = _selectedSportFilter ?? SportType.football;
    String houseA = 'ruby';
    String houseB = 'sapphire';
    DateTime matchDate = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ManagedModalScope(
          controllers: [titleController, venueController],
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏆 Schedule Match Fixture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create an official tournament fixture on the live sports scoreboard.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Tournament / Event Title',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SportType>(
                      initialValue: selectedSport,
                      decoration: InputDecoration(
                        labelText: 'Sport Type',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: SportType.values.map((s) {
                        return DropdownMenuItem(value: s, child: Text('${s.emoji} ${s.displayName}'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedSport = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: houseA,
                            decoration: InputDecoration(
                              labelText: 'House A (Home)',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: ['ruby', 'sapphire', 'emerald', 'topaz'].map((h) {
                              return DropdownMenuItem(value: h, child: Text(h.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => houseA = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: houseB,
                            decoration: InputDecoration(
                              labelText: 'House B (Away)',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: ['ruby', 'sapphire', 'emerald', 'topaz'].map((h) {
                              return DropdownMenuItem(value: h, child: Text(h.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => houseB = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: venueController,
                      decoration: InputDecoration(
                        labelText: 'Venue / Ground',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (houseA == houseB) {
                            parentMessenger.showSnackBar(
                              const SnackBar(content: Text('House A and House B cannot be the same!')),
                            );
                            return;
                          }
                          Navigator.of(ctx).pop();
                          await _authService.createSportsFixture(
                            tournamentTitle: titleController.text,
                            sportType: selectedSport,
                            houseA: houseA,
                            houseB: houseB,
                            venue: venueController.text,
                            scheduledAt: matchDate,
                          );
                          if (!mounted) return;
                          setState(() {});
                          parentMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Scheduled ${selectedSport.displayName}: ${houseA.toUpperCase()} vs ${houseB.toUpperCase()}!'),
                              backgroundColor: Colors.green[700],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Publish Match Fixture', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  void _showAwardAccoladeDialog() {
    final parentMessenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scholarController = TextEditingController(text: '2310910');
    final nameController = TextEditingController(text: 'Mohammed Ayaan');
    final statCountController = TextEditingController(text: '3');
    SportType selectedSport = _selectedSportFilter ?? SportType.football;
    SportAccoladeType selectedAccolade = SportAccoladeType.matchMvp;
    String selectedHouse = 'ruby';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ManagedModalScope(
          controllers: [scholarController, nameController, statCountController],
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏅 Award Player Accolade & MVP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bestow official player honours, Golden Boot, Scoring Champ, and credit merit points.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: scholarController,
                      decoration: InputDecoration(
                        labelText: 'Student Scholar Number',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Student Full Name',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedHouse,
                            decoration: InputDecoration(
                              labelText: 'House',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: ['ruby', 'sapphire', 'emerald', 'topaz'].map((h) {
                              return DropdownMenuItem(value: h, child: Text(h.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedHouse = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<SportType>(
                            initialValue: selectedSport,
                            decoration: InputDecoration(
                              labelText: 'Sport',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: SportType.values.map((s) {
                              return DropdownMenuItem(value: s, child: Text(s.displayName));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedSport = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SportAccoladeType>(
                      initialValue: selectedAccolade,
                      decoration: InputDecoration(
                        labelText: 'Accolade Title',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: SportAccoladeType.values.map((a) {
                        return DropdownMenuItem(value: a, child: Text('${a.emoji} ${a.title}'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedAccolade = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: statCountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Stat Metric Count (Goals / Points / Aces)',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final count = int.tryParse(statCountController.text) ?? 1;
                          final scholarNoValue = scholarController.text;
                          final studentNameValue = nameController.text;
                          Navigator.of(ctx).pop();
                          final success = await _authService.awardPlayerAccoladeCustom(
                            scholarNo: scholarNoValue,
                            studentName: studentNameValue,
                            houseName: selectedHouse,
                            sportType: selectedSport,
                            accoladeType: selectedAccolade,
                            goals: selectedSport == SportType.football ? count : 0,
                            baskets: selectedSport == SportType.basketball ? count : 0,
                            aces: selectedSport == SportType.volleyball ? count : 0,
                            trackPoints: selectedSport == SportType.trackAndField ? count : 0,
                            meritPoints: 25,
                          );
                          if (!mounted) return;
                          setState(() {});
                          if (success) {
                            parentMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Awarded ${selectedAccolade.title} to $studentNameValue (+25 PTS)!'),
                                backgroundColor: Colors.amber[800],
                              ),
                            );
                          } else {
                            parentMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Failed to award accolade. Insufficient permissions or server error.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Bestow Accolade & Credit Points', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  void _showAwardTrophyDialog() {
    final parentMessenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController(text: 'Inter-House Monsoon Cup 2026');
    final mvpController = TextEditingController(text: 'Mohammed Ayaan');
    SportType selectedSport = _selectedSportFilter ?? SportType.football;
    String winningHouse = 'ruby';
    String runnerUpHouse = 'sapphire';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ManagedModalScope(
          controllers: [titleController, mvpController],
          child: StatefulBuilder(
            builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🛡️ Crown Champion & Award Trophy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bestow Gold Cup (+100 PTS) and Silver Shield (+50 PTS) into House Trophy Cabinet.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Championship Tournament Title',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SportType>(
                      initialValue: selectedSport,
                      decoration: InputDecoration(
                        labelText: 'Sport Type',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: SportType.values.map((s) {
                        return DropdownMenuItem(value: s, child: Text('${s.emoji} ${s.displayName}'));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedSport = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: winningHouse,
                            decoration: InputDecoration(
                              labelText: '🏆 Champions (+100 PTS)',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: ['ruby', 'sapphire', 'emerald', 'topaz'].map((h) {
                              return DropdownMenuItem(value: h, child: Text(h.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => winningHouse = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: runnerUpHouse,
                            decoration: InputDecoration(
                              labelText: '🥈 Runners-Up (+50 PTS)',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: ['ruby', 'sapphire', 'emerald', 'topaz'].map((h) {
                              return DropdownMenuItem(value: h, child: Text(h.toUpperCase()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => runnerUpHouse = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mvpController,
                      decoration: InputDecoration(
                        labelText: 'Tournament MVP Name (Optional)',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (winningHouse == runnerUpHouse) {
                            parentMessenger.showSnackBar(
                              const SnackBar(content: Text('Champions and Runners-Up cannot be the same house!')),
                            );
                            return;
                          }
                          final tournamentTitleValue = titleController.text;
                          final mvpNameValue = mvpController.text;
                          Navigator.of(ctx).pop();
                          final profile = AuthService.getCachedProfile();
                          final adminName = (profile?['full_name'] ?? 'Sports Master').toString();
                          final adminScholar = (profile?['scholar_no'] ?? '2310910').toString();
                          final adminRole = (profile?['role'] ?? 'captain').toString();

                          final res = await _authService.awardChampionshipTrophyAndPoints(
                            tournamentTitle: tournamentTitleValue,
                            sportType: selectedSport,
                            winningHouse: winningHouse,
                            runnerUpHouse: runnerUpHouse,
                            pointsAwarded: 100,
                            runnerUpPoints: 50,
                            mvpName: mvpNameValue,
                            commissionerName: adminName,
                            adminScholarNo: adminScholar,
                            adminRole: adminRole,
                          );
                          if (!mounted) return;
                          if (res.success) {
                            setState(() {});
                            parentMessenger.showSnackBar(
                              SnackBar(
                                content: Text('🏆 ${winningHouse.toUpperCase()} crowned $tournamentTitleValue Champions (+100 PTS)!'),
                                backgroundColor: Colors.amber[800],
                              ),
                            );
                          } else {
                            parentMessenger.showSnackBar(
                              SnackBar(
                                content: Text(res.error ?? 'Failed to crown champions. Database transaction failed.'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Crown & Issue Trophy Proclamation', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  void _showHouseMatchLogsModal(
    BuildContext context,
    HouseLeagueStanding standing,
    List<SportsMatchFixture> allFixtures,
  ) {
    final houseName = standing.houseName.toLowerCase();
    final col = _getHouseColor(houseName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final houseMatches = allFixtures.where((f) {
      return f.houseA.toLowerCase() == houseName || f.houseB.toLowerCase() == houseName;
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: col.withValues(alpha: 0.2),
                    child: Text(
                      houseName.isNotEmpty ? houseName[0].toUpperCase() : '?',
                      style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${standing.houseName.toUpperCase()} HOUSE',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: col),
                        ),
                        Text(
                          '${standing.matchesPlayed} Matches • ${standing.won}W ${standing.drawn}D ${standing.lost}L • ${standing.points} PTS',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Tournament Match Logs',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              if (houseMatches.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No completed match fixtures on record for this house yet.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                ...houseMatches.map((f) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${f.houseA.toUpperCase()} vs ${f.houseB.toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        Text(
                          f.formattedScore,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrophyDetailsModal(BuildContext context, SportsTrophyRecord trophy) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final winnerCol = _getHouseColor(trophy.winningHouse);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(trophy.trophyTier.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trophy.tournamentTitle.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        Text(
                          '${trophy.sportType.displayName} • ${trophy.trophyTier.title}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: winnerCol.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🏆 Champions: ${trophy.winningHouse.toUpperCase()} HOUSE (+${trophy.pointsAwarded} PTS)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: winnerCol),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '🥈 Runners-Up: ${trophy.runnerUpHouse.toUpperCase()} HOUSE (+${trophy.runnerUpPoints} PTS)',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (trophy.mvpName != null && trophy.mvpName!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '⭐ Tournament MVP: ${trophy.mvpName}',
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Awarded: ${trophy.awardedAt.day}/${trophy.awardedAt.month}/${trophy.awardedAt.year}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    'Certified By: ${trophy.commissionerName}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Export Victory Certificate PDF', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final sm = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final res = await PassDocumentExporter.exportPass(
                      title: 'Official Sports Tournament Victory Certificate',
                      subtitle: '${trophy.tournamentTitle} (${trophy.sportType.displayName})',
                      details: 'Champions: ${trophy.winningHouse.toUpperCase()} HOUSE\n'
                          'Runners-Up: ${trophy.runnerUpHouse.toUpperCase()} HOUSE\n'
                          'Tournament MVP: ${trophy.mvpName ?? "N/A"}\n'
                          'Certified by: ${trophy.commissionerName}',
                      totalInfo: 'House Merit Reward: +${trophy.pointsAwarded} PTS Awarded',
                      qrData: 'ASB-TROPHY-${trophy.trophyId}-${trophy.winningHouse}',
                    );
                    sm.showSnackBar(
                      SnackBar(
                        content: Text(
                          res.success
                              ? '✓ Championship pass exported to: ${res.filePath}'
                              : 'Export failed: ${res.error}',
                        ),
                        backgroundColor: res.success ? Colors.green[700] : Colors.redAccent,
                      ),
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
}

