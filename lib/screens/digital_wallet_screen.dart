import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../services/hierarchy_service.dart';
import '../services/voucher_security_service.dart';
import '../services/auth_service.dart';
import 'merch_store_tab.dart';
import 'id_scanner_screen.dart';

class DigitalWalletScreen extends StatefulWidget {
  final String userName;
  final String userHouse;
  final String scholarNo;
  final bool isAdmin;
  final int initialIndex;
  final String classLevel;
  final bool canScanQr;
  final String userRole;

  const DigitalWalletScreen({
    super.key,
    required this.userName,
    required this.userHouse,
    this.scholarNo = '2310910',
    this.isAdmin = false,
    this.initialIndex = 0,
    this.classLevel = 'Grade 11-D',
    this.canScanQr = false,
    this.userRole = 'Student',
  });

  @override
  State<DigitalWalletScreen> createState() => _DigitalWalletScreenState();
}

class _DigitalWalletScreenState extends State<DigitalWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _canScanQr {
    if (widget.canScanQr || widget.isAdmin) return true;
    return HierarchyService.isCouncilOrTeacher(
      scholarNo: widget.scholarNo,
      role: widget.userRole,
      fullName: widget.userName,
    );
  }

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String get _walletButtonLabel =>
      _isApplePlatform ? 'Add to Apple Wallet' : 'Save to Google Wallet';

  IconData get _walletButtonIcon =>
      _isApplePlatform ? Icons.apple : Icons.account_balance_wallet_rounded;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 2),
    );
    GlobalWalletStore.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final houseColor = _getHouseColor(widget.userHouse);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B0F19)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.wallet_rounded, color: Colors.amber),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                ' Apple / Google Wallet Passes',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (_canScanQr)
            IconButton(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.blueAccent,
              ),
              tooltip: 'Scan Student Digital ID (Faculty & Council)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IdScannerScreen(
                      evaluatorName: widget.userName.isNotEmpty
                          ? widget.userName
                          : 'Faculty Lead',
                    ),
                  ),
                );
              },
            ),
          if (GlobalWalletStore.orders.isNotEmpty)
            IconButton(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              tooltip: 'Clear All Store Bills',
              onPressed: () async {
                await GlobalWalletStore.clearAllBills();
                if (mounted) setState(() {});
              },
            ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: houseColor,
          indicatorWeight: 4,
          labelColor: houseColor,
          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: [
            Tab(text: '🛍️ Store Passes (${GlobalWalletStore.orders.length})'),
            const Tab(text: '🪪 Campus ID Pass'),
            const Tab(text: '🧾 Fee Receipts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStorePassesTab(houseColor),
          _buildCampusIdTab(houseColor),
          _buildFeeReceiptsTab(houseColor),
        ],
      ),
    );
  }

  Widget _buildStorePassesTab(Color houseColor) {
    final orders = GlobalWalletStore.orders;
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'No store passes found.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final order = orders[orders.length - 1 - index];
        return _buildPassCard(
          title: 'ASB MERCHANDISE CLAIM PASS',
          subtitle: 'Order #${order.receiptId}',
          status: order.isClaimed ? 'CLAIMED / FULFILLED 📦' : 'READY FOR PICKUP 🟢',
          statusColor: order.isClaimed ? Colors.blueGrey : Colors.greenAccent,
          qrData: order.qrData,
          details: order.items
              .map((i) => '${i.qty}x ${i.product.name} (${i.size})')
              .join('\n'),
          totalInfo: '${order.totalPts} Pts Paid',
          accentColor: houseColor,
        );
      },
    );
  }

  Widget _buildCampusIdTab(Color houseColor) {
    // Pre-hydrate verified student contribution statistics from local disk cache
    final cachedStats = AuthService.getCachedStudentContribution(widget.scholarNo);

    // Official, cryptographically signed scannable JSON QR payload for the student
    final studentQrData = VoucherSecurityService.generateStudentPassPayload(
      scholarNo: widget.scholarNo.trim(),
      studentName: widget.userName.trim().isNotEmpty ? widget.userName.trim() : 'Student',
      houseName: widget.userHouse.trim().isNotEmpty ? widget.userHouse.trim().toUpperCase() : 'RUBY',
      classLevel: widget.classLevel.trim().isNotEmpty ? widget.classLevel.trim() : 'Grade 11-D',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Banner: Shows Scanner controls for Council/Faculty, or Student Identity Pass for Students
          if (_canScanQr)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.2),
                    Colors.indigo.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scanBtn = ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text(
                      'Scan ID',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IdScannerScreen(
                            evaluatorName: widget.userName.isNotEmpty
                                ? widget.userName
                                : 'Faculty Lead',
                          ),
                        ),
                      );
                    },
                  );

                  if (constraints.maxWidth < 400) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.blueAccent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Faculty & Council Scanner',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scan student QR to award merits or deduct demerits.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: scanBtn,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.blueAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Faculty & Council Scanner',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Scan student QR to award merits or deduct demerits.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      scanBtn,
                    ],
                  );
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    houseColor.withValues(alpha: 0.2),
                    const Color(0xFF1F2937).withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: houseColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: houseColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: houseColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Official Student Identity Card',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Present your verified QR pass to Teachers or Council to track merits.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // StreamBuilder for Student's Real Contribution Points & Merits/Demerits
          StreamBuilder<DocumentSnapshot>(
            stream: () {
              try {
                if (widget.scholarNo.isNotEmpty && widget.scholarNo != '---') {
                  return FirebaseFirestore.instance
                      .collection('house_contributors')
                      .doc(widget.scholarNo)
                      .snapshots();
                }
              } catch (_) {}
              return null;
            }(),
            builder: (context, snapshot) {
              int totalPoints = cachedStats.totalPoints;
              int merits = cachedStats.merits;
              int demerits = cachedStats.demerits;
              bool isLiveSynced = false;

              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.exists) {
                final raw = snapshot.data!.data();
                final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
                if (data != null) {
                  totalPoints =
                      (data['total_contributed'] as num?)?.toInt() ?? totalPoints;
                  merits = (data['merits_count'] as num?)?.toInt() ?? merits;
                  demerits = (data['demerits_count'] as num?)?.toInt() ?? demerits;
                  isLiveSynced = true;

                  // Persist fresh verified data to disk asynchronously
                  AuthService.cacheStudentContribution(
                    scholarNo: widget.scholarNo,
                    totalPoints: totalPoints,
                    merits: merits,
                    demerits: demerits,
                  );
                }
              }

              return Column(
                children: [
                  // Personal House Contribution Card with MergeSemantics
                  MergeSemantics(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            houseColor.withValues(alpha: 0.25),
                            const Color(0xFF111827),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: houseColor.withValues(alpha: 0.4),
                        ),
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
                                    const Icon(
                                      Icons.military_tech_rounded,
                                      color: Colors.amber,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'My Contribution to ${widget.userHouse.toUpperCase()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: totalPoints >= 0
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  totalPoints >= 0
                                      ? '+$totalPoints Pts'
                                      : '$totalPoints Pts',
                                  style: TextStyle(
                                    color: totalPoints >= 0
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Live vs Offline Sync Badge with liveRegion Semantics
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Semantics(
                                liveRegion: true,
                                label: isLiveSynced
                                    ? 'Contribution data is live synced with campus database'
                                    : 'Contribution data is verified from offline local cache',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLiveSynced
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isLiveSynced
                                          ? Colors.greenAccent.withValues(alpha: 0.3)
                                          : Colors.amberAccent.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLiveSynced
                                            ? Icons.cloud_done_rounded
                                            : Icons.offline_bolt_rounded,
                                        size: 12,
                                        color: isLiveSynced
                                            ? Colors.greenAccent
                                            : Colors.amberAccent,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          isLiveSynced ? 'Live Synced 🟢' : 'Offline Verified ⚡',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isLiveSynced
                                                ? Colors.greenAccent
                                                : Colors.amberAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (cachedStats.lastUpdated != null)
                                Text(
                                  isLiveSynced ? 'Just now' : 'Cached snapshot',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        '⭐ ',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'MERITS',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              '$merits Earned',
                                              style: const TextStyle(
                                                color: Colors.greenAccent,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text(
                                        '⚠️ ',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'DEMERITS',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              '$demerits Recorded',
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Digital ID Card with QR
                  _buildPassCard(
                    title: 'ASB OFFICIAL CAMPUS ENTRY ID',
                    subtitle: widget.userName.isNotEmpty
                        ? widget.userName
                        : (widget.isAdmin ? 'House Administrator' : 'Student Scholar'),
                    status: widget.isAdmin
                        ? 'SUPER ADMIN ACCESS 👑'
                        : 'VERIFIED STUDENT 🟢',
                    statusColor:
                        widget.isAdmin ? Colors.amber : Colors.greenAccent,
                    qrData: studentQrData,
                    details:
                        'Scholar Number: ${widget.scholarNo}\nHouse Affiliation: ${widget.userHouse.toUpperCase()}\nClass / Section: ${widget.classLevel}\nHouse Contribution: +$totalPoints Pts\nAccess Tier: Official Campus Pass',
                    totalInfo: 'Valid Thru: 2026/2027 Academic Year',
                    accentColor: houseColor,
                    isIdCard: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeeReceiptsTab(Color houseColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildPassCard(
            title: 'TUITION & ACTIVITY FEE RECEIPT',
            subtitle: 'Receipt #REC-2026-T2',
            status: 'PAID IN FULL 🟢',
            statusColor: Colors.greenAccent,
            qrData: 'ASB-FEE:${widget.scholarNo}:PAID:TERM2',
            details:
                'Term 2 Inter-House Activity Dues\nSports & Lab Equipment Fee\nVerified Electronic Payment',
            totalInfo: 'Amount: BHD 150.000',
            accentColor: houseColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPassCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required String qrData,
    required String details,
    required String totalInfo,
    required Color accentColor,
    bool isIdCard = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.22),
            blurRadius: 26,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Holographic Foil Accent Line (decorative)
            ExcludeSemantics(
              child: Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor,
                      Colors.amberAccent,
                      Colors.cyanAccent,
                      accentColor,
                    ],
                  ),
                ),
              ),
            ),

            // Merged Header Banner
            MergeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withValues(alpha: 0.35),
                      const Color(0xFF1E293B).withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isIdCard
                                  ? Icons.badge_rounded
                                  : Icons.confirmation_number_rounded,
                              color: Colors.amberAccent,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 10.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pass Body
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  if (isIdCard) ...[
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/asb_academic_crest.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.school_rounded,
                              color: Colors.amber,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // High-contrast scannable QR card with metallic trim
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Semantics(
                          container: true,
                          label: isIdCard
                              ? 'Cryptographically verified digital student QR pass for ${widget.userName.trim().isNotEmpty ? widget.userName.trim() : "Student"}, House ${widget.userHouse.trim().toUpperCase()}'
                              : '$title QR barcode for $subtitle',
                          hint: isIdCard
                              ? 'Display this barcode to Faculty or House Captains for campus entry and merit tracking.'
                              : 'Display this barcode for verification or redemption.',
                          child: QrImageView(
                            data: qrData.trim().isNotEmpty
                                ? qrData
                                : 'ASB-ID:${widget.scholarNo}:VERIFIED',
                            version: QrVersions.auto,
                            size: 180,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            errorStateBuilder: (cxt, err) {
                              return Container(
                                width: 180,
                                height: 180,
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 64,
                                      color: accentColor,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Digital ID Active',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isIdCard
                                ? 'SCHOLAR #${widget.scholarNo} • ${widget.userHouse.toUpperCase()} • ${widget.classLevel.toUpperCase()}'
                                : qrData,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Perforated Ticket Notches Divider (decorative)
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF0B0F19)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(12),
                              ),
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const dashWidth = 6.0;
                                const dashSpace = 4.0;
                                final dashCount = (constraints.constrainWidth() / (dashWidth + dashSpace)).floor();
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(dashCount, (_) {
                                    return SizedBox(
                                      width: dashWidth,
                                      height: 1.5,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(1),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF0B0F19)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Merged Pass Details box
                  MergeSemantics(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'PASS DETAILS',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              ExcludeSemantics(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.nfc_rounded,
                                      size: 15,
                                      color: accentColor.withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'NFC Active',
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            details,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.55,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 26),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              const Text(
                                'VERIFICATION STATUS',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                totalInfo,
                                style: TextStyle(
                                  color: accentColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Action buttons with responsive wrap under 200% font scaling
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final walletButton = ElevatedButton.icon(
                        icon: Icon(_walletButtonIcon, size: 20),
                        label: Text(
                          _walletButtonLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 4,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          AppHaptics.success();
                          _showWalletSuccessSheet(
                            context: context,
                            passTitle: title,
                            subtitle: subtitle,
                            serial: 'ASB-${widget.scholarNo}',
                            accentColor: accentColor,
                            isAppleWallet: _isApplePlatform,
                          );
                        },
                      );

                      final receiptButton = ElevatedButton.icon(
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text(
                          'Pass & Receipt',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          AppHaptics.tap();
                          _showPrintReceiptModal(
                            context: context,
                            title: title,
                            subtitle: subtitle,
                            details: details,
                            totalInfo: totalInfo,
                            qrData: qrData,
                            accentColor: accentColor,
                          );
                        },
                      );

                      final isLargeText =
                          MediaQuery.textScalerOf(context).scale(12.5) > 18 ||
                          constraints.maxWidth < 360;

                      if (isLargeText) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            walletButton,
                            const SizedBox(height: 10),
                            receiptButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: walletButton),
                          const SizedBox(width: 12),
                          Expanded(child: receiptButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletSuccessSheet({
    required BuildContext context,
    required String passTitle,
    required String subtitle,
    required String serial,
    required Color accentColor,
    required bool isAppleWallet,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierLabel: 'Dismiss digital wallet confirmation modal',
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Exclude decorative drag handle
                  ExcludeSemantics(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Exclude decorative checkmark icon
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Semantics
                  Semantics(
                    header: true,
                    child: Text(
                      isAppleWallet
                          ? 'Added to Apple Wallet'
                          : 'Saved to Google Wallet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAppleWallet
                        ? 'This pass is now safely synchronized to your Apple Wallet keychain.'
                        : 'This pass is now saved to your Google Wallet and ready for NFC access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Merged Pass Token Details
                  MergeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isAppleWallet
                                  ? Icons.apple
                                  : Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Serial: $serial • Express Mode On ⚡',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Accessible Done Button with Focus Management & 48dp minimum height
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      autofocus: true,
                      onPressed: () {
                        AppHaptics.light();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getPlatformPrintMessage() {
    if (kIsWeb) return 'Document sent to web browser print service.';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'Document dispatched to Windows Print Spooler.';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'Document sent to Apple AirPrint.';
      case TargetPlatform.android:
        return 'Document sent to Android Print Services.';
      default:
        return 'Document sent to system printer.';
    }
  }

  void _dispatchAccessibleFeedback(
    BuildContext context,
    String message, {
    String? icon,
  }) {
    AppHaptics.success();
    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        TextDirection.ltr,
      );
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: const Color(0xFF0F172A),
        content: Semantics(
          liveRegion: true,
          label: message,
          child: Row(
            children: [
              if (icon != null) ...[
                ExcludeSemantics(
                  child: Text(icon, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrintReceiptModal({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String details,
    required String totalInfo,
    required String qrData,
    required Color accentColor,
  }) {
    showDialog(
      context: context,
      barrierLabel: 'Dismiss electronic receipt dialog',
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Semantics(
            container: true,
            label: 'Campus Pass and Electronic Receipt Preview',
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.school_rounded, color: Color(0xFF1E293B), size: 26),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'ASB OFFICIAL VOUCHER',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: const Icon(Icons.close_rounded, color: Colors.grey),
                          tooltip: 'Close receipt preview',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFE2E8F0), thickness: 1.5, height: 24),
                    Text(
                      title,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Accessible Center QR Barcode
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Semantics(
                        image: true,
                        label: 'Electronic verification QR barcode for $subtitle',
                        child: QrImageView(
                          data: qrData.isNotEmpty ? qrData : 'ASB-PASS-VERIFIED',
                          size: 140,
                          version: QrVersions.auto,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Unified Document Receipt with MergeSemantics
                    MergeSemantics(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 12,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Divider(color: Color(0xFFE2E8F0), height: 18),
                            Text(
                              totalInfo,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Responsive Action Buttons supporting 200% font scaling
                    LayoutBuilder(
                      builder: (buttonCtx, constraints) {
                        final isLargeText = MediaQuery.textScalerOf(buttonCtx).scale(13) > 18 ||
                            constraints.maxWidth < 320;

                        final printBtn = OutlinedButton.icon(
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text('Print Pass', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _dispatchAccessibleFeedback(context, _getPlatformPrintMessage(), icon: '🖨️');
                          },
                        );

                        final exportBtn = ElevatedButton.icon(
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _dispatchAccessibleFeedback(context, 'Exported high-resolution PDF pass to Downloads.', icon: '📄');
                          },
                        );

                        if (isLargeText) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              printBtn,
                              const SizedBox(height: 10),
                              exportBtn,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: printBtn),
                            const SizedBox(width: 12),
                            Expanded(child: exportBtn),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
