import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'student_behavior_evaluation_screen.dart';
import '../services/auth_service.dart';
import '../services/voucher_security_service.dart';
import '../services/qr_decoder_service.dart';
import 'merch_store_tab.dart';

class IdScannerScreen extends StatefulWidget {
  final String evaluatorName;

  const IdScannerScreen({
    super.key,
    this.evaluatorName = 'Faculty Lead',
  });

  static String cleanScholarQuery(String raw) =>
      _IdScannerScreenState.cleanScholarQuery(raw);

  @override
  State<IdScannerScreen> createState() => _IdScannerScreenState();
}

class _IdScannerScreenState extends State<IdScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _scannerController;
  bool _isCameraInitializing = true;
  String? _cameraErrorMessage;
  bool _isFlashOn = false;
  bool _isProcessingScan = false;
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final TextEditingController _manualSearchController = TextEditingController();
  bool _isSearching = false;
  String? _searchErrorMessage;

  static String cleanScholarQuery(String raw) {
    var s = raw.trim();
    final prefixes = [
      RegExp(r'^scholar(?:[_\s]*(?:no\.?|id|#))?\s*[:#-]?\s*', caseSensitive: false),
      RegExp(r'^id\s*[:#-]?\s*', caseSensitive: false),
      RegExp(r'^#+\s*'),
    ];
    for (final p in prefixes) {
      s = s.replaceFirst(p, '');
    }
    return s.trim();
  }

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  bool get _hasMobileCamera =>
      _isMobilePlatform && _scannerController != null;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final isTestEnv = !kIsWeb &&
        (Platform.environment.containsKey('FLUTTER_TEST') ||
         WidgetsBinding.instance is! WidgetsFlutterBinding);

    if (!_isMobilePlatform || isTestEnv) {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage =
              'Desktop / Test Mode: Point camera at student ID QR code or voucher on mobile devices.\nEnter Scholar # or upload a QR image below.';
        });
      }
      return;
    }

    try {
      final previous = _scannerController;
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
        autoStart: true,
        formats: const [
          BarcodeFormat.qrCode,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.dataMatrix,
        ],
      );
      previous?.dispose();
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage = 'Camera scanner unavailable: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController?.dispose();
    _manualSearchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFlashlight() async {
    final cam = _scannerController;
    if (cam == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flashlight is available when mobile camera is active.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    try {
      await cam.toggleTorch();
      if (mounted) {
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Flashlight toggle error: $e')),
        );
      }
    }
  }

  Future<void> _flipCamera() async {
    final cam = _scannerController;
    if (cam == null) return;
    try {
      await cam.switchCamera();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera flip error: $e')),
        );
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessingScan) return;
    for (final barcode in capture.barcodes) {
      final rawVal = barcode.rawValue;
      if (rawVal != null && rawVal.trim().isNotEmpty) {
        _isProcessingScan = true;
        HapticFeedback.heavyImpact();
        _handleDecodedString(rawVal.trim()).then((_) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isProcessingScan = false;
              });
            }
          });
        });
        break;
      }
    }
  }

  Future<void> _navigateToEvaluation({
    required String scholarNo,
    required String studentName,
    required String houseName,
    required String classLevel,
  }) async {
    HapticFeedback.mediumImpact();
    try {
      await _scannerController?.stop();
    } catch (_) {}

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentBehaviorEvaluationScreen(
          scholarNo: scholarNo,
          studentName: studentName,
          houseName: houseName,
          classLevel: classLevel,
          evaluatorName: widget.evaluatorName,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _isProcessingScan = false;
      });
      try {
        await _scannerController?.start();
      } catch (_) {}
    }
  }

  Future<void> _showVoucherDialog(VoucherValidationResult voucher) async {
    final billNo = voucher.billNo ?? '';
    bool isAlreadyClaimed = false;
    String? claimedBy;
    DateTime? claimedAt;

    // 1. Check local GlobalWalletStore cache first
    final localIndex = GlobalWalletStore.orders.indexWhere((o) => o.receiptId == billNo);
    if (localIndex != -1 && GlobalWalletStore.orders[localIndex].isClaimed) {
      isAlreadyClaimed = true;
      claimedBy = GlobalWalletStore.orders[localIndex].claimedBy ?? 'Staff';
      claimedAt = GlobalWalletStore.orders[localIndex].claimedAt;
    }

    // 2. Check remote Firestore if not already known to be claimed
    if (!isAlreadyClaimed && billNo.isNotEmpty) {
      final remoteStatus = await VoucherSecurityService.checkVoucherClaimStatus(billNo: billNo);
      if (remoteStatus.isClaimed) {
        isAlreadyClaimed = true;
        claimedBy = remoteStatus.claimedBy ?? 'Staff';
        claimedAt = remoteStatus.claimedAt;
      }
    }

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final claimedColor = isDark ? Colors.amberAccent : const Color(0xFFB45309);
    final validColor = isDark ? Colors.greenAccent : const Color(0xFF047857);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isClaiming = false;
        bool claimedState = isAlreadyClaimed;
        String? currentClaimedBy = claimedBy;
        DateTime? currentClaimedAt = claimedAt;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(
                  claimedState ? Icons.check_circle_outline_rounded : Icons.verified_rounded,
                  color: claimedState ? Colors.blueGrey : Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    claimedState ? 'Voucher Already Claimed' : 'Voucher Verified',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prominent Status / Warning Banner
                  if (claimedState)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: claimedColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: claimedColor.withValues(alpha: 0.45)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: claimedColor, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '⚠️ Previously Claimed by ${currentClaimedBy ?? "Staff"}'
                              '${currentClaimedAt != null ? " on ${currentClaimedAt!.toLocal().toString().split('.').first}" : ""}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: claimedColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: validColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: validColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: validColor, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Valid Store Voucher. Ready for handover and fulfillment.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: validColor,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Text('Bill No: ${voucher.billNo ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (voucher.points != null)
                    Text('Value: ${voucher.points} House Points'),
                  if (voucher.scholarNo != null && voucher.scholarNo!.isNotEmpty)
                    Text('Scholar No: ${voucher.scholarNo}'),
                  if (voucher.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Redeemed Items:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ...voucher.items.map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $i', style: const TextStyle(fontSize: 12)),
                    )),
                  ],
                ],
              ),
            ),
            actions: [
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isClaiming ? null : () => Navigator.pop(ctx),
                    child: const Text('Dismiss'),
                  ),
                  if (!claimedState)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(180, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isClaiming
                          ? null
                          : () async {
                              setDialogState(() => isClaiming = true);
                              final result = await VoucherSecurityService.claimStoreVoucher(
                                billNo: billNo,
                                evaluatorName: widget.evaluatorName,
                              );
                              if ((result.success || result.alreadyClaimed) &&
                                  billNo.isNotEmpty) {
                                await GlobalWalletStore.markOrderClaimed(
                                  billNo,
                                  scholarNo: voucher.scholarNo,
                                  claimedBy: result.claimedBy ?? widget.evaluatorName,
                                  claimedAt: result.claimedAt,
                                );
                              }
                              if (!dialogCtx.mounted) return;
                              setDialogState(() {
                                isClaiming = false;
                                if (result.success || result.alreadyClaimed) {
                                  claimedState = true;
                                  currentClaimedBy =
                                      result.claimedBy ?? widget.evaluatorName;
                                  currentClaimedAt = result.claimedAt;
                                }
                              });
                              _updateLiveRegion(result.message);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result.message),
                                    backgroundColor: result.success ? Colors.green : Colors.orangeAccent,
                                  ),
                                );
                              }
                            },
                      icon: isClaiming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(isClaiming ? 'Claiming...' : 'Confirm Handover & Claim Pass'),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white60,
                        minimumSize: const Size(160, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.lock_outline_rounded, size: 18),
                      label: const Text('Pass Fulfilled'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showTamperedVoucherDialog(VoucherValidationResult voucher) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tampered Voucher',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: Text(
          'Security Warning: ${voucher.error ?? "Invalid digital signature. This voucher has been modified or forged."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _updateLiveRegion(String message) {
    if (!mounted) return;
    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  Future<void> _showTamperedPassDialog(StudentPassValidationResult pass) async {
    try {
      _scannerController?.stop();
    } catch (_) {}
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tampered Student Pass',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Security Alert: ${pass.error ?? "Invalid digital signature. This student pass has been modified or forged."}',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              if (pass.scholarNo != null && pass.scholarNo!.isNotEmpty)
                Text('Scholar #: ${pass.scholarNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (pass.studentName != null && pass.studentName!.isNotEmpty)
                Text('Student Name: ${pass.studentName}'),
              if (pass.houseName != null && pass.houseName!.isNotEmpty)
                Text('Claimed House: ${pass.houseName}'),
              if (pass.classLevel != null && pass.classLevel!.isNotEmpty)
                Text('Class Level: ${pass.classLevel}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    } finally {
      try {
        _scannerController?.start();
      } catch (_) {}
    }
  }

  Future<void> _resolveStudentAndNavigate(
    String scholarNo, {
    String? fallbackName,
    String? fallbackHouse,
  }) async {
    final cleanNo = scholarNo.trim();

    // 1. Query Firestore for real student document
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('scholar_no', isEqualTo: cleanNo)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        await _navigateToEvaluation(
          scholarNo: data['scholar_no']?.toString() ?? cleanNo,
          studentName: data['full_name']?.toString() ?? fallbackName ?? 'Student',
          houseName: AuthService.extractHouse(data) ?? fallbackHouse ?? (data['house_name'] ?? 'Ruby').toString(),
          classLevel: '${data['class_level'] ?? "Grade 11"} ${data['division'] ?? ""}'.trim(),
        );
        return;
      }
    } catch (e) {
      debugPrint('Firestore query error or timeout for scholar $cleanNo: $e');
    }

    // 2. Check local saved accounts / current active session
    final saved = AuthService.getSavedAccounts();
    final match = saved.where((a) => a.scholarNo.trim().toLowerCase() == cleanNo.toLowerCase());
    if (match.isNotEmpty) {
      final acc = match.first;
      await _navigateToEvaluation(
        scholarNo: acc.scholarNo,
        studentName: acc.fullName,
        houseName: acc.houseName,
        classLevel: acc.classLevel ?? 'Grade 11',
      );
      return;
    }

    final cachedProfile = AuthService.getCachedProfile();
    if (cachedProfile != null && cachedProfile['scholar_no']?.toString().toLowerCase() == cleanNo.toLowerCase()) {
      await _navigateToEvaluation(
        scholarNo: cachedProfile['scholar_no']?.toString() ?? cleanNo,
        studentName: cachedProfile['full_name']?.toString() ?? 'Student',
        houseName: AuthService.extractHouse(cachedProfile) ?? 'Ruby',
        classLevel: cachedProfile['class_level']?.toString() ?? 'Grade 11',
      );
      return;
    }

    // 3. If structured QR token included an explicit student name or house affiliate
    if ((fallbackName != null && fallbackName.isNotEmpty && fallbackName != 'Student') ||
        (fallbackHouse != null && fallbackHouse.isNotEmpty)) {
      await _navigateToEvaluation(
        scholarNo: cleanNo,
        studentName: (fallbackName != null && fallbackName.isNotEmpty && fallbackName != 'Student')
            ? fallbackName
            : 'Scholar #$cleanNo',
        houseName: fallbackHouse ?? 'Ruby',
        classLevel: 'Grade 11',
      );
      return;
    }

    // 4. Scholar ID not found: Display error and abort
    if (mounted) {
      setState(() {
        _searchErrorMessage = 'Scholar ID "$cleanNo" not found in school database.';
        _isSearching = false;
        _isProcessingScan = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Scholar ID "$cleanNo" not found in school database.'),
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleManualLookup() async {
    if (_isSearching || _isProcessingScan) return;
    final raw = _manualSearchController.text;
    if (raw.trim().isEmpty) {
      setState(() {
        _searchErrorMessage = 'Please enter a Scholar # or scan a QR code.';
      });
      return;
    }
    setState(() => _searchErrorMessage = null);
    await _handleDecodedString(raw.trim());
  }

  Future<void> _handleDecodedString(String query) async {
    if (_isSearching) return;
    setState(() => _isSearching = true);

    try {
      final trimmed = query.trim();

      // 0. Structured JSON payloads
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        // A. Signed student identity pass (HMAC-SHA256 verified)
        final pass = VoucherSecurityService.validateStudentPassPayload(trimmed);
        if (pass.isValid) {
          if (!mounted) return;
          _updateLiveRegion(
            'Student pass cryptographically verified for ${pass.studentName}, House ${pass.houseName}',
          );
          await _navigateToEvaluation(
            scholarNo: pass.scholarNo!,
            studentName: (pass.studentName != null && pass.studentName!.isNotEmpty)
                ? pass.studentName!
                : 'Student',
            houseName: (pass.houseName != null && pass.houseName!.isNotEmpty)
                ? pass.houseName!
                : 'Ruby',
            classLevel: (pass.classLevel != null && pass.classLevel!.isNotEmpty)
                ? pass.classLevel!
                : 'Grade 11',
          );
          return;
        } else if (pass.isTampered) {
          if (!mounted) return;
          await _showTamperedPassDialog(pass);
          return;
        }

        // B. Store voucher or merchandise pass
        final voucher = VoucherSecurityService.validateVoucherPayload(trimmed);
        if (voucher.isValid) {
          if (!mounted) return;
          await _showVoucherDialog(voucher);
          return;
        } else if (voucher.isTampered) {
          if (!mounted) return;
          await _showTamperedVoucherDialog(voucher);
          return;
        }

        // C. Legacy student JSON fallback: never trust unverified caller metadata;
        // only resolve the scholar number against Firestore / verified directory.
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            final looksLikeVoucher = data.containsKey('billNo') ||
                data.containsKey('bill_no') ||
                data.containsKey('orderId') ||
                data['type']?.toString().toLowerCase() == 'voucher';
            final scholar = (data['scholar_no'] ?? data['scholarNo'] ?? data['scholar_id'] ?? data['scholarId'] ?? '')
                .toString()
                .trim();
            if (!looksLikeVoucher && scholar.isNotEmpty) {
              await _resolveStudentAndNavigate(scholar);
              return;
            }
          }
        } catch (_) {}
      } else if (trimmed.toUpperCase().startsWith('ASB-ORDER-')) {
        // Non-JSON voucher token fallback
        final voucher = VoucherSecurityService.validateVoucherPayload(trimmed);
        if (voucher.isValid) {
          if (!mounted) return;
          await _showVoucherDialog(voucher);
          return;
        } else if (voucher.isTampered) {
          if (!mounted) return;
          await _showTamperedVoucherDialog(voucher);
          return;
        }
      }

      // 2. Deep link URL QR scheme (e.g. asb://student/2310910 or https://.../student/2310910)
      if (trimmed.toLowerCase().contains('student/')) {
        final scholar = trimmed.split(RegExp(r'student/', caseSensitive: false)).last.split('?').first.split('/').first.trim();
        final cleanScholar = cleanScholarQuery(scholar);
        if (cleanScholar.isNotEmpty) {
          await _resolveStudentAndNavigate(cleanScholar);
          return;
        }
      }

      // 3. Formatted token e.g. "ASB-ID:2310910:RUBY:VERIFIED" (case-insensitive)
      if (trimmed.toUpperCase().startsWith('ASB-ID')) {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          final scholar = cleanScholarQuery(parts[1]);
          if (scholar.isNotEmpty) {
            String house = 'Ruby';
            String name = 'Student';
            if (parts.length >= 4) {
              if (parts[2].toUpperCase() != 'VERIFIED') house = parts[2].trim();
              if (parts[3].toUpperCase() != 'VERIFIED') name = parts[3].trim();
            } else if (parts.length == 3 && parts[2].toUpperCase() != 'VERIFIED') {
              house = parts[2].trim();
            }
            await _resolveStudentAndNavigate(scholar, fallbackName: name, fallbackHouse: house);
            return;
          }
        }
      }

      // 4. Sanitize and validate pure scholar number lookup
      final cleanScholar = cleanScholarQuery(trimmed);
      final isValidScholarFormat = RegExp(r'^[A-Za-z0-9\-]{3,12}$').hasMatch(cleanScholar);

      if (!isValidScholarFormat) {
        if (!mounted) return;
        setState(() {
          _searchErrorMessage = 'Invalid Scholar #. Enter 3-12 letters/digits (e.g. 2310910).';
        });
        return;
      }

      await _resolveStudentAndNavigate(cleanScholar);
    } catch (e) {
      if (!mounted) return;
      _isProcessingScan = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lookup error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      if (!mounted) return;
      setState(() => _isSearching = true);

      String? decodedString;

      // 1. On mobile devices with an active scanner controller, try native ML Kit first
      final isMobile = !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

      if (isMobile && _scannerController != null) {
        try {
          final capture = await _scannerController!.analyzeImage(file.path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            decodedString = capture.barcodes.first.rawValue;
          }
        } catch (_) {}
      }

      // 2. On Windows Desktop, Web, or mobile fallback: decode via pure Dart engine
      if (decodedString == null || decodedString.trim().isEmpty) {
        final bytes = await file.readAsBytes();
        decodedString = await QrDecoderService.decodeQrFromBytes(bytes);
      }

      if (!mounted) return;
      setState(() => _isSearching = false);

      // 3. Process decoded QR data
      if (decodedString != null && decodedString.trim().isNotEmpty) {
        await _handleDecodedString(decodedString.trim());
        return;
      }

      // 4. Accessible failure notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            label:
                'No QR code could be decoded from the selected image. Please ensure the QR is well-lit and not blurry, or enter the Scholar number below.',
            child: const Text(
              'No QR code could be decoded from the selected image. Please ensure the QR is well-lit and not blurry, or enter the Scholar # below.',
            ),
          ),
          backgroundColor: Colors.orangeAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'ASB Campus Digital ID Scanner',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      actions: [
        if (_hasMobileCamera) ...[
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isFlashOn ? Colors.amber : null,
            ),
            tooltip: _isFlashOn ? 'Turn Flashlight Off' : 'Turn Flashlight On',
            onPressed: _toggleFlashlight,
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.flip_camera_ios_rounded),
            tooltip: 'Flip Camera Front/Back',
            onPressed: _flipCamera,
          ),
        ] else ...[
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.folder_open_rounded, color: Colors.blueAccent),
            tooltip: 'Select QR Image File from Computer',
            onPressed: _pickImageFromGallery,
          ),
        ],
      ],
    );
  }

  Widget _buildGuidanceBanner() {
    final message = _isMobilePlatform
        ? 'Point camera directly at student ID QR or digital voucher to scan in real-time.'
        : 'Desktop Mode: Upload a QR pass image from your computer or look up any student by Scholar # below.';

    final icon = _isMobilePlatform
        ? Icons.qr_code_scanner_rounded
        : Icons.desktop_windows_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopQrDropzone(BuildContext context, bool isDark) {
    return Semantics(
      button: true,
      label: 'Select QR Code image file from your computer',
      hint: 'Activates file dialog to choose a PNG or JPG pass image',
      child: InkWell(
        onTap: _pickImageFromGallery,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 380),
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A29) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.blueAccent.withValues(alpha: 0.35),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x1F448AFF),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Icon(
                          Icons.cloud_upload_rounded,
                          color: Colors.blueAccent,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Click to Browse QR Code Image',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supports PNG, JPG, JPEG, and WebP digital passes, student identity cards, and merchandise receipts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // ExcludeSemantics prevents duplicate nested interactive button focus stops
                  ExcludeSemantics(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.file_open_rounded, size: 20),
                      label: const Text(
                        'Select Image File',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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

  Widget _buildMobileViewfinder() {
    return Semantics(
      container: true,
      label: 'Camera Viewfinder for Student ID and Voucher QR Codes',
      hint: _isProcessingScan
          ? 'Processing recognized code. Please hold steady.'
          : 'Point camera steadily at a student ID barcode or digital voucher.',
      child: Container(
        constraints: const BoxConstraints(minHeight: 380),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isProcessingScan
                ? Colors.amberAccent
                : Colors.blueAccent.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isProcessingScan ? Colors.amberAccent : Colors.blueAccent)
                  .withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Live Camera feed or Mobile fallback
            if (_scannerController != null)
              Positioned.fill(
                child: MobileScanner(
                  controller: _scannerController!,
                  onDetect: _onBarcodeDetected,
                  errorBuilder: (context, error, child) {
                    return Semantics(
                      container: true,
                      liveRegion: true,
                      label:
                          'Camera Error: ${error.errorCode.name}. Allow camera permissions to scan student IDs.',
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const ExcludeSemantics(
                                child: Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white54),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Camera: ${error.errorCode.name}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Allow camera permissions to scan student IDs.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white24,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(48, 48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _initCamera(),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Retry Camera Access', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else if (_isCameraInitializing)
              const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.qr_code_rounded,
                        size: 72,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _cameraErrorMessage ?? 'Live Mobile Camera Active on Android/iOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Decorative Reticle Corners (Excluded from Screen Reader)
            Positioned.fill(
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _isProcessingScan
                            ? Colors.amberAccent
                            : Colors.white.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),

            // Decorative Laser Sweep (Positioned is direct Stack descendant inside AnimatedBuilder)
            AnimatedBuilder(
              animation: _laserAnimation,
              builder: (context, child) {
                return Positioned(
                  top: 36 + (_laserAnimation.value * 300),
                  left: 36,
                  right: 36,
                  child: ExcludeSemantics(child: child!),
                );
              },
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isProcessingScan
                        ? [
                            Colors.transparent,
                            Colors.amberAccent,
                            Colors.yellowAccent,
                            Colors.amberAccent,
                            Colors.transparent,
                          ]
                        : [
                            Colors.transparent,
                            Colors.cyanAccent,
                            Colors.greenAccent,
                            Colors.cyanAccent,
                            Colors.transparent,
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isProcessingScan ? Colors.amberAccent : Colors.cyanAccent)
                          .withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

            // Dynamic Live Region Status Badge
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Semantics(
                container: true,
                liveRegion: true,
                label: _isProcessingScan
                    ? 'QR code detected. Resolving student credentials.'
                    : 'Real-time camera scanner active.',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isProcessingScan
                              ? Colors.amberAccent.withValues(alpha: 0.7)
                              : Colors.greenAccent.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isProcessingScan
                                ? Icons.sync_rounded
                                : Icons.qr_code_scanner_rounded,
                            color: _isProcessingScan ? Colors.amberAccent : Colors.greenAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isProcessingScan ? 'RESOLVING QR...' : 'REAL-TIME SCANNER ACTIVE',
                            style: TextStyle(
                              color: _isProcessingScan ? Colors.amberAccent : Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_scannerController != null)
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 20),
                        tooltip: 'Flip camera lens',
                        onPressed: _flipCamera,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualSearchSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manual Scholar # or QR Code Lookup',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _manualSearchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Scholar # or QR Text',
                    hintText: 'e.g. 2310910',
                    errorText: _searchErrorMessage,
                    suffixIcon: _manualSearchController.text.isNotEmpty
                        ? IconButton(
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            tooltip: 'Clear search text',
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _manualSearchController.clear();
                              setState(() => _searchErrorMessage = null);
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {
                      if (_searchErrorMessage != null) {
                        _searchErrorMessage = null;
                      }
                    });
                  },
                  onSubmitted: (_) => _handleManualLookup(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HouseColors.ruby,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSearching ? null : _handleManualLookup,
                child: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Lookup', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Tooltip(
            message:
                'Select a photo containing a student QR code to decode',
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: _isSearching ? null : _pickImageFromGallery,
              icon: const Icon(Icons.photo_library_rounded, size: 20),
              label: const Text(
                'Upload QR Image / Photo from Gallery',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          if (isWide) {
            // Desktop Two-Column Viewport
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        container: true,
                        liveRegion: true,
                        label: 'Analyzing selected image for QR code, please wait...',
                        child: const LinearProgressIndicator(),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _buildGuidanceBanner(),
                            const SizedBox(height: 20),
                            _hasMobileCamera
                                ? _buildMobileViewfinder()
                                : _buildDesktopQrDropzone(context, isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: _buildManualSearchSection(context, isDark),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          // Mobile Single-Column Viewport
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(
                      container: true,
                      liveRegion: true,
                      label: 'Analyzing selected image for QR code, please wait...',
                      child: const LinearProgressIndicator(),
                    ),
                  ),
                _buildGuidanceBanner(),
                const SizedBox(height: 20),
                if (_hasMobileCamera)
                  _buildMobileViewfinder()
                else
                  _buildDesktopQrDropzone(context, isDark),
                const SizedBox(height: 24),
                _buildManualSearchSection(context, isDark),
              ],
            ),
          );
        },
      ),
    );
  }
}
