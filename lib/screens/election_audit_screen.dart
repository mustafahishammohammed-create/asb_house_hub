// lib/screens/election_audit_screen.dart
import 'package:flutter/material.dart';
import '../models/election_audit_record.dart';
import '../models/digital_ballot_cast.dart';
import '../services/auth_service.dart';
import '../services/election_security_service.dart';
import '../theme/app_theme.dart';

class ElectionAuditScreen extends StatefulWidget {
  final String ballotId;
  final String ballotTitle;

  const ElectionAuditScreen({
    super.key,
    required this.ballotId,
    required this.ballotTitle,
  });

  @override
  State<ElectionAuditScreen> createState() => _ElectionAuditScreenState();
}

class _ElectionAuditScreenState extends State<ElectionAuditScreen> {
  final _receiptController = TextEditingController();
  final _authService = AuthService();
  late Stream<ElectionAuditRecord?> _auditStream;
  String? _verificationMessage;
  bool? _isReceiptVerified;
  BallotCastReceipt? _verifiedReceipt;

  @override
  void initState() {
    super.initState();
    _auditStream = _authService.getElectionAuditStream(widget.ballotId);
  }

  @override
  void didUpdateWidget(ElectionAuditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ballotId != widget.ballotId) {
      _auditStream = _authService.getElectionAuditStream(widget.ballotId);
    }
  }

  @override
  void dispose() {
    _receiptController.dispose();
    super.dispose();
  }

  void _handleVerifyReceipt(List<BallotCastReceipt> receipts) {
    final query = _receiptController.text.trim();
    if (query.isEmpty) return;

    final result = ElectionSecurityService.auditReceiptVerification(
      receiptNumber: query,
      auditedReceipts: receipts,
    );

    setState(() {
      _isReceiptVerified = result.verified;
      _verificationMessage = result.message;
      _verifiedReceipt = result.receipt;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cachedAudit = AuthService.getCachedElectionAudit(widget.ballotId);
    final userReceipts = AuthService.getCachedVoteReceipts();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ballotTitle),
        elevation: 0,
      ),
      body: StreamBuilder<ElectionAuditRecord?>(
        stream: _auditStream,
        initialData: cachedAudit,
        builder: (context, snapshot) {
          final audit = snapshot.data ??
              ElectionAuditRecord(
                ballotId: widget.ballotId,
                ballotTitle: widget.ballotTitle,
                totalEligibleVoters: 500,
                totalVotesCast: 0,
              );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Statutory Quorum HUD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: audit.hasMetQuorum
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: audit.turnoutPercentage / 100.0,
                              strokeWidth: 6,
                              backgroundColor: Colors.grey.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                audit.hasMetQuorum ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                          Text(
                            '${audit.turnoutPercentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  audit.hasMetQuorum
                                      ? Icons.check_circle_rounded
                                      : Icons.pending_rounded,
                                  color: audit.hasMetQuorum ? Colors.green : Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    audit.hasMetQuorum
                                        ? 'STATUTORY QUORUM MET'
                                        : 'BELOW STATUTORY QUORUM (≥50%)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: audit.hasMetQuorum ? Colors.green : Colors.orange,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${audit.totalVotesCast} of ${audit.totalEligibleVoters} eligible scholars voted',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const Text(
                              'Cryptographically audited under Ministry of Education quorum standards.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. House Turnout Telemetry
                const Text(
                  'House Turnout Telemetry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _buildHouseTurnoutBar('Ruby House', HouseColors.ruby, audit.houseTurnoutBreakdown['ruby'] ?? 0, audit.totalVotesCast),
                const SizedBox(height: 8),
                _buildHouseTurnoutBar('Sapphire House', HouseColors.sapphire, audit.houseTurnoutBreakdown['sapphire'] ?? 0, audit.totalVotesCast),
                const SizedBox(height: 8),
                _buildHouseTurnoutBar('Emerald House', HouseColors.emerald, audit.houseTurnoutBreakdown['emerald'] ?? 0, audit.totalVotesCast),
                const SizedBox(height: 8),
                _buildHouseTurnoutBar('Topaz House', HouseColors.topaz, audit.houseTurnoutBreakdown['topaz'] ?? 0, audit.totalVotesCast),
                const SizedBox(height: 28),

                // 3. Independent Cryptographic Receipt Verification Scanner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Colors.blue),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Verify Digital Ballot Receipt',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your ASB-VOTE-XXXXXXXX receipt code to verify your vote was mathematically included in the audited election ledger.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _receiptController,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleVerifyReceipt(userReceipts),
                        decoration: InputDecoration(
                          labelText: 'Receipt Number',
                          hintText: 'e.g. ASB-VOTE-E4F2A1B9',
                          prefixIcon: const Icon(Icons.receipt_long_rounded),
                          suffixIcon: IconButton(
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => _receiptController.clear(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.verified_user_rounded),
                        label: const Text('Verify Ballot Inclusion', style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: () => _handleVerifyReceipt(userReceipts),
                      ),
                      if (_verificationMessage != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_isReceiptVerified == true)
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (_isReceiptVerified == true) ? Colors.green : Colors.red,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  (_isReceiptVerified == true)
                                      ? Icons.check_circle_rounded
                                      : Icons.error_outline_rounded,
                                  color: (_isReceiptVerified == true) ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _verificationMessage!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: (_isReceiptVerified == true) ? Colors.green : Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (_verifiedReceipt != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Ballot Verified: ${_verifiedReceipt!.ballotTitle} (${_verifiedReceipt!.runningPosition})',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHouseTurnoutBar(String name, Color color, int votes, int totalVotes) {
    final pct = totalVotes > 0 ? (votes / totalVotes) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                name,
                style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$votes votes (${(pct * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
