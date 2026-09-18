import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import 'merch_store_tab.dart';
import 'id_scanner_screen.dart';

class DigitalWalletScreen extends StatefulWidget {
  final String userName;
  final String userHouse;
  final String scholarNo;
  final bool isAdmin;
  final int initialIndex;

  const DigitalWalletScreen({
    super.key,
    required this.userName,
    required this.userHouse,
    this.scholarNo = '2310910',
    this.isAdmin = false,
    this.initialIndex = 0,
  });

  @override
  State<DigitalWalletScreen> createState() => _DigitalWalletScreenState();
}

class _DigitalWalletScreenState extends State<DigitalWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.blueAccent,
            ),
            tooltip: 'Scan Student Digital ID',
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
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
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
          status: 'READY FOR PICKUP 🟢',
          statusColor: Colors.greenAccent,
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
    final qrFormatted =
        'ASB-ID:${widget.scholarNo}:${widget.userHouse.toUpperCase()}:${widget.userName.isNotEmpty ? widget.userName.replaceAll(':', ' ') : "Mustafa Hisham"}:VERIFIED';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Faculty / Council / Student Action Bar
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
            child: Row(
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text(
                    'Scan ID',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // StreamBuilder for Student's Real Contribution Points & Merits/Demerits
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('house_contributors')
                .doc(widget.scholarNo)
                .snapshots(),
            builder: (context, snapshot) {
              int totalPoints = 0;
              int merits = 0;
              int demerits = 0;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  totalPoints =
                      (data['total_contributed'] as num?)?.toInt() ?? 0;
                  merits = (data['merits_count'] as num?)?.toInt() ?? 0;
                  demerits = (data['demerits_count'] as num?)?.toInt() ?? 0;
                }
              }

              return Column(
                children: [
                  // Personal House Contribution Card
                  Container(
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.military_tech_rounded,
                                  color: Colors.amber,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'My Contribution to ${widget.userHouse.toUpperCase()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
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
                                    Column(
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
                                    Column(
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
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Digital ID Card with QR
                  _buildPassCard(
                    title: 'ASB OFFICIAL CAMPUS ENTRY ID',
                    subtitle: widget.userName.isNotEmpty
                        ? widget.userName
                        : 'Mustafa Hisham (Super Admin)',
                    status: widget.isAdmin
                        ? 'SUPER ADMIN ACCESS 👑'
                        : 'VERIFIED STUDENT 🟢',
                    statusColor:
                        widget.isAdmin ? Colors.amber : Colors.greenAccent,
                    qrData: qrFormatted,
                    details:
                        'Scholar Number: ${widget.scholarNo}\nHouse Affiliation: ${widget.userHouse.toUpperCase()}\nHouse Contribution: +$totalPoints Pts\nAccess Tier: Master Campus Pass',
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
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isIdCard
                          ? Icons.badge_rounded
                          : Icons.confirmation_number_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // White scannable QR box
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        qrData,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Details box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PASS DETAILS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        details,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.apple, size: 20),
                        label: const Text(
                          'Add to Apple Wallet',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pass synced with Apple Wallet!'),
                              backgroundColor: Colors.black87,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text(
                          'Download / Print',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Receipt downloaded as high-resolution PDF pass.',
                              ),
                            ),
                          );
                        },
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
  }
}
