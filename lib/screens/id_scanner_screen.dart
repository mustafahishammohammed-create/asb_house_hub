import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'student_behavior_evaluation_screen.dart';
import '../services/auth_service.dart';
import '../services/voucher_security_service.dart';

class IdScannerScreen extends StatefulWidget {
  final String evaluatorName;

  const IdScannerScreen({
    super.key,
    this.evaluatorName = 'Faculty Lead',
  });

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
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS);

    final isTestEnv = !kIsWeb &&
        (Platform.environment.containsKey('FLUTTER_TEST') ||
         WidgetsBinding.instance is! WidgetsFlutterBinding);

    if (!isMobile || isTestEnv) {
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
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
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

  Future<void> _handleManualLookup() async {
    final query = _manualSearchController.text.trim();
    if (query.isEmpty) return;
    await _handleDecodedString(query);
  }

  Future<void> _handleDecodedString(String query) async {
    setState(() => _isSearching = true);
    try {
      // 0. Check if input is a store voucher or pass
      if (query.startsWith('{') || query.startsWith('ASB-ORDER-')) {
        final voucher = VoucherSecurityService.validateVoucherPayload(query);
        if (voucher.isValid) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.green, size: 28),
                  SizedBox(width: 8),
                  Text('Voucher Verified', style: TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bill No: ${voucher.billNo ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (voucher.points != null)
                    Text('Value: ${voucher.points} House Points'),
                  if (voucher.scholarNo != null && voucher.scholarNo!.isNotEmpty)
                    Text('Scholar No: ${voucher.scholarNo}'),
                  if (voucher.items.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Redeemed Items:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ...voucher.items.map((i) => Text('• $i', style: const TextStyle(fontSize: 12))),
                  ],
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
          return;
        } else if (voucher.isTampered) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  SizedBox(width: 8),
                  Text('Tampered Voucher', style: TextStyle(fontWeight: FontWeight.w900)),
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
          return;
        }
      }

      // 1. Check if input is structured JSON student QR code
      if (query.startsWith('{') && query.endsWith('}')) {
        try {
          final decoded = jsonDecode(query);
          if (decoded is Map) {
            final data = Map<String, dynamic>.from(decoded);
            final scholar = (data['scholar_no'] ?? data['scholarNo'] ?? data['scholar_id'] ?? data['scholarId'] ?? '').toString().trim();
            final name = (data['name'] ?? data['studentName'] ?? data['full_name'] ?? 'Student').toString().trim();
            final house = AuthService.extractHouse(data) ?? (data['house_name'] ?? data['house'] ?? data['houseName'] ?? 'Ruby').toString().trim();
            final cls = (data['class'] ?? data['classLevel'] ?? data['class_level'] ?? 'Grade 11').toString().trim();
            if (scholar.isNotEmpty) {
              _navigateToEvaluation(
                scholarNo: scholar,
                studentName: name,
                houseName: house,
                classLevel: cls,
              );
              return;
            }
          }
        } catch (_) {}
      }

      // 2. Check if input is deep link or URL QR scheme (e.g. asb://student/2310910 or https://.../student/2310910)
      if (query.contains('student/')) {
        final scholar = query.split('student/').last.split('?').first.split('/').first.trim();
        if (scholar.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('scholar_no', isEqualTo: scholar)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final data = snap.docs.first.data();
            _navigateToEvaluation(
              scholarNo: data['scholar_no'] ?? scholar,
              studentName: data['full_name'] ?? 'Student',
              houseName: AuthService.extractHouse(data) ?? (data['house_name'] ?? 'Ruby').toString(),
              classLevel: '${data['class_level'] ?? "Grade 11"} ${data['division'] ?? ""}'.trim(),
            );
            return;
          } else {
            final inferred = AuthService.inferHouseFromScholarNo(scholar) ?? 'Ruby';
            _navigateToEvaluation(
              scholarNo: scholar,
              studentName: 'Scholar #$scholar',
              houseName: inferred,
              classLevel: 'Senior Tier',
            );
            return;
          }
        }
      }

      // 3. Check if input is legacy formatted QR token e.g. "ASB-ID:2310910:RUBY:VERIFIED" or "ASB-ID:2310910:VERIFIED"
      if (query.startsWith('ASB-ID')) {
        final parts = query.split(':');
        if (parts.length >= 2) {
          final scholar = parts[1].trim();
          String house = 'Ruby';
          String name = 'Student';

          if (parts.length >= 4) {
            if (parts[2].toUpperCase() != 'VERIFIED') {
              house = parts[2].trim();
            }
            if (parts[3].toUpperCase() != 'VERIFIED') {
              name = parts[3].trim();
            }
          } else if (parts.length == 3) {
            if (parts[2].toUpperCase() == 'VERIFIED') {
              house = AuthService.inferHouseFromScholarNo(scholar) ?? 'Ruby';
            } else {
              house = parts[2].trim();
            }
          }

          try {
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .where('scholar_no', isEqualTo: scholar)
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) {
              final data = snap.docs.first.data();
              _navigateToEvaluation(
                scholarNo: data['scholar_no'] ?? scholar,
                studentName: data['full_name'] ?? name,
                houseName: AuthService.extractHouse(data) ?? house,
                classLevel: '${data['class_level'] ?? "Grade 11"} ${data['division'] ?? ""}'.trim(),
              );
              return;
            }
          } catch (_) {}

          _navigateToEvaluation(
            scholarNo: scholar,
            studentName: name.isNotEmpty && name != 'Student' ? name : 'Scholar #$scholar',
            houseName: house,
            classLevel: 'Senior Tier',
          );
          return;
        }
      }

      // 4. Query Firestore users collection by scholar_no
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('scholar_no', isEqualTo: query)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final scholar = data['scholar_no'] ?? query;
        final name = data['full_name'] ?? 'Student';
        final house = AuthService.extractHouse(data) ?? (data['house_name'] ?? 'Ruby').toString();
        final cls = '${data['class_level'] ?? "Grade 11"} ${data['division'] ?? ""}';

        _navigateToEvaluation(
          scholarNo: scholar,
          studentName: name,
          houseName: house,
          classLevel: cls,
        );
        return;
      }

      // 5. If not found in Firestore, infer house and create provisional student entry
      final inferredHouse = AuthService.inferHouseFromScholarNo(query) ?? 'Ruby';
      _navigateToEvaluation(
        scholarNo: query,
        studentName: 'Scholar #$query',
        houseName: inferredHouse,
        classLevel: 'Senior Tier',
      );
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
      if (_scannerController != null) {
        try {
          final capture = await _scannerController!.analyzeImage(file.path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            final code = capture.barcodes.first.rawValue;
            if (code != null && code.trim().isNotEmpty) {
              await _handleDecodedString(code.trim());
              return;
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No QR code detected in selected image. Please try another photo or enter Scholar # below.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error analyzing image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'ASB Campus Digital ID Scanner',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isFlashOn ? Colors.amber : null,
            ),
            tooltip: _isFlashOn ? 'Turn Flashlight Off' : 'Turn Flashlight On',
            onPressed: _toggleFlashlight,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            tooltip: 'Flip Camera Front/Back',
            onPressed: _flipCamera,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Instructions Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: Colors.blue, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Point camera directly at student ID QR or digital voucher to scan in real-time.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Camera Viewfinder Box with Real-Time Scanner
            Container(
              height: 380,
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
                  // Live Camera feed or Desktop fallback
                  if (_scannerController != null)
                    Positioned.fill(
                      child: MobileScanner(
                        controller: _scannerController!,
                        onDetect: _onBarcodeDetected,
                        errorBuilder: (context, error, child) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white54),
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _initCamera(),
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Retry Camera Permission', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
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
                          Icon(
                            Icons.qr_code_rounded,
                            size: 72,
                            color: Colors.white.withValues(alpha: 0.35),
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

                  // Holographic Reticle Frame Corners
                  Positioned.fill(
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

                  // Animated Neon Laser Sweep
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 36 + (_laserAnimation.value * 300),
                        left: 36,
                        right: 36,
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
                      );
                    },
                  ),

                  // Real-Time Scanning HUD Overlay Badge
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
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
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 18),
                              tooltip: 'Flip Camera',
                              onPressed: _flipCamera,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Manual Scholar Number / QR String Input Bar
            Container(
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
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualSearchController,
                          decoration: InputDecoration(
                            hintText: 'Enter Scholar # (e.g. 2310910) or QR text...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                          ),
                          onSubmitted: (_) => _handleManualLookup(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HouseColors.ruby,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
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
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    onPressed: _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Upload QR Image / Photo from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
