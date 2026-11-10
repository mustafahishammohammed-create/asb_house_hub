// lib/screens/election_gazette_screen.dart
import 'package:flutter/material.dart';
import '../models/election_gazette.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/student_profile_modal.dart';
import 'election_audit_screen.dart';
import 'home_screen.dart';

class ElectionGazetteScreen extends StatefulWidget {
  const ElectionGazetteScreen({super.key});

  @override
  State<ElectionGazetteScreen> createState() => _ElectionGazetteScreenState();
}

class _ElectionGazetteScreenState extends State<ElectionGazetteScreen> {
  final _authService = AuthService();
  late Stream<List<CertifiedElectionResult>> _gazetteStream;

  @override
  void initState() {
    super.initState();
    _gazetteStream = _authService.getCertifiedGazetteStream();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cached = AuthService.getCachedCertifiedGazette();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Election Gazette', style: TextStyle(fontWeight: FontWeight.w900)),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Proclamations',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {
              _gazetteStream = _authService.getCertifiedGazetteStream();
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<CertifiedElectionResult>>(
          stream: _gazetteStream,
          initialData: cached,
          builder: (context, snapshot) {
            final proclamations = snapshot.data ?? cached;

            if (proclamations.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Election Proclamations Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Certified election outcomes and statutory appointments will appear here after official commission certification.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: proclamations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                final item = proclamations[index];
                final houseColor = HouseColors.getHouseColor(item.winnerHouse);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showProclamationAuditModal(context, item, houseColor),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: houseColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: houseColor.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              HouseColors.getHouseEmoji(item.winnerHouse),
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.runningPosition.toUpperCase(),
                                style: TextStyle(
                                  color: houseColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+${item.housePointsAwarded} PTS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Candidate Details & Resilient Image
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: HomeScreen.buildResilientImage(
                                      item.winnerAvatarUrl,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.winnerName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Scholar #${item.winnerScholarNo} • ${item.winnerHouse.toUpperCase()} House',
                                        style: TextStyle(
                                          color: houseColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            'Votes: ${item.totalVotesReceived}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            'Margin: +${item.victoryMarginVotes}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                item.proclamationText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.grey.withValues(alpha: 0.2)),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Certified: ${item.certifiedAt.toLocal().toString().split(' ').first}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                Text(
                                  'By: ${item.commissionerName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  ),
);
}

  void _showProclamationAuditModal(
    BuildContext context,
    CertifiedElectionResult item,
    Color houseColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                Text(
                  HouseColors.getHouseEmoji(item.winnerHouse),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.runningPosition.toUpperCase(),
                        style: TextStyle(
                          color: houseColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Official Election Audit Certificate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: houseColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Winner:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${item.winnerName} (#${item.winnerScholarNo})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('House:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(item.winnerHouse.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: houseColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Certified Votes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${item.totalVotesReceived} Votes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Victory Margin:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('+${item.victoryMarginVotes} Votes', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Certified By:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(item.commissionerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.verified_user_rounded, size: 18),
                    label: const Text('Verify Ballot Audit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: houseColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ElectionAuditScreen(
                            ballotId: item.ballotId,
                            ballotTitle: item.ballotTitle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_rounded, size: 18),
                  label: const Text('Winner Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    StudentProfileModal.show(
                      context,
                      scholarNo: item.winnerScholarNo,
                      studentName: item.winnerName,
                      houseName: item.winnerHouse,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
