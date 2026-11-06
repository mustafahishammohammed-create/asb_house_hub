// lib/screens/election_gazette_screen.dart
import 'package:flutter/material.dart';
import '../models/election_gazette.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class ElectionGazetteScreen extends StatefulWidget {
  const ElectionGazetteScreen({super.key});

  @override
  State<ElectionGazetteScreen> createState() => _ElectionGazetteScreenState();
}

class _ElectionGazetteScreenState extends State<ElectionGazetteScreen> {
  final _authService = AuthService();

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
            tooltip: 'Load Statutory Records',
            icon: const Icon(Icons.history_edu_rounded),
            onPressed: () async {
              await AuthService.cacheCertifiedGazette(AuthService.getFoundationalGazettes());
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: 'Refresh Proclamations',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<CertifiedElectionResult>>(
          stream: _authService.getCertifiedGazetteStream(),
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
                        'Certified election outcomes and statutory appointments will appear here after commission sign-off.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.history_edu_rounded, size: 18),
                        label: const Text('Load Statutory Records'),
                        onPressed: () async {
                          await AuthService.cacheCertifiedGazette(AuthService.getFoundationalGazettes());
                          if (mounted) setState(() {});
                        },
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

                return Container(
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
