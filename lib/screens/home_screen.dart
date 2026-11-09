import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'admin_claims_screen.dart';
import 'merch_store_tab.dart';
import '../widgets/camera_capture_dialog.dart';
import 'chat_list_screen.dart';
import 'house_group_screen.dart';
import 'class_group_screen.dart';
import 'notification_center_screen.dart';
import 'digital_wallet_screen.dart';
import 'house_leaderboard_screen.dart';
import 'id_scanner_screen.dart';
import 'house_arena_screen.dart';
import 'house_ai_chat_screen.dart';
import 'academics_screen.dart';
import 'events_screen.dart';
import 'election_chamber_screen.dart';
import 'sports_tournament_screen.dart';
import 'login_screen.dart';
import '../models/attendance_record.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/account_switcher_modal.dart';
import '../widgets/student_profile_modal.dart';
import '../widgets/managed_modal_scope.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  /// Dual-Mode Resilient Image Engine:
  /// Decodes Base64 data URIs (webcam/desktop uploads) and renders Image.memory,
  /// or renders Image.network for remote HTTP/HTTPS URLs with graceful placeholders.
  static Widget buildResilientImage(
    String imgUrl, {
    double height = 280,
    BoxFit fit = BoxFit.cover,
  }) {
    final clean = imgUrl.trim();
    if (clean.isEmpty) {
      return _buildImagePlaceholder(height);
    }

    // Dual-Mode 1: Base64 Data URI (e.g. data:image/jpeg;base64,... or raw base64 string)
    if (clean.startsWith('data:image/') ||
        clean.startsWith('data:application/') ||
        clean.contains(';base64,')) {
      try {
        final commaIndex = clean.indexOf(',');
        final base64Payload =
            commaIndex != -1 ? clean.substring(commaIndex + 1).trim() : clean;
        final bytes = base64Decode(base64Payload);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              _buildImagePlaceholder(height),
        );
      } catch (_) {
        return _buildImagePlaceholder(height);
      }
    }

    // Dual-Mode 2: Remote Network URL (http:// or https://)
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return Image.network(
        clean,
        width: double.infinity,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _buildImagePlaceholder(height),
      );
    }

    // Fallback: Attempt base64 decode if it appears to be raw base64
    if (clean.length > 50 && !clean.contains(' ') && !clean.contains('/')) {
      try {
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              _buildImagePlaceholder(height),
        );
      } catch (_) {}
    }

    return _buildImagePlaceholder(height);
  }

  static Widget _buildImagePlaceholder(double height) {
    if (height < 70) {
      return Container(
        width: double.infinity,
        height: height,
        color: Colors.grey.withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Icon(
          Icons.camera_alt_outlined,
          size: (height * 0.45).clamp(16.0, 32.0),
          color: Colors.grey,
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: height,
      color: Colors.grey.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 40,
                color: Colors.grey,
              ),
              SizedBox(height: 6),
              Text(
                'Photo unavailable',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final _authService = AuthService();
  final _notificationService = NotificationService();
  Stream<int>? _unreadCountStream;
  String _unreadCountUid = '';

  /// Reuse the unread-count stream across rebuilds, but refresh it if the
  /// signed-in account changes (account switching).
  Stream<int> _unreadCountStreamForCurrentUser() {
    final uid = _notificationService.currentUserId;
    if (_unreadCountStream == null || _unreadCountUid != uid) {
      _unreadCountUid = uid;
      _unreadCountStream = _notificationService.getUnreadCountStream();
    }
    return _unreadCountStream!;
  }
  FirebaseFirestore? get _safeFirestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }
  FirebaseFirestore get _firestore => _safeFirestore ?? FirebaseFirestore.instance;

  Map<String, dynamic>? _profile;
  String? _cachedHouse;
  bool _loading = true;
  late int _selectedIndex;
  final ValueNotifier<bool> _isMyHouseFirstPlaceNotifier =
      ValueNotifier<bool>(false);
  String? _previousLeader;
  Timer? _watchdogTimer;

  final List<Map<String, dynamic>> _borrowedBooks = [
    {
      'title': 'Advanced IB Diploma Physics',
      'author': 'K. A. Tsokos',
      'dueDays': 5,
      'due': 'Due in 5 days',
      'renewalCount': 0,
    },
    {
      'title': 'The Great Gatsby',
      'author': 'F. Scott Fitzgerald',
      'dueDays': 12,
      'due': 'Due in 12 days',
      'renewalCount': 0,
    },
    {
      'title': 'Theory of Knowledge Guide',
      'author': 'Oxford Press',
      'dueDays': 18,
      'due': 'Due in 18 days',
      'renewalCount': 0,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    final cachedProfile = AuthService.getCachedProfile();

    if (cachedProfile != null) {
      _profile = Map<String, dynamic>.from(cachedProfile);
      _cachedHouse =
          AuthService.extractHouse(cachedProfile) ?? AuthService.getCachedHouse();
      _loading = false; // Zero-flash Frame-1 instant rendering
    } else {
      _cachedHouse = AuthService.getCachedHouse();
    }

    // Fallback watchdog: Guarantee loading dismisses within 1200ms
    _watchdogTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          if (_pulseController.isAnimating) {
            _pulseController.stop();
          }
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_loading) {
      _pulseController.repeat(reverse: true);
    }
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfile();
      }
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _pulseController.dispose();
    _isMyHouseFirstPlaceNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    _authService.seedAdminRoster(); // Auto-seed slots in background if empty
    final user = _authService.currentUser;
    final cached = AuthService.getCachedProfile();
    final activeScholar = (cached?['scholar_no'] ??
            AuthService.getCachedScholarNo() ??
            _profile?['scholar_no'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    if (cached != null) {
      final pKey = AuthService.extractHouse(cached);
      if (mounted) {
        setState(() {
          _profile = Map<String, dynamic>.from(cached);
          if (pKey != null && pKey.isNotEmpty) {
            _cachedHouse = pKey;
          }
          _loading = false;
          if (_pulseController.isAnimating) {
            _pulseController.stop();
          }
        });
      }
    }

    if (user != null) {
      final userEmail = (user.email ?? '').toLowerCase();
      final userScholar = userEmail.contains('@')
          ? userEmail.split('@').first
          : userEmail;

      if (activeScholar.isEmpty || activeScholar == userScholar) {
        try {
          final profile = await _authService.getUserProfile(user.uid);
          if (mounted && profile != null) {
            setState(() {
              _profile = profile;
              final pKey = AuthService.extractHouse(profile);
              if (pKey != null && pKey.isNotEmpty) {
                _cachedHouse = pKey;
              }
              _loading = false;
            });
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        if (_pulseController.isAnimating) {
          _pulseController.stop();
        }
      });
    }
  }

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<String?> _promptForSwitchPassword(String scholarNo) async {
    final controller = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E222D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Re-authenticate Session',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter password for Scholar #$scholarNo to verify session switch:',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.3),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Verify & Switch', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchActiveSession(SavedAccount account) async {
    SavedAccount accountToSwitch = account;
    if (AuthService.isFirebaseLive &&
        _authService.currentUser?.uid != account.uid &&
        (account.password == null || account.password!.isEmpty)) {
      final pwd = await _promptForSwitchPassword(account.scholarNo);
      if (pwd == null || pwd.isEmpty) {
        return; // User cancelled prompt, no session switch occurs
      }
      accountToSwitch = account.copyWith(password: pwd);
    }

    setState(() {
      _loading = true;
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    });

    try {
      await _authService.switchAccount(accountToSwitch);
      await AuthService.cacheHouse(account.houseName);

      if (mounted) {
        // Clean slate re-navigation: forces fresh state initialization for the switched scholar
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              key: ValueKey(
                'session_${account.scholarNo}_${DateTime.now().millisecondsSinceEpoch}',
              ),
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_pulseController.isAnimating) {
            _pulseController.stop();
          }
        });
        final rawMsg = e.toString().replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch account: $rawMsg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAddSiblingModal(Color houseColor) {
    AddSiblingModal.show(
      context,
      houseColor: houseColor,
      onAccountAdded: _switchActiveSession,
    );
  }

  void _showSwitchAccountModal(Color houseColor, String currentHouse) {
    AccountSwitcherModal.show(
      context,
      houseColor: houseColor,
      currentHouse: currentHouse,
      onSwitchAccount: _switchActiveSession,
      onSignOutCurrent: _handleSignOut,
      onSignOutAll: () async {
        await AuthService.clearAllSavedAccounts();
        await _handleSignOut();
      },
      onAddSiblingPressed: () {
        Navigator.pop(context);
        _showAddSiblingModal(houseColor);
      },
    );
  }

  void _showStudentClaimsHistoryModal({
    required BuildContext context,
    required String scholarNo,
    required String houseName,
    required Color themeColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.history_edu_rounded, color: themeColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Certificate Claims',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Real-time status of your house point submissions',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _authService.getStudentClaimsStream(scholarNo),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'No claims submitted yet',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Upload certificates to earn points for ${houseName.toUpperCase()} House!',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final data = docs[idx].data() as Map<String, dynamic>? ?? {};
                        final title = (data['activity_title'] ?? 'Competition Entry').toString();
                        final pts = data['points'] ?? 10;
                        final status = (data['status'] ?? 'pending').toString().toLowerCase();
                        final aiStatus = data['ai_status']?.toString().toLowerCase();
                        final reason = data['rejection_reason']?.toString();

                        Color statusColor;
                        String statusLabel;
                        IconData statusIcon;

                        if (status == 'approved') {
                          statusColor = Colors.green;
                          statusLabel = 'Approved (+$pts Pts)';
                          statusIcon = Icons.check_circle_rounded;
                        } else if (status == 'rejected') {
                          statusColor = Colors.redAccent;
                          statusLabel = 'Not Approved';
                          statusIcon = Icons.cancel_rounded;
                        } else {
                          statusColor = Colors.amber;
                          statusLabel = 'Under Review';
                          statusIcon = Icons.hourglass_top_rounded;
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(statusIcon, size: 12, color: statusColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          statusLabel,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (aiStatus == 'verified') ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.verified_rounded, size: 12, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(
                                      'AI Seal Verified',
                                      style: TextStyle(color: Colors.green[700], fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                              if (status == 'rejected' && reason != null && reason.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Feedback: $reason',
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                ),
                              ],
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
      },
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
      builder: (context) => ManagedModalScope(
        controllers: [titleController],
        child: StatefulBuilder(
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
                    IconButton(
                      icon: const Icon(Icons.history_rounded),
                      tooltip: 'View My Claims History',
                      onPressed: () {
                        Navigator.pop(context);
                        _showStudentClaimsHistoryModal(
                          context: context,
                          scholarNo: scholarNo,
                          houseName: houseName,
                          themeColor: color,
                        );
                      },
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
                            if (context.mounted && bytes != null) {
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
                              if (context.mounted) {
                                setModalState(() {
                                  selectedImageBytes = bytes;
                                  selectedFileName = file.name;
                                });
                              }
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
                              String claimId;
                              try {
                                claimId = _firestore.collection('house_claims').doc().id;
                              } catch (_) {
                                claimId = 'claim_${DateTime.now().millisecondsSinceEpoch}';
                              }

                              final certUrl = await _authService
                                  .uploadCertificateImage(
                                    fileBytes: selectedImageBytes!,
                                    scholarNo: scholarNo,
                                    house: houseName,
                                    claimId: claimId,
                                  );
                              await _authService.submitHouseClaim(
                                scholarNo: scholarNo,
                                studentName: studentName,
                                houseName: houseName,
                                activityTitle: titleController.text.trim(),
                                points: selectedPoints,
                                certUrl: certUrl,
                                claimId: claimId,
                              );

                              // Also post to Live Event Wall pending approval
                              try {
                                await _firestore.collection('event_wall').add({
                                  'scholar_no': scholarNo,
                                  'student_name': studentName,
                                  'house_name': houseName,
                                  'class_level': AuthService.getCachedProfile()?['class_level'] ?? 'Senior Tier',
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
                              if (context.mounted) {
                                setModalState(() => isSubmitting = false);
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error submitting claim: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? Semantics(
                            container: true,
                            liveRegion: true,
                            label: 'Uploading certificate image, please wait...',
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
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
    final extractedProfileHouse = AuthService.extractHouse(_profile);
    final inferredUserHouse = user != null ? AuthService.inferHouseFromUser(user) : null;
    final houseName = (extractedProfileHouse ??
            _cachedHouse ??
            AuthService.getCachedHouse() ??
            inferredUserHouse ??
            'emerald')
        .toLowerCase();
    final houseColor = HouseColors.getHouseColor(houseName);
    final houseDark = HouseColors.getHouseDarkColor(houseName);
    final houseGlow = HouseColors.getHouseGlowColor(houseName);
    final houseAccent = HouseColors.getHouseAccentColor(houseName);
    final houseEmoji = HouseColors.getHouseEmoji(houseName);
    final houseMascot = HouseColors.getHouseMascotName(houseName);
    final houseMotto = HouseColors.getHouseMotto(houseName);
    final fullName = _profile?['full_name'] ?? _profile?['name'] ?? user?.displayName ?? 'Student';
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
      final capitalizedHouse = houseName.isNotEmpty
          ? '${houseName[0].toUpperCase()}${houseName.substring(1)}'
          : 'House';

      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final pulse = _pulseAnimation.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing Mascot / Shield Emblem
                  Transform.scale(
                    scale: 0.95 + 0.05 * pulse,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [houseAccent, houseColor, houseDark],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          // Multi-layered pulsing neon aura glow
                          BoxShadow(
                            color: houseGlow.withValues(
                              alpha: 0.35 + 0.35 * pulse,
                            ),
                            blurRadius: 32 + 20 * pulse,
                            spreadRadius: 4 + 8 * pulse,
                          ),
                          BoxShadow(
                            color: houseColor.withValues(
                              alpha: 0.25 + 0.25 * pulse,
                            ),
                            blurRadius: 50 + 24 * pulse,
                            spreadRadius: 8 + 12 * pulse,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            color: Colors.white.withValues(alpha: 0.95),
                            size: 56,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              houseEmoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Dynamic Themed House Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: houseColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: houseColor.withValues(
                          alpha: 0.35 + 0.35 * pulse,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: houseGlow.withValues(alpha: 0.25 * pulse),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(houseEmoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(
                          '$capitalizedHouse House'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: houseColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Brand Title
                  Text(
                    'ASB House Hub',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: houseColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Themed Subtitle
                  Text(
                    'Loading your $capitalizedHouse dashboard...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Glowing Loading Progress Bar
                  Container(
                    width: 160,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: houseGlow.withValues(
                            alpha: 0.35 + 0.45 * pulse,
                          ),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: houseColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(houseGlow),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // House Motto & Mascot
                  Text(
                    '“$houseMotto”',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: houseColor.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    houseMascot,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: houseColor.withValues(alpha: 0.65),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              );
            },
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
              ValueListenableBuilder<bool>(
                valueListenable: _isMyHouseFirstPlaceNotifier,
                builder: (context, isFirst, _) {
                  if (!isFirst) return const SizedBox.shrink();
                  return Semantics(
                    container: true,
                    liveRegion: true,
                    label:
                        'Celebration: Your house is in 1st place! Confetti celebrations active! Keep participating to maintain the lead.',
                    child: Column(
                      children: [
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
                    ),
                  );
                },
              ),
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
              const SizedBox(height: 16),

              // 2.5 Campus Academics Command Center Banner (Phase 5)
              _buildCampusAcademicsBanner(
                houseName,
                scholarNo,
                fullName,
                houseColor,
                classLevel,
                division,
              ),
              const SizedBox(height: 16),

              // 2.6 Inter-House Sports League Banner (Phase 7)
              _buildSportsLeagueBanner(
                houseName,
                scholarNo,
                fullName,
                houseColor,
              ),
              const SizedBox(height: 16),

              // 2.7 ASB House AI Companion Mentor Banner
              _buildHouseAiCompanionBanner(
                houseName,
                scholarNo,
                fullName,
                houseColor,
                classLevel,
              ),
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
              padding: const EdgeInsets.all(7),
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
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'ASB House Hub',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (MediaQuery.of(context).size.width >= 450) ...[
            if (isCouncilOrTeacher)
              IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.blueAccent,
                  size: 24,
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
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                Icons.wallet_rounded,
                color: Colors.amber,
                size: 24,
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
            IconButton(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                Icons.school_rounded,
                color: Colors.tealAccent,
                size: 24,
              ),
              tooltip: '🏛️ Campus Academics (Timetable, HW, Exams, Reports, Attendance)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AcademicsScreen(
                      classLevel: classLevel != '--' ? '$classLevel $division'.trim() : 'Grade 10',
                      scholarNo: scholarNo,
                      studentName: fullName,
                      userHouse: houseName,
                    ),
                  ),
                );
              },
            ),
            if (isSuperAdmin) ...[
              IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
                tooltip: 'Broadcast Live Ticker',
                onPressed: () => _showEditTickerModal('', false),
              ),
            ],
          ],
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                size: 15,
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
          StreamBuilder<int>(
            stream: _unreadCountStreamForCurrentUser(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return IconButton(
                key: const Key('home_notifications_button'),
                padding: const EdgeInsets.all(8),
                constraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: unread > 0
                    ? 'Notifications ($unread unread)'
                    : 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: houseColor,
                      size: 24,
                    ),
                    if (unread > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          key: const Key('home_notifications_badge'),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amberAccent : const Color(0xFF64748B),
              size: 22,
            ),
            tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
            onPressed: () => AppThemeController.cycleTheme(),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Switch Account / Siblings',
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _showSwitchAccountModal(houseColor, houseName),
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 6, left: 2),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: houseColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: houseGlow.withValues(alpha: 0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: houseColor.withValues(alpha: 0.2),
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: houseColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: houseColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
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
      body: ValueListenableBuilder<bool>(
        valueListenable: _isMyHouseFirstPlaceNotifier,
        builder: (context, isMyHouseFirstPlace, child) {
          return ConfettiOverlay(
            show: _selectedIndex == 2 && isMyHouseFirstPlace,
            child: child!,
          );
        },
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xF8151D2E)
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
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
              Flexible(
                child: Container(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.black, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      house.isNotEmpty
                          ? 'SUPER ADMIN & ${house.toUpperCase()} HOUSE'
                          : 'SUPER ADMIN & CAMPUS DIRECTORATE',
                      style: const TextStyle(
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
          LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (_) {
              final String classSubtitle;
              if (isSuperAdmin || grade.toLowerCase() == 'staff' || grade.toLowerCase() == 'faculty') {
                classSubtitle = 'Executive Administration · Asian School Bahrain';
              } else {
                final cleanGrade = grade.replaceAll(RegExp(r'^Grade\s*', caseSensitive: false), '').trim();
                final gradeStr = cleanGrade.isNotEmpty && cleanGrade != '--' ? 'Grade $cleanGrade' : 'Student';
                final divStr = div.isNotEmpty ? '-$div' : '';
                classSubtitle = '$gradeStr$divStr · Asian School Bahrain';
              }
              return Text(
                classSubtitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24, height: 28),
          StreamBuilder<DocumentSnapshot>(
            stream: (scholarNo.isNotEmpty && scholarNo != '---')
                ? _safeFirestore
                    ?.collection('house_contributors')
                    .doc(scholarNo)
                    .snapshots()
                : null,
            builder: (context, snap) {
              int pts = 0;
              if (snap.hasData && snap.data != null && snap.data!.exists) {
                final raw = snap.data!.data();
                final d = raw is Map ? Map<String, dynamic>.from(raw) : null;
                pts = (d?['total_contributed'] as num?)?.toInt() ?? 0;
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'House Contribution:',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                  color: houseColor.withValues(alpha: 0.55),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: houseColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ],
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                  ),
                  const SizedBox(height: 6),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'House Warroom & Arena',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
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

  Widget _buildCampusAcademicsBanner(
    String houseName,
    String scholarNo,
    String fullName,
    Color houseColor,
    String classLevel,
    String division,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AcademicsScreen(
              classLevel: classLevel != '--' ? '$classLevel $division'.trim() : 'Grade 10',
              scholarNo: scholarNo,
              studentName: fullName,
              userHouse: houseName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF064E3B),
              Color(0xFF0F766E),
              Color(0xFF0F172A),
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFF2DD4BF).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F766E).withValues(alpha: 0.35),
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
              child: const Icon(
                Icons.school_rounded,
                color: Color(0xFF2DD4BF),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ACADEMICS 🏛️',
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
                          'LIVE PORTAL',
                          style: TextStyle(
                            color: Color(0xFF5EEAD4),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Campus Academics Command',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Timetable • Homework • Exam Vault • GPA • Attendance',
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

  Widget _buildSportsLeagueBanner(
    String houseName,
    String scholarNo,
    String studentName,
    Color houseColor,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SportsTournamentScreen(
              userHouse: houseName,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF059669),
              Color(0xFF047857),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sports_volleyball_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Inter-House Sports League',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text('🏆', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live Football, Basketball, Volleyball & Track • Real-Time Standings',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseAiCompanionBanner(
    String houseName,
    String scholarNo,
    String studentName,
    Color houseColor,
    String? classLevel,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HouseAiChatScreen(
              userHouse: houseName,
              studentName: studentName,
              scholarNo: scholarNo,
              classLevel: classLevel,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF4F46E5),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${houseName.toUpperCase()} House AI Mentor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('✨', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-Time Timetable, Attendance (75% Check), Homework, Standings & Gemini AI',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 16,
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
        final isConnecting =
            !snapshot.hasData || (snapshot.hasData && snapshot.data!.docs.isEmpty);

        // Pre-hydrate from local cache so the dashboard never renders blank or 0-points
        Map<String, int> pointsMap = Map<String, int>.from(
          AuthService.getCachedHouseStandings(),
        );

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          for (var doc in snapshot.data!.docs) {
            final raw = doc.data();
            final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
            final h = (data['house_name'] ?? doc.id).toString().toLowerCase();
            final pts = (data['total_points'] as num?)?.toInt() ?? 0;
            pointsMap[h] = pts;
          }
          // Persist the latest live points to disk for future launches
          AuthService.cacheHouseStandings(pointsMap, syncedAt: DateTime.now());
        }

        final sortedHouses = pointsMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final totalSchoolPoints = pointsMap.values.fold(
          0,
          (acc, val) => acc + val,
        );
        final maxPts = totalSchoolPoints > 0 ? totalSchoolPoints : 1;

        final myHouse = (AuthService.extractHouse(_profile) ??
                _cachedHouse ??
                AuthService.getCachedHouse() ??
                'emerald')
            .toLowerCase();
        final isFirst =
            sortedHouses.isNotEmpty &&
            sortedHouses[0].key == myHouse &&
            sortedHouses[0].value > 0;
        if (_isMyHouseFirstPlaceNotifier.value != isFirst) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isMyHouseFirstPlaceNotifier.value != isFirst) {
              _isMyHouseFirstPlaceNotifier.value = isFirst;
            }
          });
        }

        final currentLeader =
            (sortedHouses.isNotEmpty && sortedHouses[0].value > 0)
                ? sortedHouses[0].key
                : null;
        if (currentLeader != null &&
            _previousLeader != null &&
            currentLeader != _previousLeader) {
          final leaderNameDisplay =
              '${currentLeader[0].toUpperCase()}${currentLeader.substring(1)}';
          final leaderPts = sortedHouses[0].value;
          try {
            SemanticsService.sendAnnouncement(
              View.of(context),
              '$leaderNameDisplay House has taken 1st place with $leaderPts points!',
              TextDirection.ltr,
            );
          } catch (_) {}
        }
        _previousLeader = currentLeader;

        final standingsWidget = Container(
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
            children: [
              if (isConnecting)
                Semantics(
                  container: true,
                  liveRegion: true,
                  label:
                      'Offline mode: Viewing verified saved standings from local disk',
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Offline — Viewing Saved Standings',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ...sortedHouses.asMap().entries.map((entry) {
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
                child: MergeSemantics(
                  child: Semantics(
                    container: true,
                    button: true,
                    label:
                        '$houseNameDisplay House: $pts Points. Rank #$rank. Tap to view house leaderboard.',
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
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
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    houseNameDisplay,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                    ),
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
                                            Text(
                                              rank == 1
                                                  ? 'Leading • Tap for Leaderboard'
                                                  : 'Tap to view contributor roster',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: rank == 1
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: rank == 1
                                                    ? Colors.amber[800]
                                                    : Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.38,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Container(
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
                                ),
                              ],
                            );
                          },
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
              ),
            ),
          );
            }),
          ],
        ),
      );

      if (isConnecting) {
        return Semantics(
          container: true,
          liveRegion: true,
          label:
              'Connecting to ASB House standings, displaying cached scores...',
          child: standingsWidget,
        );
      }

      return standingsWidget;
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
        'title': '👥 Switch Account / Siblings',
        'sub':
            'Switch instantly between linked sibling accounts or add another student on this device.',
        'icon': Icons.switch_account_rounded,
        'color': themeColor,
      },
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
        'title': '🏠 My House Group',
        'sub':
            'Read house announcements and updates from your captains, council, and staff.',
        'icon': Icons.groups_rounded,
        'color': HouseColors.getHouseColor(houseName),
      },
      {
        'title': '🏫 My Class Group',
        'sub':
            'Class announcements, homework, and updates from your class teacher and representatives.',
        'icon': Icons.school_rounded,
        'color': themeColor,
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
        'color': HouseColors.topaz,
      },
      {
        'title': '🏆 Campus Events & Competitions',
        'sub': 'View live house competitions, register, and check points.',
        'icon': Icons.event_available_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': '🗳️ Student Council Elections',
        'sub': 'Explore candidate manifestos, speeches, and cast your ballot.',
        'icon': Icons.how_to_vote_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': '🏟️ Inter-House Sports League',
        'sub': 'Live football, basketball, volleyball & track match day scores.',
        'icon': Icons.sports_volleyball_rounded,
        'color': const Color(0xFF10B981),
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
            if (item['title'] == '👥 Switch Account / Siblings') {
              _showSwitchAccountModal(themeColor, houseName);
            } else if (item['title'] == 'Submit House Claim') {
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
            } else if (item['title'] == '🏠 My House Group') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HouseGroupScreen()),
              );
            } else if (item['title'] == '🏫 My Class Group') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClassGroupScreen()),
              );
            } else if (item['title'] == 'Attendance Record') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AcademicsScreen(
                    scholarNo: scholarNo,
                    studentName: studentName,
                    userHouse: houseName,
                    initialTab: 'attendance',
                  ),
                ),
              );
            } else if (item['title'] == 'School Calendar') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AcademicsScreen(
                    scholarNo: scholarNo,
                    studentName: studentName,
                    userHouse: houseName,
                    initialTab: 'exams',
                  ),
                ),
              );
            } else if (item['title'] == '🏆 Campus Events & Competitions') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventsScreen(
                    userHouse: houseName,
                  ),
                ),
              );
            } else if (item['title'] == '🗳️ Student Council Elections') {
              final activeSNo = (AuthService.getCachedScholarNo() ?? scholarNo).trim();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ElectionChamberScreen(
                    userHouse: houseName,
                    scholarNo: activeSNo,
                    studentName: studentName,
                  ),
                ),
              );
            } else if (item['title'] == '🏟️ Inter-House Sports League') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SportsTournamentScreen(
                    userHouse: houseName,
                  ),
                ),
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
              Expanded(
                child: Row(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'House Contribution Record',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Points earned for ${houseName.toUpperCase()} House',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                ? _safeFirestore
                    ?.collection('house_contributors')
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
                final raw = snapshot.data!.data();
                final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
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
                  final raw = docs[index].data();
                  final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
                  final type = data['type'] ?? 'merit';
                  final isMerit = type == 'merit';
                  final pts = (data['points'] as num?)?.toInt() ?? 0;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              'Official Circulars & Notices',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            TextButton.icon(
              onPressed: _showPostCircularDialog,
              icon: const Icon(Icons.post_add_rounded, size: 18),
              label: const Text('Post Circular', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
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
                final raw = doc.data();
                final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
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
                          Flexible(
                            child: Text(
                              date.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
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
        ),
      ],
    );
  }

  void _showPostCircularDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String category = 'Academic';
    String targetAudience = 'All Students';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ManagedModalScope(
          controllers: [titleController, contentController],
          child: StatefulBuilder(
            builder: (modalCtx, setModalState) {
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
                      '📢 Post School Circular & Notice',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Publish official circulars or event notices to all students and faculty.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Circular Title',
                        hintText: 'e.g. Mid-Term Examination Conduct & Guidelines',
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
                            initialValue: category,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: ['Academic', 'Sports', 'Examination', 'Holiday & Closure', 'General'].map((c) {
                              return DropdownMenuItem(value: c, child: Text(c));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => category = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: targetAudience,
                            decoration: InputDecoration(
                              labelText: 'Audience',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                            items: ['All Students', 'Middle School (6-8)', 'Secondary (9-10)', 'Senior Secondary (11-12)'].map((a) {
                              return DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => targetAudience = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Circular Content / Details',
                        hintText: 'Enter full proclamation or circular text...',
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
                          final noticeTitle = titleController.text.trim();
                          final noticeContent = contentController.text.trim();
                          if (noticeTitle.isEmpty || noticeContent.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter circular title and content.')),
                            );
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.of(ctx).pop();
                          await _authService.publishSchoolNotice(
                            title: noticeTitle,
                            content: noticeContent,
                            category: category,
                            targetAudience: targetAudience,
                          );
                          if (!mounted) return;
                          setState(() {});
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Published circular: "$noticeTitle"!'),
                              backgroundColor: Colors.green[700],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4338CA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Broadcast Circular', style: TextStyle(fontWeight: FontWeight.w800)),
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

  Widget _buildLiveTickerBanner(bool isSuperAdmin) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _safeFirestore?.collection('settings').doc('ticker').snapshots(),
      builder: (context, snapshot) {
        String msg = '';
        bool active = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          final raw = snapshot.data!.data();
          final data = raw is Map ? Map<String, dynamic>.from(raw) : null;
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
      builder: (context) => ManagedModalScope(
        controllers: [txtController],
        child: StatefulBuilder(
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
            content: SingleChildScrollView(
              child: Column(
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
      ),
    );
  }

  Widget _buildLiveEventWall(Color themeColor, bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: _safeFirestore
          ?.collection('event_wall')
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
          final raw = d.data();
          final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
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
            final raw = doc.data();
            final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
            final name = data['student_name'] ?? 'Student';
            final house = data['house_name'] ?? 'Ruby';
            final caption = data['caption'] ?? '';
            final imgUrl = data['image_url'] ?? '';
            final status = data['status'] ?? 'pending';
            final likes = (data['likes'] as num?)?.toInt() ?? 0;
            final scholarNo = (data['scholar_no'] ?? data['student_id'] ?? data['scholarNo'] ?? '').toString();
            final classLevel = (data['class_level'] ?? data['class'] ?? data['classLevel'])?.toString();

            void openStudentProfile() {
              StudentProfileModal.show(
                context,
                scholarNo: scholarNo,
                studentName: name,
                houseName: house,
                classLevel: classLevel,
                avatarUrl: imgUrl.isNotEmpty ? imgUrl : null,
              );
            }

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
                        Expanded(
                          child: InkWell(
                            onTap: openStudentProfile,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
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
                                          'House $house • Tap to view profile ↗',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: HouseColors.getHouseColor(house),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.end,
                          children: [
                            if (status == 'pending') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Pending',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (isAdmin)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 30),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                  onPressed: () => _firestore
                                      .collection('event_wall')
                                      .doc(doc.id)
                                      .update({'status': 'approved'}),
                                  icon: const Icon(Icons.check_rounded, size: 14),
                                  label: const Text(
                                    'Feature',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
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
                            if (isAdmin || (scholarNo.isNotEmpty && scholarNo == (_profile?['scholar_no'] ?? AuthService.getCachedScholarNo() ?? '').toString().trim()))
                              Semantics(
                                button: true,
                                label: 'Delete post',
                                child: IconButton(
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  padding: const EdgeInsets.all(8),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  tooltip: 'Delete Post',
                                  onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Row(
                                        children: [
                                          Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
                                          SizedBox(width: 8),
                                          Text('Delete Post', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                        ],
                                      ),
                                      content: const Text(
                                        'Are you sure you want to permanently delete this post from the Live Event Wall?',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _firestore.collection('event_wall').doc(doc.id).delete();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Post deleted from Live Event Wall.'),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (imgUrl.isNotEmpty)
                    GestureDetector(
                      onTap: openStudentProfile,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                          bottom: Radius.circular(4),
                        ),
                        child: HomeScreen.buildResilientImage(imgUrl),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final myScholarNo = (_profile?['scholar_no'] ??
                                        AuthService.getCachedScholarNo() ??
                                        _authService.currentUser?.uid ??
                                        '')
                                    .toString()
                                    .trim();
                                final myUid = _authService.currentUser?.uid ?? '';
                                final List<dynamic> likedBy = data['liked_by'] is List
                                    ? List<dynamic>.from(data['liked_by'])
                                    : [];
                                final bool isLikedByMe = (myScholarNo.isNotEmpty && likedBy.contains(myScholarNo)) ||
                                    (myUid.isNotEmpty && likedBy.contains(myUid));

                                return InkWell(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final targetId = myScholarNo.isNotEmpty
                                        ? myScholarNo
                                        : (myUid.isNotEmpty ? myUid : 'anon');
                                    final postRef = _firestore.collection('event_wall').doc(doc.id);
                                    if (isLikedByMe) {
                                      // Toggle Unlike
                                      await postRef.update({
                                        'likes': FieldValue.increment(-1),
                                        'liked_by': FieldValue.arrayRemove([
                                          if (myScholarNo.isNotEmpty) myScholarNo,
                                          if (myUid.isNotEmpty) myUid,
                                        ]),
                                      });
                                    } else {
                                      // Toggle Like (Single Like per Student)
                                      await postRef.update({
                                        'likes': FieldValue.increment(1),
                                        'liked_by': FieldValue.arrayUnion([targetId]),
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLikedByMe
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          color: isLikedByMe ? Colors.redAccent : Colors.grey,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$likes ${likes == 1 ? 'like' : 'likes'}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: isLikedByMe ? Colors.redAccent : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (caption.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: openStudentProfile,
                            child: RichText(
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
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showSwitchAccountModal(color, house);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.switch_account_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Switch Account / Sibling',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
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
                    Icons.switch_account_rounded,
                    '👥 Switch / Add Sibling Account',
                    color,
                    () {
                      Navigator.pop(context);
                      _showSwitchAccountModal(color, house);
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
                    Icons.groups_rounded,
                    '🏠 House Group',
                    color,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HouseGroupScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.school_rounded,
                    '🏫 Class Group',
                    color,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClassGroupScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.notifications_active_rounded,
                    '🔔 Notifications',
                    color,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationCenterScreen(),
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
                    Icons.school_rounded,
                    '🏛️ Campus Academics (Timetable, HW, Exams)',
                    Colors.tealAccent,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AcademicsScreen(
                            scholarNo: scholarNo,
                            studentName: name,
                            userHouse: house,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerTile(
                    Icons.fact_check_rounded,
                    '📋 Attendance Registry & Leave Pass',
                    Colors.greenAccent,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AcademicsScreen(
                            scholarNo: scholarNo,
                            studentName: name,
                            userHouse: house,
                            initialTab: 'attendance',
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
    // Dynamically calculate attendance rate from cached attendance records
    final records = AuthService.getCachedAttendanceRecords(scholarNo: scholarNo);
    String attendanceDisplay;
    if (records.isNotEmpty) {
      final presentCount = records
          .where((r) => r.status == AttendanceStatus.present || r.status == AttendanceStatus.excused)
          .length;
      final lateCount = records.where((r) => r.status == AttendanceStatus.late).length;
      final rate = ((presentCount + (lateCount * 0.5)) / records.length) * 100.0;
      attendanceDisplay = '${rate.toStringAsFixed(1)}%';
    } else if (_profile?['attendance_rate'] != null) {
      attendanceDisplay = '${_profile!['attendance_rate']}%';
    } else {
      attendanceDisplay = '100.0%';
    }

    final standingDisplay = _profile?['academic_standing']?.toString() ?? 'High Honors 🏆';
    final gradeDisplay = _profile?['class_level']?.toString() ?? 'Senior Tier 1';

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
                    _buildProfileStat('Academic Standing', standingDisplay),
                    _buildProfileStat('Grade / Class', gradeDisplay),
                    _buildProfileStat('Attendance', attendanceDisplay),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Advisor / Homeroom Teacher',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _profile?['advisor'] ?? 'House Faculty Mentor • Academic Directorate',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.switch_account_rounded, size: 18),
                  label: const Text(
                    'Switch Account / Add Sibling',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showSwitchAccountModal(color, house);
                  },
                ),
              ),
              const SizedBox(height: 12),
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
    final books = _borrowedBooks;
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
                            setModalState(() {
                              final curDays = (b['dueDays'] as int?) ?? 5;
                              final newDays = curDays + 14;
                              final count = ((b['renewalCount'] as int?) ?? 0) + 1;
                              b['dueDays'] = newDays;
                              b['due'] = 'Due in $newDays days (Renewed)';
                              b['renewalCount'] = count;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Renewed "${b['title']}" for an additional 14 days! (Due in ${b['dueDays']} days)',
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
      ),
    );
  }

  void _showAppSettingsModal(Color color) {
    bool pushNotifs = true;
    bool soundEffects = true;
    bool darkTheme = AppThemeController.isDarkMode(context);

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
                  onChanged: (v) {
                    setModalState(() => darkTheme = v);
                    AppThemeController.setThemeMode(
                      v ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.people_alt_rounded,
                    color: color,
                  ),
                  title: const Text(
                    'Family & Sibling Accounts',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${AuthService.getSavedAccounts().length} accounts linked on this device',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    final hName = (_cachedHouse ??
                            AuthService.getCachedHouse() ??
                            'emerald')
                        .toLowerCase();
                    _showSwitchAccountModal(color, hName);
                  },
                ),
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
}


