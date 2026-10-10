import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Preference key used to persist first-time installation walkthrough completion.
const String kHasCompletedOnboardingKey = 'asb_has_completed_onboarding';

/// Helper for standard haptic feedback responses
class AppHaptics {
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}

/// A high-aesthetic, first-time interactive walkthrough introducing new students
/// to ASB House Hub with dynamic ambient background morphing and WCAG 2.1 AA compliance.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _orbitController;

  final List<_OnboardingSlideData> _slides = const [
    _OnboardingSlideData(
      eyebrow: '🏛️ CITADEL OF FOUR HOUSES',
      title: 'Welcome to the Arena of Houses',
      subtitle:
          'Your digital school warroom where house pride, live leaderboards, and championship camaraderie meet.',
      themePrimary: Color(0xFFE63946), // Ignis Crimson
      themeSecondary: Color(0xFF2563EB), // Zephyr Cobalt
      featurettes: [
        _Featurette(
          emoji: '🏆',
          title: 'Live Championship',
          desc: 'Real-time telemetry across all 4 houses.',
        ),
        _Featurette(
          emoji: '🎖️',
          title: 'Titan Honours',
          desc: 'Unlock prestigious badges and streaks.',
        ),
        _Featurette(
          emoji: '⚔️',
          title: 'Mascot Warroom',
          desc: '3D CAD stages, lore, and battle chants.',
        ),
      ],
      stageType: _HeroStageType.quadHouseOrbit,
    ),
    _OnboardingSlideData(
      eyebrow: '🤖 24/7 LIVE GEMINI INTELLIGENCE',
      title: 'Your Personal AI House Mentor',
      subtitle:
          'Powered by Google Gemini and deeply unified with your real-time student schedule, syllabus, and attendance.',
      themePrimary: Color(0xFF06B6D4), // Electric Cyan
      themeSecondary: Color(0xFF8B5CF6), // Cyber Violet
      featurettes: [
        _Featurette(
          emoji: '📅',
          title: 'Instant Timetable',
          desc: "Today's periods, teachers, and rooms.",
        ),
        _Featurette(
          emoji: '⚠️',
          title: '75% CBSE Guard',
          desc: 'Statutory compliance tracking and alerts.',
        ),
        _Featurette(
          emoji: '📚',
          title: 'Homework Coach',
          desc: 'Assignment priorities and exam portions.',
        ),
      ],
      stageType: _HeroStageType.neuralAiHologram,
    ),
    _OnboardingSlideData(
      eyebrow: '⚡ ACADEMIC & ATHLETIC EXCELLENCE',
      title: 'Classroom Mastery & Pitch Glory',
      subtitle:
          'Track every assignment, exam timetable, and tournament match in real-time with zero friction.',
      themePrimary: Color(0xFFF59E0B), // Trophy Amber
      themeSecondary: Color(0xFF10B981), // Stadium Emerald
      featurettes: [
        _Featurette(
          emoji: '📋',
          title: 'Academic Tracker',
          desc: 'Assignments with countdown due dates.',
        ),
        _Featurette(
          emoji: '⚽',
          title: 'Sports League HUD',
          desc: 'Live scores and referee certification.',
        ),
        _Featurette(
          emoji: '📊',
          title: 'Report Cards',
          desc: 'Exam portion guides and grade records.',
        ),
      ],
      stageType: _HeroStageType.twinArenaDeck,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    AppHaptics.heavy();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kHasCompletedOnboardingKey, true);
    } catch (e) {
      debugPrint('Error saving onboarding preference: $e');
    }

    if (!mounted) return;

    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _nextPage() {
    AppHaptics.light();
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSlide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0E17)
          : const Color(0xFFF4F7FC),
      body: Stack(
        children: [
          // 1. Dynamic Ambient Background Glow that morphs per slide
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    currentSlide.themePrimary.withValues(alpha: isDark ? 0.22 : 0.12),
                    currentSlide.themeSecondary.withValues(alpha: isDark ? 0.08 : 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 2. Main Scrollable Content
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar (Skip + Theme Switcher)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Skip Button
                      Semantics(
                        button: true,
                        label: 'Skip introduction and proceed to sign in',
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          child: TextButton.icon(
                            onPressed: _completeOnboarding,
                            icon: const Icon(Icons.fast_forward_rounded, size: 16),
                            label: const Text(
                              'Skip',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ),

                      // Quick Theme Switcher
                      Semantics(
                        button: true,
                        label: 'Toggle application color theme',
                        child: IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: isDark ? Colors.amberAccent : const Color(0xFF2A6FDB),
                          ),
                          tooltip: 'Switch Theme',
                          onPressed: () => AppThemeController.cycleTheme(),
                        ),
                      ),
                    ],
                  ),
                ),

                // PageView Deck
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return _buildSlidePage(context, _slides[index], isDark);
                    },
                  ),
                ),

                // Bottom Navigation Deck (Indicators + Primary CTA)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Expanding Worm Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (index) {
                          final isActive = index == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: isActive ? 28 : 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? currentSlide.themePrimary
                                  : (isDark ? Colors.white24 : Colors.black12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Primary CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentSlide.themePrimary,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: currentSlide.themePrimary.withValues(alpha: 0.45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == _slides.length - 1
                                    ? 'Continue to Sign In 🚀'
                                    : 'Next Step →',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
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
  }

  Widget _buildSlidePage(BuildContext context, _OnboardingSlideData slide, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // Custom Vector Hero Visual Stage
          _buildHeroStage(slide, isDark),

          const SizedBox(height: 20),

          // Eyebrow Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: slide.themePrimary.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: slide.themePrimary.withValues(alpha: isDark ? 0.40 : 0.25),
              ),
            ),
            child: Text(
              slide.eyebrow,
              style: TextStyle(
                color: slide.themePrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),

          const SizedBox(height: 20),

          // 3 Featurette Cards
          Column(
            children: slide.featurettes.map((f) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131B2A).withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: slide.themePrimary.withValues(alpha: isDark ? 0.15 : 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(f.emoji, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.desc,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeroStage(_OnboardingSlideData slide, bool isDark) {
    switch (slide.stageType) {
      case _HeroStageType.quadHouseOrbit:
        return _buildQuadHouseStage(slide, isDark);
      case _HeroStageType.neuralAiHologram:
        return _buildNeuralAiStage(slide, isDark);
      case _HeroStageType.twinArenaDeck:
        return _buildTwinArenaStage(slide, isDark);
    }
  }

  Widget _buildQuadHouseStage(_OnboardingSlideData slide, bool isDark) {
    return SizedBox(
      height: 160,
      width: 250,
      child: AnimatedBuilder(
        animation: _orbitController,
        builder: (context, child) {
          final angle = _orbitController.value * 2 * math.pi;
          const double radiusX = 76.0;
          const double radiusY = 46.0;

          // Sinusoidal bounce modulation
          final bounce1 = math.sin(angle * 2) * 5.5;
          final bounce2 = math.cos(angle * 2) * 5.5;

          // Orbital positions with harmonic vertical bounce
          final rubyX = radiusX * math.cos(angle);
          final rubyY = radiusY * math.sin(angle) + bounce1;

          final sapphireX = radiusX * math.cos(angle + math.pi / 2);
          final sapphireY = radiusY * math.sin(angle + math.pi / 2) + bounce2;

          final emeraldX = radiusX * math.cos(angle + math.pi);
          final emeraldY = radiusY * math.sin(angle + math.pi) - bounce1;

          final topazX = radiusX * math.cos(angle + 3 * math.pi / 2);
          final topazY = radiusY * math.sin(angle + 3 * math.pi / 2) - bounce2;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Faint orbital ellipse track
              Container(
                width: radiusX * 2 + 16,
                height: radiusY * 2 + 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(radiusX + 8, radiusY + 8)),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
              ),

              // Central Golden Crest with Pulsing Glow Halo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.50),
                      blurRadius: 24,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 38),
              ),

              // 4 Bouncing & Glowing House Emblems
              _buildOrbitBadge('🔥', const Color(0xFFE63946), const Color(0xFFFF4D4F), rubyX, rubyY, angle),
              _buildOrbitBadge('⚡', const Color(0xFF2563EB), const Color(0xFF4096FF), sapphireX, sapphireY, angle + math.pi / 2),
              _buildOrbitBadge('🐺', const Color(0xFF059669), const Color(0xFF52C41A), emeraldX, emeraldY, angle + math.pi),
              _buildOrbitBadge('☀️', const Color(0xFFD97706), const Color(0xFFFFC53D), topazX, topazY, angle + 3 * math.pi / 2),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrbitBadge(String emoji, Color baseColor, Color glowColor, double dx, double dy, double localAngle) {
    final scale = 1.0 + 0.07 * math.sin(localAngle * 2);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: baseColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.70),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Widget _buildNeuralAiStage(_OnboardingSlideData slide, bool isDark) {
    return SizedBox(
      height: 140,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Concentric Glowing Neon Rings
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
          Container(
            width: 95,
            height: 95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          // Central Core Orb
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: 3,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildTwinArenaStage(_OnboardingSlideData slide, bool isDark) {
    return SizedBox(
      height: 130,
      width: 240,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left: Academic Card
          Container(
            width: 105,
            height: 110,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, color: Color(0xFFF59E0B), size: 26),
                SizedBox(height: 4),
                Text(
                  'Academics',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  '92% HW Done',
                  style: TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Right: Sports Stadium Card
          Container(
            width: 105,
            height: 110,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_rounded, color: Color(0xFF10B981), size: 26),
                SizedBox(height: 4),
                Text(
                  'Sports League',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Live Fixtures',
                  style: TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _HeroStageType { quadHouseOrbit, neuralAiHologram, twinArenaDeck }

class _Featurette {
  final String emoji;
  final String title;
  final String desc;
  const _Featurette({required this.emoji, required this.title, required this.desc});
}

class _OnboardingSlideData {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color themePrimary;
  final Color themeSecondary;
  final List<_Featurette> featurettes;
  final _HeroStageType stageType;

  const _OnboardingSlideData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.themePrimary,
    required this.themeSecondary,
    required this.featurettes,
    required this.stageType,
  });
}
