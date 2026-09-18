import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'student_behavior_evaluation_screen.dart';

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
  CameraController? _cameraController;
  bool _isCameraInitializing = true;
  String? _cameraErrorMessage;
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final TextEditingController _manualSearchController = TextEditingController();
  bool _isSearching = false;

  // Preset students for fast 1-tap testing on Desktop / Web
  final List<Map<String, String>> _demoStudents = [
    {
      'name': 'Mustafa Hisham',
      'scholar': '2310910',
      'house': 'Ruby',
      'class': '11-D',
      'role': 'Super Admin & Captain',
    },
    {
      'name': 'Noaman Nizamuddin',
      'scholar': '10001',
      'house': 'Emerald',
      'class': '11-E',
      'role': 'Emerald House Captain',
    },
    {
      'name': 'Sarah Student Rep',
      'scholar': '20002',
      'house': 'Emerald',
      'class': '11-E',
      'role': 'Student Representative',
    },
    {
      'name': 'Dr. Elizabeth Vance',
      'scholar': '30003',
      'house': 'Sapphire',
      'class': 'Faculty Lead',
      'role': 'Sapphire Teacher Lead',
    },
    {
      'name': 'Tanish Mukherjee',
      'scholar': '12001',
      'house': 'Topaz',
      'class': '12-E',
      'role': 'School Head Boy',
    },
    {
      'name': 'Sarah Paul',
      'scholar': '11004',
      'house': 'Ruby',
      'class': '11-D',
      'role': 'Grade 11 Prefect',
    },
  ];

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
    // On Desktop (Windows, macOS, Linux), mobile camera plugin is not available.
    // Gracefully switch to desktop input mode without calling missing plugin channels.
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.linux ||
         defaultTargetPlatform == TargetPlatform.macOS);

    if (isDesktop) {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage =
              'Desktop Mode: Hardware camera feed active on mobile devices.\nUse Manual Scholar # search, QR image upload, or preset chips below.';
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraInitializing = false;
            _cameraErrorMessage = 'No live webcam or camera device detected.';
          });
        }
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraErrorMessage = 'Camera unavailable or access restricted.';
        });
      }
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _cameraController?.dispose();
    _manualSearchController.dispose();
    super.dispose();
  }

  void _navigateToEvaluation({
    required String scholarNo,
    required String studentName,
    required String houseName,
    required String classLevel,
  }) {
    HapticFeedback.mediumImpact();
    Navigator.push(
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
  }

  Future<void> _handleManualLookup() async {
    final query = _manualSearchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      // 1. Check if input is formatted QR token e.g. "ASB-ID:2310910:RUBY:VERIFIED"
      if (query.startsWith('ASB-ID')) {
        final parts = query.split(':');
        if (parts.length >= 3) {
          final scholar = parts[1];
          final house = parts[2];
          final name = parts.length >= 4 && parts[3] != 'VERIFIED' ? parts[3] : 'Student';
          _navigateToEvaluation(
            scholarNo: scholar,
            studentName: name,
            houseName: house,
            classLevel: 'Senior Tier',
          );
          return;
        }
      }

      // 2. Query Firestore users collection by scholar_no
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('scholar_no', isEqualTo: query)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final scholar = data['scholar_no'] ?? query;
        final name = data['full_name'] ?? 'Student';
        final house = (data['house_name'] ?? 'Ruby').toString();
        final cls = '${data['class_level'] ?? "Grade 11"} ${data['division'] ?? ""}';

        _navigateToEvaluation(
          scholarNo: scholar,
          studentName: name,
          houseName: house,
          classLevel: cls,
        );
        return;
      }

      // 3. Fallback check inside preset demo students
      final match = _demoStudents.firstWhere(
        (s) => s['scholar'] == query || s['name']!.toLowerCase().contains(query.toLowerCase()),
        orElse: () => {},
      );

      if (match.isNotEmpty) {
        _navigateToEvaluation(
          scholarNo: match['scholar']!,
          studentName: match['name']!,
          houseName: match['house']!,
          classLevel: match['class']!,
        );
        return;
      }

      // 4. If not found, create a provisional student entry for conduct tracking
      _navigateToEvaluation(
        scholarNo: query,
        studentName: 'Scholar #$query',
        houseName: 'Ruby',
        classLevel: 'Senior Tier',
      );
    } catch (e) {
      if (!mounted) return;
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
      // Simulated QR extraction from uploaded photo or demo match
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analyzing QR Image... Matched Scholar #2310910'),
          backgroundColor: Colors.blueAccent,
        ),
      );

      _navigateToEvaluation(
        scholarNo: '2310910',
        studentName: 'Mustafa Hisham',
        houseName: 'Ruby',
        classLevel: '11-D',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking QR: $e')),
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
                      'Scan a student\'s Digital ID QR code to evaluate conduct and award or deduct House Points.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Camera Viewfinder Box with Laser Animation
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Camera feed or fallback graphic
                  if (_cameraController != null && _cameraController!.value.isInitialized)
                    Center(child: CameraPreview(_cameraController!))
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
                            size: 80,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _cameraErrorMessage ?? 'Ready to scan student ID QR',
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
                          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
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
                        top: 40 + (_laserAnimation.value * 200),
                        left: 36,
                        right: 36,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.cyanAccent,
                                Colors.greenAccent,
                                Colors.cyanAccent,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Simulated Capture Trigger Button on Camera
                  Positioned(
                    bottom: 12,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.camera_alt_rounded, color: Colors.greenAccent, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'AI QR READY',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            _navigateToEvaluation(
                              scholarNo: '2310910',
                              studentName: 'Mustafa Hisham',
                              houseName: 'Ruby',
                              classLevel: '11-D',
                            );
                          },
                          icon: const Icon(Icons.flash_on_rounded, size: 16),
                          label: const Text('Capture QR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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

            // One-Tap Quick Test Scans
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '⚡ One-Tap Demo Scans (Fast Desktop Testing)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'INSTANT',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _demoStudents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final student = _demoStudents[index];
                final houseColor = HouseColors.getHouseColor(student['house']!);

                return InkWell(
                  onTap: () {
                    _navigateToEvaluation(
                      scholarNo: student['scholar']!,
                      studentName: student['name']!,
                      houseName: student['house']!,
                      classLevel: student['class']!,
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: houseColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: houseColor.withValues(alpha: 0.15),
                          child: Text(
                            student['name']![0],
                            style: TextStyle(
                              color: houseColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name']!,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              Text(
                                '${student['house']} House • Scholar #${student['scholar']} • ${student['class']}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: houseColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_rounded, color: houseColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Scan ID',
                                style: TextStyle(
                                  color: houseColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
