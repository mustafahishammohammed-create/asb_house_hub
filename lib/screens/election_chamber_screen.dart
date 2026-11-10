import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pass_document_exporter.dart';
import '../models/election_ballot.dart';
import '../models/digital_ballot_cast.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'election_gazette_screen.dart';
import 'school_elections_page.dart';

/// Screen for exploring Student Council & House Captain elections, candidates, manifestos, and voting.
class ElectionChamberScreen extends StatefulWidget {
  final String userHouse;
  final String scholarNo;
  final String studentName;
  final DateTime? mockNow;

  const ElectionChamberScreen({
    super.key,
    this.userHouse = '',
    this.scholarNo = '',
    this.studentName = '',
    this.mockNow,
  });

  @override
  State<ElectionChamberScreen> createState() => _ElectionChamberScreenState();
}

class _ElectionChamberScreenState extends State<ElectionChamberScreen> {
  final _authService = AuthService();
  BallotPosition _selectedPosition = BallotPosition.all;
  String _searchQuery = '';
  late final Stream<List<ElectionBallot>> _electionsStream;

  @override
  void initState() {
    super.initState();
    _electionsStream = _authService.getElectionsStream();
  }

  String get _effectiveScholarNo {
    final cached = AuthService.getCachedScholarNo()?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    return widget.scholarNo.trim();
  }

