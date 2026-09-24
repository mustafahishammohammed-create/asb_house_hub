import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'admin_claims_screen.dart';
import 'merch_store_tab.dart';
import '../widgets/camera_capture_dialog.dart';
import 'chat_list_screen.dart';
import 'digital_wallet_screen.dart';
import 'house_leaderboard_screen.dart';
import 'id_scanner_screen.dart';
import 'house_arena_screen.dart';
import 'house_ai_chat_screen.dart';
import '../widgets/confetti_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _profile;
  bool _loading = true;
  int _selectedIndex = 0;
  bool _isMyHouseFirstPlace = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    _authService.seedAdminRoster(); // Auto-seed slots in background if empty
    final user = _authService.currentUser;
    if (user != null) {
      final profile = await _authService.getUserProfile(user.uid);
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showSubmitClaimModal(
    String houseName,
    String scholarNo,
    String studentName,
    Color color,
  ) {
    final titleController = TextEditingController();
    int selectedPoints = 25;
    Uint8List? selectedImageBytes;
    String? selectedFileName;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 32,
            left: 32,
            right: 32,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submit House Claim',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Upload real certificate photo for admin review',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Activity / Competition Title',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g., 1st Place in Inter-School Debate',
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Points Requested',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [10, 25, 50].map((pts) {
                    final isSel = selectedPoints == pts;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              '+$pts Pts',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isSel ? Colors.white : color,
                              ),
                            ),
                          ),
                          selected: isSel,
                          selectedColor: color,
                          onSelected: (_) {
                            AppHaptics.tap();
                            setModalState(() => selectedPoints = pts);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Certificate Proof (Required)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                if (selectedImageBytes != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            selectedImageBytes!,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          selectedFileName ?? 'certificate.jpg',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            AppHaptics.light();
                            setModalState(() {
                              selectedImageBytes = null;
                              selectedFileName = null;
                            });
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Remove & Replace',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final bytes = await showDialog<Uint8List>(
                              context: context,
                              builder: (context) => const CameraCaptureDialog(),
                            );
                            if (bytes != null) {
                              setModalState(() {
                                selectedImageBytes = bytes;
                                selectedFileName =
                                    'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.blue,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Take Photo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Use Camera',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picker = ImagePicker();
                            final file = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1024,
                              maxHeight: 1024,
                              imageQuality: 70,
                            );
                            if (file != null) {
                              final bytes = await file.readAsBytes();
                              setModalState(() {
                                selectedImageBytes = bytes;
                                selectedFileName = file.name;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.photo_library_rounded,
                                  color: color,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload File',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    fontSize: 14,
                                  ),
                                ),
                                const Text(
                                  'Device / Gallery',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: color.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter an activity title',
                                  ),
                                ),
                              );
                              return;
                            }
                            if (selectedImageBytes == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please upload or take a photo of your certificate!',
                                  ),
                                ),
                              );
                              return;
                            }

                            setModalState(() => isSubmitting = true);
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);

                            try {
                              final certUrl = await _authService
                                  .uploadCertificateImage(
                                    selectedImageBytes!,
                                    scholarNo,
                                  );
                              await _authService.submitHouseClaim(
                                scholarNo: scholarNo,
                                studentName: studentName,
                                houseName: houseName,
                                activityTitle: titleController.text.trim(),
                                points: selectedPoints,
                                certUrl: certUrl,
                              );

                              // Also post to Live Event Wall pending approval
                              try {
                                await _firestore.collection('event_wall').add({
                                  'student_name': studentName,
                                  'house_name': houseName,
                                  'caption': titleController.text.trim(),
                                  'image_url': certUrl,
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'status': 'pending',
                                  'likes': 0,
                                });
                              } catch (_) {}

                              AppHaptics.success();
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Certificate uploaded & added to Live Event Feed review!',
                                  ),
                                  backgroundColor: Colors.green[700],
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error submitting claim: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Submit for Verification',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFeatureModal(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: color.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final houseName = (_profile?['house_name'] ?? 'ruby')
        .toString()
        .toLowerCase();
    final houseColor = HouseColors.getHouseColor(houseName);
    final houseDark = HouseColors.getHouseDarkColor(houseName);
    final fullName = _profile?['full_name'] ?? user?.displayName ?? 'Student';
    final scholarNo = _profile?['scholar_no'] ?? '---';
    final classLevel = _profile?['class_level'] ?? '--';
    final division = _profile?['division'] ?? '';

    // Strict role validation via centralized HierarchyService
    final roleStr = (_profile?['role'] ?? '').toString();
    final isSuperAdmin = HierarchyService.isSuperAdmin(
      scholarNo: scholarNo,
      role: roleStr,
      fullName: fullName,
    );
    final isAdmin = HierarchyService.isAdmin(
      scholarNo: scholarNo,
      role: roleStr,
      fullName: fullName,
    );
    final isCouncilOrTeacher = HierarchyService.isCouncilOrTeacher(
      scholarNo: scholarNo,
      role: roleStr,
      fullName: fullName,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) =>
                Opacity(opacity: _pulseAnimation.value, child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [houseColor, houseDark]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: houseColor.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ASB House Hub',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: houseColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading your dashboard...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget currentTabBody;
    if (_selectedIndex == 1) {
      currentTabBody = MerchStoreTab(
        userHouse: houseName,
        houseColor: houseColor,
        houseDark: houseDark,
        scholarNo: scholarNo,
        studentName: fullName,
      );
    } else if (_selectedIndex == 2) {
      currentTabBody = RefreshIndicator(
        onRefresh: _loadProfile,
        color: houseColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏆 Live House Standings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (_isMyHouseFirstPlace) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Text('🎉', style: TextStyle(fontSize: 32)),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR HOUSE IS IN 1ST PLACE!',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Confetti celebrations active! Keep participating to maintain the lead.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _buildLiveStandingsSection(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    } else if (_selectedIndex == 3) {
      currentTabBody = RefreshIndicator(
        onRefresh: _loadProfile,
        color: houseColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '👤 My Profile & Actions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              _buildHeroCard(
                fullName,
                scholarNo,
                classLevel,
                division,
                houseName,
                houseColor,
                houseDark,
                isSuperAdmin,
              ),
              const SizedBox(height: 24),
              _buildStudentContributionRecord(
                scholarNo: scholarNo,
                studentName: fullName,
                houseName: houseName,
                houseColor: houseColor,
              ),
              const SizedBox(height: 24),
              _buildActionCards(houseName, scholarNo, fullName, houseColor),
              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    } else {
      currentTabBody = RefreshIndicator(
        onRefresh: _loadProfile,
        color: houseColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Vibrant Hero Card
              _buildHeroCard(
                fullName,
                scholarNo,
                classLevel,
                division,
                houseName,
                houseColor,
                houseDark,
                isSuperAdmin,
              ),
              const SizedBox(height: 24),

              // 👑 Hidden Admin Button (Appears if user role == 'admin' or accessible in Drawer)
              if (isAdmin) ...[
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminClaimsScreen(isSuperAdmin: isSuperAdmin),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuperAdmin
                              ? Icons.stars_rounded
                              : Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSuperAdmin
                                    ? '👑 Super Admin & Council Portal'
                                    : 'Verify Pending Claims',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                isSuperAdmin
                                    ? 'Full Master Access: Roster & Claims Review'
                                    : 'Council Review: Visually check certificates',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 2. ASB House Warroom & Spirit Clash Arena Feature Banner
              _buildHouseArenaBanner(houseName, scholarNo, fullName, houseColor, isAdmin),
              const SizedBox(height: 24),

              // 3. Real-Time House Standings (Streamed Live from Firestore)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      '🏆 Live House Standings',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: houseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Live Sync',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: houseColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLiveStandingsSection(),
              const SizedBox(height: 36),

              // 3. Student Services (No Timetable, No Homework, No Dummy Info)
              const Text(
                '⚡ Student Services',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildActionCards(houseName, scholarNo, fullName, houseColor),
              const SizedBox(height: 36),

              // 4. Live Notice Board Feed from Firestore
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      '📣 Notice Board & Circulars',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.campaign_rounded, color: houseColor, size: 24),
                ],
              ),
              const SizedBox(height: 16),
              _buildLiveNoticesFeed(houseColor),
              const SizedBox(height: 36),

              // 5. Live Instagram-Style Event Photo Feed / Wall
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      '📸 Live Event Wall',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Community Feed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildLiveEventWall(houseColor, isAdmin || isSuperAdmin),
              const SizedBox(height: 100),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              size: 28,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [houseColor, houseDark]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: houseColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'ASB House Hub',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (isCouncilOrTeacher)
            IconButton(
              icon: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.blueAccent,
                size: 26,
              ),
              tooltip: 'Campus Digital ID Scanner (Faculty & Council)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IdScannerScreen(
                      evaluatorName: fullName.isNotEmpty ? fullName : 'Faculty Lead',
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(
              Icons.wallet_rounded,
              color: Colors.amber,
              size: 26,
            ),
            tooltip: 'My Digital Wallet & Passes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DigitalWalletScreen(
                    userName: fullName,
                    userHouse: houseName,
                    scholarNo: scholarNo,
                    isAdmin: isAdmin,
                    classLevel: classLevel != '--' ? '$classLevel $division'.trim() : 'Grade 11-D',
                    canScanQr: isCouncilOrTeacher,
                    userRole: roleStr.isNotEmpty ? roleStr : (isAdmin ? 'Council' : 'Student'),
                  ),
                ),
              );
            },
          ),
          if (isSuperAdmin) ...[
            IconButton(
              icon: const Icon(
                Icons.campaign_rounded,
                color: Colors.amber,
                size: 26,
              ),
              tooltip: 'Broadcast Live Ticker',
              onPressed: () => _showEditTickerModal('', false),
            ),
          ],
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purpleAccent, Colors.deepPurpleAccent],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            tooltip: '🤖 ASB House AI Advisor (Gemini)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HouseAiChatScreen(
                    userHouse: houseName,
                    studentName: fullName,
                    scholarNo: scholarNo,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined, size: 26),
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No urgent notifications at this moment.'),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBody: true,
      drawer: _buildMyJioDrawer(
        fullName,
        scholarNo,
        houseName,
        houseColor,
        houseDark,
        isAdmin,
        isSuperAdmin,
        isCouncilOrTeacher,
      ),
      body: ConfettiOverlay(
        show: _selectedIndex == 2 && _isMyHouseFirstPlace,
        child: Column(
          children: [
            _buildLiveTickerBanner(isSuperAdmin),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedIndex),
                  child: currentTabBody,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark
                      ? const Color(0xFF151D2E)
                      : Theme.of(context).colorScheme.surface)
                  .withValues(alpha: 0.78),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      0,
                      Icons.home_rounded,
                      'Dashboard',
                      houseColor,
                    ),
                    _buildNavItem(
                      1,
                      Icons.shopping_bag_rounded,
                      'Store',
                      houseColor,
                    ),
                    _buildNavItem(
                      2,
                      Icons.emoji_events_rounded,
                      'Standings',
                      houseColor,
                    ),
                    _buildNavItem(
                      3,
                      Icons.person_rounded,
                      'Profile',
                      houseColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color color) {
    final isSelected = _selectedIndex == index;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: () {
        if (_selectedIndex != index) {
          HapticFeedback.lightImpact();
          setState(() => _selectedIndex = index);
        }
      },
      borderRadius: BorderRadius.circular(16),
      splashColor: color.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? color
                  : onSurface.withValues(alpha: 0.40),
              size: isSelected ? 24 : 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    String name,
    String scholarNo,
    String grade,
    String div,
    String house,
    Color color,
    Color darkColor, [
    bool isSuperAdmin = false,
  ]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, darkColor],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${house[0].toUpperCase()}${house.substring(1)} House',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Scholar #$scholarNo',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (isSuperAdmin) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: Colors.black, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'SUPER ADMIN & RUBY HOUSE CAPTAIN',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grade $grade $div · Asian School Bahrain',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const Divider(color: Colors.white24, height: 28),
          StreamBuilder<DocumentSnapshot>(
            stream: (scholarNo.isNotEmpty && scholarNo != '---')
                ? _firestore
                    .collection('house_contributors')
                    .doc(scholarNo)
                    .snapshots()
                : null,
            builder: (context, snap) {
              int pts = 0;
              if (snap.hasData && snap.data != null && snap.data!.exists) {
                final d = snap.data!.data() as Map<String, dynamic>?;
                pts = (d?['total_contributed'] as num?)?.toInt() ?? 0;
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'House Contribution:',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pts >= 0 ? '+$pts Pts' : '$pts Pts',
                      style: TextStyle(
                        color: darkColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHouseArenaBanner(
    String houseName,
    String scholarNo,
    String fullName,
    Color houseColor,
    bool isAdmin,
  ) {
    final mascot = HouseMascot.forHouse(houseName);
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HouseArenaScreen(
              userHouse: houseName,
              scholarNo: scholarNo,
              userName: fullName,
              isAdmin: isAdmin,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E1B4B),
              houseColor.withValues(alpha: 0.85),
              const Color(0xFF0F172A),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: houseColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: houseColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                mascot.icon,
                style: const TextStyle(fontSize: 30),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'NEW ARENA 🔥',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE CLASH',
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'House Warroom & Arena',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Spirit Reactor • Daily Brain Blitz • 3D Lore',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStandingsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _authService.getHouseStandingsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        Map<String, int> pointsMap = {
          'ruby': 0,
          'sapphire': 0,
          'emerald': 0,
          'topaz': 0,
        };

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final h = (data['house_name'] ?? doc.id).toString().toLowerCase();
            final pts = (data['total_points'] ?? 0) as int;
            pointsMap[h] = pts;
          }
        }

        final sortedHouses = pointsMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final totalSchoolPoints = pointsMap.values.fold(
          0,
          (acc, val) => acc + val,
        );
        final maxPts = totalSchoolPoints > 0 ? totalSchoolPoints : 1;

        final myHouse = (_profile?['house_name'] ?? 'ruby')
            .toString()
            .toLowerCase();
        final isFirst =
            sortedHouses.isNotEmpty &&
            sortedHouses[0].key == myHouse &&
            sortedHouses[0].value > 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMyHouseFirstPlace != isFirst) {
            setState(() => _isMyHouseFirstPlace = isFirst);
          }
        });

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: sortedHouses.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final house = entry.value.key;
              final pts = entry.value.value;
              final color = HouseColors.getHouseColor(house);
              final houseNameDisplay =
                  '${house[0].toUpperCase()}${house.substring(1)}';
              // Medal emojis for top 3 positions
              const medals = {1: '🥇', 2: '🥈', 3: '🥉'};
              final medal = medals[rank];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HouseLeaderboardScreen(
                          initialHouse: houseNameDisplay,
                          initialPoints: pts,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: color.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: rank == 1
                                        ? Colors.amber.withValues(alpha: 0.2)
                                        : rank == 2
                                        ? const Color(
                                            0xFFC0C0C0,
                                          ).withValues(alpha: 0.2)
                                        : rank == 3
                                        ? const Color(
                                            0xFFCD7F32,
                                          ).withValues(alpha: 0.2)
                                        : color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: medal != null
                                        ? Text(
                                            medal,
                                            style: const TextStyle(fontSize: 18),
                                          )
                                        : Text(
                                            '#$rank',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: color,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          houseNameDisplay,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.leaderboard_outlined,
                                          size: 14,
                                          color: color.withValues(alpha: 0.8),
                                        ),
                                      ],
                                    ),
                                    if (rank == 1)
                                      Text(
                                        'Leading • Tap for Leaderboard',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber[800],
                                        ),
                                      )
                                    else
                                      Text(
                                        'Tap to view contributor roster',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$pts Pts',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: color.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pts == 0 ? 0.05 : pts / maxPts,
                            backgroundColor: color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: rank == 1 ? 10 : 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildActionCards(
    String houseName,
    String scholarNo,
    String studentName,
    Color themeColor,
  ) {
    final cards = [
      {
        'title': 'Submit House Claim',
        'sub': 'Upload competition certificates to earn points for your house.',
        'icon': Icons.emoji_events_rounded,
        'color': const Color(0xFFDC2626),
      },
      {
        'title': '1-on-1 Council & Student Chats',
        'sub':
            'Private direct messaging between students and school council members.',
        'icon': Icons.chat_bubble_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Attendance Record',
        'sub': 'View your term attendance summary and status.',
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFF059669),
      },
      {
        'title': 'School Calendar',
        'sub': 'Upcoming holidays, exams, and inter-house events.',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFFD97706),
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = cards[index];
        final color = item['color'] as Color;
        return InkWell(
          onTap: () {
            AppHaptics.light();
            if (item['title'] == 'Submit House Claim') {
              _showSubmitClaimModal(
                houseName,
                scholarNo,
                studentName,
                themeColor,
              );
            } else if (item['title'] == '1-on-1 Council & Student Chats') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              );
            } else {
              _showFeatureModal(
                item['title'] as String,
                'This module connects directly to your live school record. You can view official updates and submit records securely from home.',
                item['icon'] as IconData,
                color,
              );
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: AppGlass.cardDecoration(
              context: context,
              accentColor: color,
              radius: 24,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item['icon'] as IconData, color: color, size: 28),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['sub'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentContributionRecord({
    required String scholarNo,
    required String studentName,
    required String houseName,
    required Color houseColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: houseColor.withValues(alpha: 0.3),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: houseColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.military_tech_rounded,
                      color: houseColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'House Contribution Record',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Points earned for ${houseName.toUpperCase()} House',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HouseLeaderboardScreen(
                        initialHouse: houseName,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: houseColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Leaderboard',
                        style: TextStyle(
                          color: houseColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded,
                          size: 14, color: houseColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Real-time metrics counters
          StreamBuilder<DocumentSnapshot>(
            stream: (scholarNo.isNotEmpty && scholarNo != '---')
                ? _firestore
                    .collection('house_contributors')
                    .doc(scholarNo)
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              int totalPoints = 0;
              int merits = 0;
              int demerits = 0;

              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  totalPoints =
                      (data['total_contributed'] as num?)?.toInt() ?? 0;
                  merits = (data['merits_count'] as num?)?.toInt() ?? 0;
                  demerits = (data['demerits_count'] as num?)?.toInt() ?? 0;
                }
              }

              return Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: houseColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: houseColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NET POINTS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: houseColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalPoints >= 0 ? '+$totalPoints' : '$totalPoints',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: totalPoints >= 0 ? houseColor : Colors.red,
                            ),
                          ),
                          Text(
                            'Total Contributed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
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
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MERITS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$merits',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'Positive Records',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
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
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DEMERITS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$demerits',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.redAccent,
                            ),
                          ),
                          Text(
                            'Deductions',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Recent Conduct Activity Header
          const Text(
            'Recent Teacher Evaluations',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          // Stream of conduct logs
          StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _authService.getStudentConductStream(scholarNo),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final docs = snapshot.data ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'No conduct evaluations recorded yet. Merits or demerits awarded by teachers via Digital ID scan will appear here.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length.clamp(0, 4),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'merit';
                  final isMerit = type == 'merit';
                  final pts = (data['points'] ?? 0) as int;
                  final reason = data['reason'] ?? 'Conduct Record';
                  final teacher = data['teacher_name'] ?? 'Faculty';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: (isMerit ? Colors.green : Colors.red)
                          .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isMerit ? Colors.green : Colors.red)
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMerit
                              ? Icons.stars_rounded
                              : Icons.warning_amber_rounded,
                          color: isMerit ? Colors.green : Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reason,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Evaluated by $teacher',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isMerit ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isMerit ? '+$pts' : '$pts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
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
        ],
      ),
    );
  }

  Widget _buildLiveNoticesFeed(Color themeColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _authService.getNoticesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 52, color: Colors.grey[400]),
                const SizedBox(height: 14),
                const Text(
                  'No Circulars Posted Yet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'When school administrators publish new announcements or circulars, they will appear live right here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'School Announcement';
            final desc = data['content'] ?? '';
            final date = data['date'] ?? 'Recent';

            return Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Circular',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ),
                      Text(
                        date.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLiveTickerBanner(bool isSuperAdmin) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('settings').doc('ticker').snapshots(),
      builder: (context, snapshot) {
        String msg = '';
        bool active = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            msg = data['message'] ?? '';
            active = data['active'] ?? false;
          }
        }

        if (!active && !isSuperAdmin) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF475569), Color(0xFF334155)],
                  ),
          ),
          child: Row(
            children: [
              Icon(
                active
                    ? Icons.campaign_rounded
                    : Icons.notifications_off_rounded,
                color: Colors.amber,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active
                      ? '🚨 LIVE ANNOUNCEMENT: $msg'
                      : '📢 Ticker Inactive (Super Admin Click to Broadcast)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSuperAdmin) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showEditTickerModal(msg, active),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Edit Broadcast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showEditTickerModal(String currentMsg, bool currentActive) {
    final txtController = TextEditingController(text: currentMsg);
    bool activeState = currentActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.campaign_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text(
                'Live Broadcast Ticker',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Broadcast instant updates across all school student screens.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: txtController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Announcement Message',
                  hintText: 'e.g. Ruby House takes the lead in Sports Day!',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'Broadcast Active',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                value: activeState,
                activeThumbColor: Colors.redAccent,
                onChanged: (val) => setModalState(() => activeState = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 36),
              ),
              onPressed: () async {
                await _firestore.collection('settings').doc('ticker').set({
                  'message': txtController.text.trim(),
                  'active': activeState,
                  'updated_at': FieldValue.serverTimestamp(),
                });
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Live Ticker updated across school!'),
                  ),
                );
              },
              child: const Text(
                'Publish Broadcast',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveEventWall(Color themeColor, bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('event_wall')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snapshot.hasData ? snapshot.data!.docs : [];
        final visibleDocs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'pending';
          return status == 'approved' || isAdmin;
        }).toList();

        if (visibleDocs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'No photos on the Live Event Wall yet. Submit claims or capture moments to appear here!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleDocs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final doc = visibleDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['student_name'] ?? 'Student';
            final house = data['house_name'] ?? 'Ruby';
            final caption = data['caption'] ?? '';
            final imgUrl = data['image_url'] ?? '';
            final status = data['status'] ?? 'pending';
            final likes = (data['likes'] ?? 0) as int;

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: status == 'pending'
                      ? Colors.amber
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                  width: status == 'pending' ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: HouseColors.getHouseColor(house),
                          radius: 18,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'House $house • Live Feed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HouseColors.getHouseColor(house),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (status == 'pending') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Pending Review',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isAdmin)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              onPressed: () => _firestore
                                  .collection('event_wall')
                                  .doc(doc.id)
                                  .update({'status': 'approved'}),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text(
                                'Feature',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.stars_rounded,
                                  color: Colors.green,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Featured',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (imgUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                        bottom: Radius.circular(4),
                      ),
                      child: Image.network(
                        imgUrl,
                        width: double.infinity,
                        height: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_rounded,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _firestore
                                  .collection('event_wall')
                                  .doc(doc.id)
                                  .update({'likes': FieldValue.increment(1)}),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.redAccent,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '$likes likes',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: '$name ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                TextSpan(text: caption),
                              ],
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
        );
      },
    );
  }

  Widget _buildMyJioDrawer(
    String name,
    String scholarNo,
    String house,
    Color color,
    Color darkColor,
    bool isAdmin,
    bool isSuperAdmin, [
    bool isCouncilOrTeacher = false,
  ]) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, darkColor],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isSuperAdmin
                      ? 'Scholar #$scholarNo · ${house.toUpperCase()} · SUPER ADMIN 👑'
                      : 'Scholar #$scholarNo · ${house.toUpperCase()} House',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  if (isAdmin)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.amber,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        isSuperAdmin
                            ? '👑 Super Admin Portal'
                            : '🛡️ Verify Claims (Council)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.amber,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminClaimsScreen(isSuperAdmin: isSuperAdmin),
                          ),
                        );
                      },
                    ),
                  _buildDrawerTile(
                    Icons.chat_bubble_rounded,
                    '💬 1-on-1 Messages',
                    color,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.person_outline_rounded,
                    'My Academic Profile',
                    color,
                    () {
                      Navigator.pop(context);
                      _showAcademicProfileModal(name, scholarNo, house, color);
                    },
                  ),
                  _buildDrawerTile(
                    Icons.wallet_rounded,
                    '💳 Digital Wallet & Passes',
                    color,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DigitalWalletScreen(
                            userName: name,
                            userHouse: house,
                            scholarNo: scholarNo,
                            isAdmin: isAdmin,
                            canScanQr: isCouncilOrTeacher,
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.qr_code_rounded,
                    'Digital ID Card',
                    color,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DigitalWalletScreen(
                            userName: name,
                            userHouse: house,
                            scholarNo: scholarNo,
                            isAdmin: isAdmin,
                            canScanQr: isCouncilOrTeacher,
                            initialIndex: 1,
                          ),
                        ),
                      );
                    },
                  ),
                  if (isCouncilOrTeacher)
                    _buildDrawerTile(
                      Icons.qr_code_scanner_rounded,
                      '📷 Scan Student ID (Conduct / Merits)',
                      Colors.blueAccent,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IdScannerScreen(
                              evaluatorName:
                                  name.isNotEmpty ? name : 'Faculty Lead',
                            ),
                          ),
                        );
                      },
                    ),
                  _buildDrawerTile(
                    Icons.leaderboard_rounded,
                    '🏆 Inter-House Leaderboards',
                    Colors.amber,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HouseLeaderboardScreen(
                            initialHouse: house,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.bolt_rounded,
                    '⚔️ House Warroom & Clash Arena',
                    Colors.deepOrangeAccent,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HouseArenaScreen(
                            userHouse: house,
                            scholarNo: scholarNo,
                            userName: name,
                            isAdmin: isAdmin,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.auto_awesome_rounded,
                    '🤖 ASB House AI Advisor (Gemini)',
                    Colors.purpleAccent,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HouseAiChatScreen(
                            userHouse: house,
                            studentName: name,
                            scholarNo: scholarNo,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.shield_rounded,
                    '🛡️ House Grand Honours & Shields',
                    Colors.amber,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HouseArenaScreen(
                            userHouse: house,
                            scholarNo: scholarNo,
                            userName: name,
                            isAdmin: isAdmin,
                            initialNav: 3,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.receipt_long_rounded,
                    'Fee Receipts & Dues',
                    color,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DigitalWalletScreen(
                            userName: name,
                            userHouse: house,
                            scholarNo: scholarNo,
                            isAdmin: isAdmin,
                            canScanQr: isCouncilOrTeacher,
                            initialIndex: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.local_library_outlined,
                    'Library Books',
                    color,
                    () {
                      Navigator.pop(context);
                      _showLibraryPortalModal(color);
                    },
                  ),
                  _buildDrawerTile(
                    Icons.settings_outlined,
                    'App Settings',
                    color,
                    () {
                      Navigator.pop(context);
                      _showAppSettingsModal(color);
                    },
                  ),
                ],
              ),
            ),
          ),
          Divider(color: Colors.grey.withValues(alpha: 0.2)),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 0,
            ),
            leading: const Icon(
              Icons.switch_account_rounded,
              color: Colors.blueAccent,
              size: 26,
            ),
            title: const Text(
              'Switch Account',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _showAccountSwitcherModal(color);
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 0,
            ),
            leading: const Icon(
              Icons.logout_rounded,
              color: Colors.redAccent,
              size: 26,
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            onTap: _handleSignOut,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAcademicProfileModal(
    String name,
    String scholarNo,
    String house,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Scholar ID #$scholarNo • House $house',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildProfileStat('Academic Standing', 'High Honors 🏆'),
                    _buildProfileStat('Grade / Class', 'Senior Tier 1'),
                    _buildProfileStat('Attendance', '99.4%'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Advisor / Homeroom Teacher',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Dr. Elizabeth Vance • Science Dept Lead',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close Profile',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  void _showLibraryPortalModal(Color color) {
    final books = [
      {
        'title': 'Advanced IB Diploma Physics',
        'author': 'K. A. Tsokos',
        'due': 'Due in 5 days',
      },
      {
        'title': 'The Great Gatsby',
        'author': 'F. Scott Fitzgerald',
        'due': 'Due in 12 days',
      },
      {
        'title': 'Theory of Knowledge Guide',
        'author': 'Oxford Press',
        'due': 'Due in 18 days',
      },
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_library_rounded, color: color, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'ASB Library Portal',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Your currently borrowed textbooks and literature catalog.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ...books.map(
                (b) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['title']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${b['author']} • ${b['due']}',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color.withValues(alpha: 0.15),
                          foregroundColor: color,
                          minimumSize: const Size(0, 36),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Renewed "${b['title']}" for an additional 14 days!',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Renew Loan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppSettingsModal(Color color) {
    bool pushNotifs = true;
    bool soundEffects = true;
    bool darkTheme = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_rounded, color: color, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'App Preferences',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text(
                    'Push Notifications',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Live house point alerts & council messages',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: pushNotifs,
                  activeThumbColor: color,
                  onChanged: (v) => setModalState(() => pushNotifs = v),
                ),
                SwitchListTile(
                  title: const Text(
                    'Sound Effects & Confetti',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Celebration animations when house takes 1st place',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: soundEffects,
                  activeThumbColor: color,
                  onChanged: (v) => setModalState(() => soundEffects = v),
                ),
                SwitchListTile(
                  title: const Text(
                    'Dark Theme Aesthetic',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Matches system appearance & OLED battery saver',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: darkTheme,
                  activeThumbColor: color,
                  onChanged: (v) => setModalState(() => darkTheme = v),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.cleaning_services_rounded,
                    color: Colors.orange,
                  ),
                  title: const Text(
                    'Clear App Cache',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Temporary cache cleared. Performance optimized!',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  void _showAccountSwitcherModal(Color color) {
    final currentScholar = _profile?['scholar_no'] ?? '2310910';

    final presetAccounts = [
      {
        'name': 'Mustafa Hisham',
        'id': '2310910',
        'role': 'Super Admin',
        'house': 'Ruby',
      },
      {
        'name': 'Ruby House Captain',
        'id': '10001',
        'role': 'Council Leader',
        'house': 'Ruby',
      },
      {
        'name': 'Sarah Student Rep',
        'id': '20002',
        'role': 'Student',
        'house': 'Emerald',
      },
      {
        'name': 'Dr. Elizabeth Vance',
        'id': '30003',
        'role': 'Teacher Lead',
        'house': 'Sapphire',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.switch_account_rounded, color: color, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Switch Profile & Account',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Switch instantly between staff, council, and student profiles or add a new account.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: presetAccounts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final acc = presetAccounts[index];
                final isCurrent =
                    acc['id'] == currentScholar ||
                    (currentScholar == 'admin' && acc['id'] == '2310910');
                final houseColor = HouseColors.getHouseColor(
                  (acc['house'] ?? 'ruby').toString(),
                );

                return InkWell(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    if (!isCurrent) {
                      setState(() {
                        _loading = true;
                      });
                      try {
                        if (acc['id'] == '2310910') {
                          await _authService.signInAdmin(password: '2310910');
                          await _loadProfile();
                        } else {
                          setState(() {
                            _profile = {
                              'full_name': acc['name'],
                              'scholar_no': acc['id'],
                              'role': acc['role'] == 'Super Admin'
                                  ? 'super_admin'
                                  : (acc['role'] == 'Council Leader'
                                      ? 'council'
                                      : (acc['role'] == 'Teacher Lead'
                                          ? 'teacher'
                                          : 'student')),
                              'house_name': (acc['house'] ?? 'ruby')
                                  .toString()
                                  .toLowerCase(),
                              'class_level': '12-A',
                              'division': 'Senior Tier',
                            };
                          });
                        }
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Switched profile to ${acc['name']} (${acc['role']})',
                            ),
                            backgroundColor: houseColor,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to switch profile: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? color.withValues(alpha: 0.12)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? color
                            : Colors.grey.withValues(alpha: 0.25),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: houseColor.withValues(alpha: 0.2),
                          child: Text(
                            (acc['name'] ?? 'S')[0],
                            style: TextStyle(
                              color: houseColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      acc['name'] ?? 'Profile',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${acc['role']} • ID #${acc['id']} • House ${acc['house']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isCurrent
                              ? Icons.check_circle_rounded
                              : Icons.swap_horiz_rounded,
                          color: isCurrent ? color : Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: color, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(Icons.person_add_rounded, color: color),
                label: Text(
                  'Log Into Another Account',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _handleSignOut();
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