  bool get _canManageElections {
    final cached = AuthService.getCachedProfile() ?? {};
    final sNo = _effectiveScholarNo.toLowerCase();
    final role = cached['role']?.toString().toLowerCase();
    String? safeEmail;
    try {
      if (Firebase.apps.isNotEmpty) {
        safeEmail = FirebaseAuth.instance.currentUser?.email;
      }
    } catch (_) {}
    return HierarchyService.canManageElections(
      scholarNo: sNo,
      role: role,
      capabilities: cached['capabilities'] is Map ? Map<String, dynamic>.from(cached['capabilities']) : null,
      email: safeEmail,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final houseColor = HouseColors.getHouseColor(widget.userHouse);
    final cachedBallots = AuthService.getCachedBallots();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Election Chamber',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.newspaper_rounded),
            tooltip: 'Campus Election Gazette & Proclamations',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ElectionGazetteScreen(),
                ),
              );
            },
          ),
          if (_canManageElections)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Create Ballot & Candidates',
              onPressed: () => _showCreateBallotModal(context, houseColor),
            ),
          IconButton(
            icon: const Icon(Icons.how_to_vote_rounded),
            tooltip: 'Ballots & Roster Governance',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SchoolElectionsPage(),
                ),
              );
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: _canManageElections
          ? FloatingActionButton.extended(
              backgroundColor: houseColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Create Ballot', style: TextStyle(fontWeight: FontWeight.w900)),
              onPressed: () => _showCreateBallotModal(context, houseColor),
            )
          : null,
      body: StreamBuilder<List<ElectionBallot>>(
        initialData: cachedBallots,
        stream: _electionsStream,
        builder: (context, snapshot) {
          final ballots = snapshot.data ?? cachedBallots;
          final filteredBallots = ballots.where((b) {
            final matchesPos = _selectedPosition == BallotPosition.all ||
                b.position == _selectedPosition;
            final matchesSearch = _searchQuery.isEmpty ||
                b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                b.candidates.any((c) =>
                    c.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    c.scholarNo.toLowerCase().contains(_searchQuery.toLowerCase()));
            return matchesPos && matchesSearch;
          }).toList();

          final openBallots = ballots.where((b) => b.isOpen).toList();

          return FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: CustomScrollView(
              slivers: [
                // Active Polling Telemetry HUD
                if (openBallots.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _buildPollingStatusHUD(openBallots, houseColor, isDark),
                    ),
                  ),

                // Institutional Elections v2 Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            houseColor.withValues(alpha: 0.15),
                            Colors.deepPurple.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: houseColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: houseColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.how_to_vote_rounded, color: houseColor, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Zero-Trust Official Ballots (v2)',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cast secret ballots, verify cryptographic receipts, and view certified results.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SchoolElectionsPage(),
                                ),
                              );
                            },
                            child: const Text('Open v2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Position Selector Pills
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _buildPositionFilterBar(ballots, houseColor, isDark),
                  ),
                ),

                // Search Box
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search candidates, scholar #, or positions...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),

                // Ballots List
                if (filteredBallots.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(isDark, houseColor),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ballot = filteredBallots[index];
                          return _buildBallotCard(ballot, houseColor, isDark);
                        },
                        childCount: filteredBallots.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPollingStatusHUD(
    List<ElectionBallot> openBallots,
    Color houseColor,
    bool isDark,
  ) {
    final first = openBallots.first;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Active Election: ${first.title}, ${first.formattedRemaining}',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.how_to_vote_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'POLLS OPEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  first.formattedRemaining,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              first.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${first.candidates.length} Certified Candidates • Eligible: ${first.eligibleGrades.join(", ")}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionFilterBar(
    List<ElectionBallot> ballots,
    Color houseColor,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: BallotPosition.values.map((pos) {
          final isSelected = _selectedPosition == pos;
          final count = pos == BallotPosition.all
              ? ballots.length
              : ballots.where((b) => b.position == pos).length;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: 'Filter by ${pos.displayName} elections, $count ballots available',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: InkWell(
                  onTap: () => setState(() => _selectedPosition = pos),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? houseColor
                          : isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? houseColor
                            : isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Text(
                      pos.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : isDark
                                ? Colors.white70
                                : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBallotCard(
    ElectionBallot ballot,
    Color houseColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ballot Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: houseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ballot.position.displayName.toUpperCase(),
                        style: TextStyle(
                          color: houseColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ballot.status == BallotStatus.certified
                            ? Colors.amber.withValues(alpha: 0.15)
                            : (ballot.isOpen
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ballot.status.displayName.toUpperCase(),
                        style: TextStyle(
                          color: ballot.status == BallotStatus.certified
                              ? Colors.amber.shade800
                              : (ballot.isOpen ? Colors.green : Colors.grey),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_canManageElections && ballot.status != BallotStatus.certified && ballot.candidates.isNotEmpty)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.amber.shade900,
                          backgroundColor: Colors.amber.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.workspace_premium_rounded, size: 14),
                        label: const Text(
                          'Certify & End',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                        onPressed: () => _certifyBallotWinner(ballot, houseColor),
                      )
                    else
                      Text(
                        ballot.formattedRemaining,
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ballot.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Eligible Voters: ${ballot.eligibleGrades.join(", ")} • Total Votes: ${ballot.totalVotesCast}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Candidates List
          if (ballot.candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No candidates registered for this ballot yet.',
                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ballot.candidates.length,
              separatorBuilder: (context, i) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, i) {
                final candidate = ballot.candidates[i];
                return _buildCandidateRow(ballot, candidate, houseColor, isDark);
              },
            ),
          if (_canManageElections && ballot.status != BallotStatus.certified && ballot.candidates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                label: Text(
                  ballot.isOpen ? 'Certify Election & Conclude Voting' : 'Certify Election Proclamation',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: () => _certifyBallotWinner(ballot, houseColor),
              ),
            )
          else if (ballot.status == BallotStatus.certified)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Election Certified & Concluded. Official results recorded in Campus Gazette.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
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

  Widget _buildCandidateRow(
    ElectionBallot ballot,
    ElectionCandidate candidate,
    Color houseColor,
    bool isDark,
  ) {
    final candHouseColor = HouseColors.getHouseColor(candidate.houseName);
    final receipt = AuthService.getReceiptForBallot(ballot.id, scholarNo: _effectiveScholarNo);
    final isMyVote = receipt != null &&
        (receipt.candidateScholarNo.trim().toLowerCase() == candidate.scholarNo.trim().toLowerCase() ||
            (receipt.candidateScholarNo.isEmpty &&
                receipt.candidateName.trim().toLowerCase() == candidate.fullName.trim().toLowerCase()));
    final hasVotedAny = receipt != null || AuthService.hasVotedInBallotCached(ballot.id, scholarNo: _effectiveScholarNo);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Candidate Portrait
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 54,
              height: 54,
              child: candidate.avatarUrl.isNotEmpty
                  ? HomeScreen.buildResilientImage(candidate.avatarUrl, height: 54)
                  : Container(
                      color: candHouseColor.withValues(alpha: 0.15),
                      child: Center(
                        child: Text(
                          candidate.fullName.isNotEmpty
                              ? candidate.fullName[0].toUpperCase()
                              : 'C',
                          style: TextStyle(
                            color: candHouseColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        candidate.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (candidate.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: candHouseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        candidate.houseName.toUpperCase(),
                        style: TextStyle(
                          color: candHouseColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '#${candidate.scholarNo} • ${candidate.classLevel}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Read Manifesto Button
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text(
                'Manifesto',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              onPressed: () => _showManifestoDialog(candidate, isDark),
            ),
          ),

          // Vote Button or Candidate-Specific Voted Indicator
          if (ballot.isOpen) ...[
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: isMyVote
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Your Vote',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : hasVotedAny
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Not selected',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: houseColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.how_to_vote_rounded, size: 16),
                          label: const Text(
                            'Vote',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          onPressed: () => _showVoteConfirmationModal(
                            ballot: ballot,
                            candidate: candidate,
                            scholarNo: _effectiveScholarNo,
                            houseColor: houseColor,
                          ),
                        ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${candidate.votesCount} votes',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showVoteConfirmationModal({
    required ElectionBallot ballot,
    required ElectionCandidate candidate,
    required String scholarNo,
    required Color houseColor,
  }) {
    bool isVoting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: houseColor.withValues(alpha: 0.15),
                    child: Icon(Icons.how_to_vote_rounded, color: houseColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confirm Official Vote',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          ballot.title,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: houseColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: houseColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Candidate: ${candidate.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${candidate.runningPosition} • ${candidate.houseName.toUpperCase()} House',
                      style: TextStyle(color: houseColor, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '🔒 Secret Ballot Guarantee: Your participation is registered under an anonymized cryptographic token. Your candidate choice is counted confidentially and cannot be altered once submitted.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: houseColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isVoting ? null : () async {
                  setModalState(() => isVoting = true);
                  final res = await AuthService().castDigitalVote(
                    ballotId: ballot.id,
                    ballotTitle: ballot.title,
                    candidate: candidate,
                    scholarNo: _effectiveScholarNo,
                  );

                  if (modalCtx.mounted) {
                    Navigator.pop(modalCtx);
                  }

                  if (mounted) {
                    if (res.success && res.receipt != null) {
                      setState(() {});
                      _showReceiptModal(context, res.receipt!, houseColor);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.error ?? 'Voting transaction failed'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
                child: isVoting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Confirm & Cast My Ballot', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: isVoting ? null : () => Navigator.pop(modalCtx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptModal(BuildContext context, BallotCastReceipt receipt, Color houseColor) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.verified_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Official Ballot Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: SelectableText(
                receipt.formattedReceiptNumber,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16),
              ),
            ),
            const SizedBox(height: 14),
            Text('Ballot: ${receipt.ballotTitle}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('Candidate: ${receipt.candidateName} (${receipt.candidateHouse.toUpperCase()})'),
            Text('Position: ${receipt.runningPosition}'),
            const SizedBox(height: 10),
            Text(
              'Voted at: ${receipt.timestamp.toLocal().toString().split('.').first}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Token'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: receipt.formattedReceiptNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Receipt token copied to clipboard!')),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export PDF'),
            onPressed: () async {
              final result = await PassDocumentExporter.exportPass(
                title: 'Official Election Ballot Receipt',
                subtitle: receipt.ballotTitle,
                details: 'Candidate: ${receipt.candidateName} (${receipt.candidateHouse.toUpperCase()})\nPosition: ${receipt.runningPosition}',
                totalInfo: 'Receipt Code: ${receipt.formattedReceiptNumber}',
                qrData: receipt.formattedReceiptNumber,
              );
              if (dialogCtx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.success ? '✓ Receipt PDF exported: ${result.filePath}' : 'Export error: ${result.error}'),
                    backgroundColor: result.success ? Colors.green : Colors.redAccent,
                  ),
                );
              }
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: houseColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 44),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showManifestoDialog(ElectionCandidate candidate, bool isDark) {
    final candHouseColor = HouseColors.getHouseColor(candidate.houseName);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: candHouseColor.withValues(alpha: 0.2),
              child: Text(
                HouseColors.getHouseEmoji(candidate.houseName),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  Text(
                    '${candidate.runningPosition} • ${candidate.houseName.toUpperCase()} House',
                    style: TextStyle(color: candHouseColor, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Campaign Manifesto & Pledges:',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  candidate.manifesto.isNotEmpty
                      ? candidate.manifesto
                      : 'No manifesto text submitted yet for this candidate.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Dismiss',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color houseColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote_outlined,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No active election ballots found.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _canManageElections
                  ? 'Student Council and House Captain polls can be staged and published here.'
                  : 'Student Council and House Captain polls will be registered here by school administration.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            if (_canManageElections) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: houseColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                ),
                icon: const Icon(Icons.add_task_rounded, size: 20),
                label: const Text(
                  'Create Ballot & Add Candidates',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                onPressed: () => _showCreateBallotModal(context, houseColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateBallotModal(BuildContext context, Color houseColor) async {
    if (!_canManageElections) return;
    final titleController = TextEditingController(text: 'Student Council Election 2026');
    final scholarController = TextEditingController();
    final nameController = TextEditingController();
    final manifestoController = TextEditingController();

    try {
      BallotPosition selectedPosition = BallotPosition.headBoy;
    String selectedHouse = 'ruby';
    String selectedScope = 'all';
    final candidatesDraft = <ElectionCandidate>[];
    bool isAutoFilled = false;
    bool isRosterMatch = false;
    String? rosterMatchInfo;
    bool isLookingUp = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isDark = Theme.of(modalCtx).brightness == Brightness.dark;
          final candColor = HouseColors.getHouseColor(selectedHouse);

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalCtx).size.height * 0.9,
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: houseColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.how_to_vote_rounded, color: houseColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Election Ballot',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'Add candidates by scholar number & publish to school',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Ballot Title
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Ballot Title',
                      hintText: 'e.g. 2026 Student Council Election',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Position & House Scope
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<BallotPosition>(
                          initialValue: selectedPosition,
                          decoration: InputDecoration(
                            labelText: 'Position',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: BallotPosition.values
                              .where((p) => p != BallotPosition.all)
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.displayName, style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedPosition = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedScope,
                          decoration: InputDecoration(
                            labelText: 'House Scope',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Houses', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'ruby', child: Text('Ruby Only', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'emerald', child: Text('Emerald Only', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'sapphire', child: Text('Sapphire Only', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: 'topaz', child: Text('Topaz Only', style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedScope = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  // Candidates Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Candidates (${candidatesDraft.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      if (candidatesDraft.isNotEmpty)
                        Text(
                          '${candidatesDraft.length} added',
                          style: TextStyle(color: houseColor, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Display Candidates in Draft
                  if (candidatesDraft.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: const Center(
                        child: Text(
                          'No candidates added to this ballot yet. Fill in below to add.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...candidatesDraft.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final cand = entry.value;
                      final hColor = HouseColors.getHouseColor(cand.houseName);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: hColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: hColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: hColor.withValues(alpha: 0.2),
                              child: Text(
                                HouseColors.getHouseEmoji(cand.houseName),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cand.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                  Text(
                                    '#${cand.scholarNo} • ${cand.houseName.toUpperCase()} House',
                                    style: TextStyle(fontSize: 11, color: hColor, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setModalState(() => candidatesDraft.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  // Add Candidate Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '+ Add Candidate by Scholar Number',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: scholarController,
                                decoration: InputDecoration(
                                  labelText: 'Scholar #',
                                  hintText: 'e.g. 11209',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  suffixIcon: IconButton(
                                    tooltip: 'Auto-fill details from roster',
                                    icon: isLookingUp
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                                    onPressed: () async {
                                      final clean = scholarController.text.trim();
                                      if (clean.isEmpty) return;
                                      setModalState(() => isLookingUp = true);
                                      final details = await AuthService.lookupScholarDetails(
                                        clean,
                                        runningPosition: selectedPosition.displayName,
                                      );
                                      if (!modalCtx.mounted) return;
                                      final isFound = details['isFound'] == true;
                                      final fullName = details['fullName'] as String? ?? '';
                                      final house = details['houseName'] as String? ?? '';
                                      final manifesto = details['manifesto'] as String? ?? '';
                                      final grade = details['classLevel'] as String? ?? '';

                                      if (isFound && fullName.isNotEmpty) {
                                        nameController.text = fullName;
                                        manifestoController.text = manifesto;
                                        isAutoFilled = true;
                                        setModalState(() {
                                          selectedHouse = house;
                                          isRosterMatch = true;
                                          rosterMatchInfo = '$fullName ($grade • ${house.toUpperCase()})';
                                          isLookingUp = false;
                                        });
                                      } else {
                                        if (isAutoFilled) {
                                          nameController.clear();
                                          manifestoController.clear();
                                          isAutoFilled = false;
                                        }
                                        setModalState(() {
                                          isRosterMatch = false;
                                          rosterMatchInfo = null;
                                          isLookingUp = false;
                                          final inferred = AuthService.inferHouseFromScholarNo(clean);
                                          if (inferred != null) selectedHouse = inferred;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                onChanged: (val) async {
                                  final clean = val.trim();
                                  if (clean.isEmpty) {
                                    if (isAutoFilled) {
                                      nameController.clear();
                                      manifestoController.clear();
                                      isAutoFilled = false;
                                    }
                                    setModalState(() {
                                      isRosterMatch = false;
                                      rosterMatchInfo = null;
                                      isLookingUp = false;
                                    });
                                    return;
                                  }

                                  if (clean.length < 3) {
                                    if (isAutoFilled) {
                                      nameController.clear();
                                      manifestoController.clear();
                                      isAutoFilled = false;
                                    }
                                    setModalState(() {
                                      isRosterMatch = false;
                                      rosterMatchInfo = null;
                                      isLookingUp = false;
                                      final inferred = AuthService.inferHouseFromScholarNo(clean);
                                      if (inferred != null) selectedHouse = inferred;
                                    });
                                    return;
                                  }

                                  setModalState(() => isLookingUp = true);
                                  final details = await AuthService.lookupScholarDetails(
                                    clean,
                                    runningPosition: selectedPosition.displayName,
                                  );
                                  if (!modalCtx.mounted) return;

                                  final isFound = details['isFound'] == true;
                                  final fullName = details['fullName'] as String? ?? '';
                                  final house = details['houseName'] as String? ?? '';
                                  final manifesto = details['manifesto'] as String? ?? '';
                                  final grade = details['classLevel'] as String? ?? '';

                                  if (isFound && fullName.isNotEmpty) {
                                    nameController.text = fullName;
                                    manifestoController.text = manifesto;
                                    isAutoFilled = true;
                                    setModalState(() {
                                      selectedHouse = house;
                                      isRosterMatch = true;
                                      rosterMatchInfo = '$fullName ($grade • ${house.toUpperCase()})';
                                      isLookingUp = false;
                                    });
                                  } else {
                                    nameController.clear();
                                    manifestoController.clear();
                                    isAutoFilled = false;
                                    setModalState(() {
                                      isRosterMatch = false;
                                      rosterMatchInfo = null;
                                      isLookingUp = false;
                                      final inferred = AuthService.inferHouseFromScholarNo(clean);
                                      if (inferred != null) selectedHouse = inferred;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: nameController,
                                onChanged: (_) => isAutoFilled = false,
                                decoration: InputDecoration(
                                  labelText: 'Candidate Name',
                                  hintText: 'Full Name',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isRosterMatch && rosterMatchInfo != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Verified Roster Match: $rosterMatchInfo',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (!isRosterMatch && scholarController.text.trim().length >= 3) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Scholar #${scholarController.text.trim()} not found in records — enter name and manifesto manually.',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedHouse,
                                decoration: InputDecoration(
                                  labelText: 'House',
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'ruby', child: Text('Ruby 🔴', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'emerald', child: Text('Emerald 🟢', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'sapphire', child: Text('Sapphire 🔵', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'topaz', child: Text('Topaz 🟡', style: TextStyle(fontSize: 13))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedHouse = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: manifestoController,
                          maxLines: 2,
                          onChanged: (_) => isAutoFilled = false,
                          decoration: InputDecoration(
                            labelText: 'Campaign Manifesto & Pledges',
                            hintText: 'Key initiatives, motto or pledges for the student body...',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: candColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: const Text('Add Candidate to List', style: TextStyle(fontWeight: FontWeight.w800)),
                          onPressed: () {
                            final sNo = scholarController.text.trim();
                            final name = nameController.text.trim();
                            if (sNo.isEmpty) {
                              ScaffoldMessenger.of(modalCtx).showSnackBar(
                                const SnackBar(content: Text('Please enter candidate scholar number.')),
                              );
                              return;
                            }
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(modalCtx).showSnackBar(
                                const SnackBar(content: Text('Please enter candidate full name.')),
                              );
                              return;
                            }
                            if (candidatesDraft.any((c) => c.scholarNo.trim().toLowerCase() == sNo.toLowerCase())) {
                              ScaffoldMessenger.of(modalCtx).showSnackBar(
                                SnackBar(content: Text('Scholar # is already added as a candidate on this ballot.')),
                              );
                              return;
                            }
                            final manifesto = manifestoController.text.trim();

                            setModalState(() {
                              candidatesDraft.add(ElectionCandidate(
                                scholarNo: sNo,
                                fullName: name,
                                houseName: selectedHouse,
                                runningPosition: selectedPosition.displayName,
                                manifesto: manifesto,
                                votesCount: 0,
                              ));
                              scholarController.clear();
                              nameController.clear();
                              manifestoController.clear();
                              isAutoFilled = false;
                              isRosterMatch = false;
                              rosterMatchInfo = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Publish Official Ballot Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: houseColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                    label: const Text(
                      'Publish Official Ballot',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(modalCtx).showSnackBar(
                          const SnackBar(content: Text('Please enter a ballot title.')),
                        );
                        return;
                      }
                      if (candidatesDraft.length < 2) {
                        ScaffoldMessenger.of(modalCtx).showSnackBar(
                          const SnackBar(content: Text('Please configure at least 2 eligible candidates before publishing.')),
                        );
                        return;
                      }

                      final newBallot = ElectionBallot(
                        id: 'ballot_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        position: selectedPosition,
                        houseScope: selectedScope,
                        eligibleGrades: const ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'],
                        status: BallotStatus.open,
                        startTime: DateTime.now().subtract(const Duration(seconds: 2)),
                        endTime: DateTime.now().add(const Duration(days: 7)),
                        candidates: candidatesDraft,
                        totalVotesCast: 0,
                      );

                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(modalCtx);
                      final res = await AuthService().createElectionBallot(newBallot);
                      if (mounted) {
                        if (res.success) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Official election ballot published! Voting is now open.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res.error ?? 'Failed to publish ballot.'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    } finally {
      titleController.dispose();
      scholarController.dispose();
      nameController.dispose();
      manifestoController.dispose();
    }
  }

  Future<void> _certifyBallotWinner(ElectionBallot ballot, Color houseColor) async {
    if (ballot.candidates.isEmpty) return;

    if (DateTime.now().isBefore(ballot.endTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voting is currently active. Elections can only be certified after the scheduled voting window closes.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final sortedCandidates = List<ElectionCandidate>.from(ballot.candidates)
      ..sort((a, b) => b.votesCount.compareTo(a.votesCount));

    // Zero-votes guard (C8)
    if (sortedCandidates.first.votesCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot certify election: 0 votes cast. Ballots must be received prior to official certification.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Tie guard (C8)
    if (sortedCandidates.length > 1 && sortedCandidates[0].votesCount == sortedCandidates[1].votesCount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot certify winner: Polling concluded in a tie (${sortedCandidates[0].votesCount} votes each between ${sortedCandidates[0].fullName} and ${sortedCandidates[1].fullName}). Runoff election required.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final rawWinner = sortedCandidates.first;
    String winnerHouse = rawWinner.houseName.trim().toLowerCase();
    if (winnerHouse.isEmpty || !['ruby', 'sapphire', 'emerald', 'topaz'].contains(winnerHouse)) {
      winnerHouse = AuthService.inferHouseFromScholarNo(rawWinner.scholarNo) ?? '';
    }
    if (winnerHouse.isEmpty || !['ruby', 'sapphire', 'emerald', 'topaz'].contains(winnerHouse)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot certify election: Winner house is unknown or not in school roster.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    final winner = ElectionCandidate(
      scholarNo: rawWinner.scholarNo,
      fullName: rawWinner.fullName,
      houseName: winnerHouse,
      runningPosition: rawWinner.runningPosition,
      manifesto: rawWinner.manifesto,
      avatarUrl: rawWinner.avatarUrl,
      votesCount: rawWinner.votesCount,
      isVerified: rawWinner.isVerified,
      classLevel: rawWinner.classLevel,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Certify Election Result?')),
          ],
        ),
        content: Text(
          'Are you sure you want to officially certify ${winner.fullName} (#${winner.scholarNo}) as the winning ${winner.runningPosition} with ${winner.votesCount} votes?\n\nThis will proclaim the results in the Campus Gazette and award +100 merit points to ${winner.houseName.toUpperCase()} House.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Certify & Award Points'),
          ),
        ],
      ),
    );

    if (!mounted || confirm != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final res = await _authService.certifyElectionAndAwardPoints(
        ballotId: ballot.id,
        ballotTitle: ballot.title,
        winner: winner,
        victoryMargin: (winner.votesCount - (sortedCandidates.length > 1 ? sortedCandidates[1].votesCount : 0)),
        commissionerName: _effectiveScholarNo.isNotEmpty ? 'Scholar #$_effectiveScholarNo' : 'Returning Officer',
        housePoints: 100,
      );

      if (mounted) {
        if (res.success) {
          final cached = AuthService.getCachedBallots();
          final updated = cached.map((b) {
            if (b.id == ballot.id) {
              return ElectionBallot(
                id: b.id,
                title: b.title,
                position: b.position,
                houseScope: b.houseScope,
                eligibleGrades: b.eligibleGrades,
                status: BallotStatus.certified,
                startTime: b.startTime,
                endTime: DateTime.now(),
                candidates: b.candidates,
                totalVotesCast: b.totalVotesCast,
              );
            }
            return b;
          }).toList();
          await AuthService.cacheBallots(updated);
          setState(() {});
          messenger.showSnackBar(
            SnackBar(
              content: Text('🏆 ${winner.fullName} officially certified! +100 House Points awarded.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Certification failed.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }
