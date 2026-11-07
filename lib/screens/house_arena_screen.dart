import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/gamification_security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/apple_fitness_badges_vault.dart';
import '../widgets/mascot_3d_stage.dart';
import '../widgets/battle_chant_synthesizer.dart';

/// Interactive Mascot Data
class HouseMascot {
  final String name;
  final String title;
  final String element;
  final String motto;
  final String battleCry;
  final String icon;
  final String description;
  final Color primaryColor;
  final Color accentColor;

  const HouseMascot({
    required this.name,
    required this.title,
    required this.element,
    required this.motto,
    required this.battleCry,
    required this.icon,
    required this.description,
    required this.primaryColor,
    required this.accentColor,
  });

  static HouseMascot forHouse(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return const HouseMascot(
          name: 'Ignis the Crimson Dragon',
          title: 'Sovereign of the Blazing Hearth',
          element: 'Solar Flare & Molten Fury',
          motto: 'Courage, Honor & Unyielding Fire',
          battleCry: 'RUBY ROARS! IN FIRE WE CONQUER! 🔥',
          icon: '🐉',
          description:
              'Forged in the heart of courage and relentless passion. Ignis embodies the fearless drive of Ruby House warriors who never back down.',
          primaryColor: HouseColors.ruby,
          accentColor: Color(0xFFFFA39E),
        );
      case 'sapphire':
        return const HouseMascot(
          name: 'Zephyr the Tempest Gryphon',
          title: 'Master of the Endless Azure Sky',
          element: 'Aero-Dynamic Storm & Clarity',
          motto: 'Wisdom, Precision & Infallible Focus',
          battleCry: 'SAPPHIRE SOARS! WISDOM STRIKES TRUE! ⚡',
          icon: '🦅',
          description:
              'Born in the calm before the thunder, Zephyr rules through sharp intellect, analytical supremacy, and unwavering team precision.',
          primaryColor: HouseColors.sapphire,
          accentColor: Color(0xFF91CAFF),
        );
      case 'emerald':
        return const HouseMascot(
          name: 'Sylva the Titan Wolf',
          title: 'Guardian of the Verdant Forest',
          element: 'Primal Earth & Enduring Roots',
          motto: 'Perseverance, Growth & Indomitable Might',
          battleCry: 'EMERALD STANDS! PACK RUNS ETERNAL! 🐺',
          icon: '🐺',
          description:
              'Rooted in unshakeable resilience and relentless work ethic. Sylva defends the pack with loyal brotherhood and unstoppable momentum.',
          primaryColor: HouseColors.emerald,
          accentColor: Color(0xFF95DE64),
        );
      case 'topaz':
      default:
        return const HouseMascot(
          name: 'Solis the Golden Chimera',
          title: 'Bringer of Dawn & Sovereign Sun',
          element: 'Pure Solar Luminescence',
          motto: 'Radiance, Loyalty & Sovereign Glory',
          battleCry: 'TOPAZ SHINES! GOLDEN SUN ASCENDS! ☀️',
          icon: '🦁',
          description:
              'Radiating warmth, sportsmanship, and electric brilliance. Solis illuminates every corridor with relentless optimism and supreme leadership.',
          primaryColor: HouseColors.topaz,
          accentColor: Color(0xFFFFE58F),
        );
    }
  }
}

/// Particle model for Spirit Reactor tap shockwaves
class EnergyParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  Color color;

  EnergyParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.color,
  });

  void update() {
    x += vx;
    y += vy;
    opacity -= 0.035;
    if (opacity < 0) opacity = 0;
  }
}

/// ASB House Warroom & Clash Arena Screen
class HouseArenaScreen extends StatefulWidget {
  final String userHouse;
  final String scholarNo;
  final String userName;
  final bool isAdmin;
  final int initialNav;

  const HouseArenaScreen({
    super.key,
    required this.userHouse,
    required this.scholarNo,
    required this.userName,
    this.isAdmin = false,
    this.initialNav = 0,
  });

  @override
  State<HouseArenaScreen> createState() => _HouseArenaScreenState();
}

class _HouseArenaScreenState extends State<HouseArenaScreen>
    with TickerProviderStateMixin {
  int _activeNav = 0; // 0: Spirit Reactor, 1: Brain Blitz, 2: Cup Oracle, 3: Badges, 4: Mascot Lore

  // Reactor Animations & State
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late AnimationController _particleTicker;
  final List<EnergyParticle> _particles = [];
  final ValueNotifier<int> _particleNotifier = ValueNotifier<int>(0);
  final math.Random _rng = math.Random();

  int _localTapCount = 0;
  int _comboMultiplier = 1;
  Timer? _comboResetTimer;
  DateTime _lastTapTime = DateTime.now();
  bool _showChantSynthesizer = false;
  double _unflushedSpiritDelta = 0.0;

  // Simulated live spirit gauge across 4 houses
  double _rubySpirit = 420;
  double _sapphireSpirit = 390;
  double _emeraldSpirit = 360;
  double _topazSpirit = 410;


  // Daily Brain Blitz Quiz State
  int _blitzQuestionIndex = 0;
  int _blitzScore = 0;
  int _blitzComboStreak = 0;
  bool _blitzActive = false;
  bool _blitzFinished = false;
  bool _blitzIsDemo = false;
  int? _blitzSelectedOption;
  bool? _blitzAnswerCorrect;
  Timer? _blitzTimer;
  Timer? _advanceTimer;
  int _blitzSecondsLeft = 15;
  bool _showConfetti = false;
  StreamSubscription? _spiritSubscription;

  // Cup Oracle Prediction Sliders
  double _sportsSim = 150;
  double _academicSim = 120;
  double _spiritSim = 80;

  final List<Map<String, dynamic>> _quizBank = [
    {
      'question': 'What core virtue is symbolized by the Ruby House motto?',
      'options': ['Courage & Fire', 'Speed & Silence', 'Frost & Ice', 'Cunning & Shadows'],
      'correct': 0,
      'fact': 'Ruby represents courage, determination, and unyielding school pride!',
    },
    {
      'question': 'Which house holds the mascot of the Sky Tempest Gryphon?',
      'options': ['Ruby', 'Topaz', 'Emerald', 'Sapphire'],
      'correct': 3,
      'fact': 'Zephyr the Tempest Gryphon is the revered mascot of Sapphire House.',
    },
    {
      'question': 'In the ASB House System, how are Demerits officially reconciled?',
      'options': [
        'By earning Merits & Service Hours',
        'They are deleted weekly',
        'Only by paying cash',
        'By switching houses'
      ],
      'correct': 0,
      'fact': 'Active campus participation and commendable conduct neutralize demerits.',
    },
    {
      'question': 'What is the sovereign celestial gem of the golden lion?',
      'options': ['Diamond', 'Topaz', 'Amethyst', 'Obsidian'],
      'correct': 1,
      'fact': 'Topaz embodies the radiance and sovereign spirit of the Golden Chimera.',
    },
    {
      'question': 'What is the fastest way to surge your House Leaderboard standing?',
      'options': [
        'Submitting verified inter-school certificates',
        'Waiting until end of year',
        'Leaving school early',
        'Unapproved claims'
      ],
      'correct': 0,
      'fact': 'Verified claims award up to 50 House Points instantly upon council approval!',
    },
  ];

  @override
  void initState() {
    super.initState();
    _activeNav = widget.initialNav;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _particleTicker = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateParticles);

    _listenToLiveSpirit();
  }

  void _listenToLiveSpirit() {
    try {
      _spiritSubscription?.cancel();
      _spiritSubscription = FirebaseFirestore.instance
          .collection('system_config')
          .doc('house_spirit_reactor')
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          final d = doc.data();
          if (d != null) {
            setState(() {
              _rubySpirit = (d['ruby'] as num?)?.toDouble() ?? _rubySpirit;
              _sapphireSpirit = (d['sapphire'] as num?)?.toDouble() ?? _sapphireSpirit;
              _emeraldSpirit = (d['emerald'] as num?)?.toDouble() ?? _emeraldSpirit;
              _topazSpirit = (d['topaz'] as num?)?.toDouble() ?? _topazSpirit;
            });
          }
        }
      });
    } catch (_) {}
  }

  void _updateParticles() {
    if (_particles.isEmpty) {
      if (_particleTicker.isAnimating) {
        _particleTicker.stop();
      }
      return;
    }
    for (final p in _particles) {
      p.update();
    }
    _particles.removeWhere((p) => p.opacity <= 0.01);
    _particleNotifier.value++;
    if (_particles.isEmpty && _particleTicker.isAnimating) {
      _particleTicker.stop();
    }
  }

  @override
  void dispose() {
    _spiritSubscription?.cancel();
    _pulseController.dispose();
    _particleTicker.dispose();
    _particleNotifier.dispose();
    _comboResetTimer?.cancel();
    _blitzTimer?.cancel();
    _advanceTimer?.cancel();
    super.dispose();
  }

  // --- Reactor Tap Logic ---
  void _handleReactorTap(TapDownDetails details, Size boxSize) {
    HapticFeedback.lightImpact();
    final houseKey = widget.userHouse.toLowerCase();
    final houseColor = HouseColors.getHouseColor(widget.userHouse);

    // Spawn 10 dynamic shockwave particles from tap position
    final localPos = details.localPosition;
    for (int i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = _rng.nextDouble() * 4.5 + 2.0;
      _particles.add(
        EnergyParticle(
          x: localPos.dx,
          y: localPos.dy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          size: _rng.nextDouble() * 5 + 3,
          opacity: 1.0,
          color: i % 2 == 0 ? houseColor : Colors.white,
        ),
      );
    }
    _particleNotifier.value++;
    if (!_particleTicker.isAnimating) {
      _particleTicker.repeat();
    }

    // Combo streak tracking
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 800) {
      final prevMultiplier = _comboMultiplier;
      _comboMultiplier = math.min(10, _comboMultiplier + 1);
      if (_comboMultiplier >= 5 && prevMultiplier < 5) {
        _triggerOverdriveRallyChant();
      }
    } else {
      _comboMultiplier = 1;
    }
    _lastTapTime = now;

    _comboResetTimer?.cancel();
    _comboResetTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _comboMultiplier = 1);
    });

    final tapGain = _comboMultiplier * 1.5;
    _unflushedSpiritDelta += tapGain;

    setState(() {
      _localTapCount++;
      if (houseKey == 'ruby') _rubySpirit += tapGain;
      if (houseKey == 'sapphire') _sapphireSpirit += tapGain;
      if (houseKey == 'emerald') _emeraldSpirit += tapGain;
      if (houseKey == 'topaz') _topazSpirit += tapGain;
    });

    // Debounced persist to Firestore: atomic FieldValue.increment for caller's house only
    if (_localTapCount % 5 == 0 && _unflushedSpiritDelta > 0) {
      final deltaToCommit = _unflushedSpiritDelta;
      _unflushedSpiritDelta = 0.0;
      final validHouses = const ['ruby', 'sapphire', 'emerald', 'topaz'];
      if (validHouses.contains(houseKey)) {
        try {
          final payload = <String, dynamic>{
            houseKey: FieldValue.increment(deltaToCommit),
            'last_updated': FieldValue.serverTimestamp(),
          };
          if (widget.scholarNo.trim().isNotEmpty) {
            payload['last_contributor'] = widget.scholarNo.trim();
          }
          FirebaseFirestore.instance
              .collection('system_config')
              .doc('house_spirit_reactor')
              .set(payload, SetOptions(merge: true)).catchError((e) {
            debugPrint('Spirit reactor commit rejected or offline: $e');
          });
        } catch (_) {}
      }
    }
  }

  void _triggerOverdriveRallyChant() {
    HapticFeedback.heavyImpact();
    final chantData = HouseChantData.forHouse(widget.userHouse);
    final warCry = chantData.warCry;

    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        '5x Overdrive achieved! House battle cry: $warCry',
        TextDirection.ltr,
      );
    } catch (_) {}

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          liveRegion: true,
          excludeSemantics: true,
          label: 'OVERDRIVE RALLY: $warCry',
          child: Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OVERDRIVE! $warCry',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: HouseColors.getHouseColor(widget.userHouse),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Daily Brain Blitz Logic ---
  void _startBrainBlitz() {
    if (_quizBank.isEmpty) return;
    setState(() {
      _blitzActive = true;
      _blitzFinished = false;
      _blitzQuestionIndex = 0;
      _blitzScore = 0;
      _blitzComboStreak = 0;
      _blitzSelectedOption = null;
      _blitzAnswerCorrect = null;
      _blitzSecondsLeft = 15;
    });
    _startBlitzCountdown();
  }

  void _startBlitzCountdown() {
    _blitzTimer?.cancel();
    _blitzTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_blitzSecondsLeft > 0) {
        setState(() => _blitzSecondsLeft--);
      } else {
        _blitzTimer?.cancel();
        _handleBlitzOptionSelected(-1); // Timeout
      }
    });
  }

  void _handleBlitzOptionSelected(int optionIndex) {
    if (_blitzAnswerCorrect != null) return; // Prevent double taps
    _blitzTimer?.cancel();

    if (_quizBank.isEmpty) return;
    if (_blitzQuestionIndex >= _quizBank.length) return;

    final currentQ = _quizBank[_blitzQuestionIndex];
    final isCorrect = optionIndex == currentQ['correct'];

    HapticFeedback.mediumImpact();
    setState(() {
      _blitzSelectedOption = optionIndex;
      _blitzAnswerCorrect = isCorrect;
      if (isCorrect) {
        _blitzComboStreak++;
        final multiplier = (_blitzComboStreak >= 4)
            ? 2.0
            : (_blitzComboStreak >= 3
                ? 1.5
                : (_blitzComboStreak == 2 ? 1.25 : 1.0));
        _blitzScore += (20 * multiplier).round();
      } else {
        _blitzComboStreak = 0;
      }
    });

    // Advance to next after 1.4s delay
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 1400), () async {
      if (!mounted) return;
      if (!_blitzActive || _activeNav != 1) return;

      if (_blitzQuestionIndex + 1 < _quizBank.length) {
        setState(() {
          _blitzQuestionIndex++;
          _blitzSelectedOption = null;
          _blitzAnswerCorrect = null;
          _blitzSecondsLeft = 15;
        });
        _startBlitzCountdown();
      } else {
        // Finished Quiz!
        final effectiveScore = _blitzScore.clamp(0, 50);
        setState(() {
          _blitzFinished = true;
          _blitzActive = false;
        });

        if (effectiveScore > 0) {
          final sNo = widget.scholarNo.isNotEmpty && widget.scholarNo != '---'
              ? widget.scholarNo
              : (AuthService.getCachedScholarNo() ?? 'guest');
          final token = GamificationSecurityService.generateScoreProofToken(
            scholarNo: sNo,
            activityId: 'blitz_quiz',
            points: effectiveScore,
          );
          AuthService().awardVerifiedGamificationPoints(
            scholarNo: sNo,
            activityId: 'blitz_quiz',
            house: widget.userHouse,
            token: token,
            studentName: widget.userName,
          ).then((res) {
            if (mounted && res.success) {
              setState(() {
                _blitzIsDemo = res.isDemo;
                _showConfetti = _blitzScore >= 40;
              });
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mascot = HouseMascot.forHouse(widget.userHouse);
    final houseColor = HouseColors.getHouseColor(widget.userHouse);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConfettiOverlay(
      show: _showConfetti,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF3F6FA),
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mascot.icon,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'ASB House Warroom',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: houseColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: houseColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.userHouse.toUpperCase()} ARENA',
                    style: TextStyle(
                      color: houseColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildArenaNavPills(houseColor),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: _buildCurrentTabBody(mascot, houseColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArenaNavPills(Color houseColor) {
    final tabs = [
      {'icon': Icons.bolt_rounded, 'label': 'Spirit Reactor'},
      {'icon': Icons.psychology_rounded, 'label': 'Brain Blitz'},
      {'icon': Icons.auto_graph_rounded, 'label': 'Cup Oracle'},
      {'icon': Icons.workspace_premium_rounded, 'label': 'Titan Vault'},
      {'icon': Icons.view_in_ar_rounded, 'label': '3D Mascot'},
    ];

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (int index = 0; index < tabs.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final isSel = _activeNav == index;
                  final tabLabel = tabs[index]['label'] as String;
                  return Semantics(
                    button: true,
                    selected: isSel,
                    excludeSemantics: true,
                    label: '$tabLabel Arena Tab',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (_activeNav == 1 && index != 1) {
                            _blitzTimer?.cancel();
                            _advanceTimer?.cancel();
                          }
                          setState(() => _activeNav = index);
                          try {
                            SemanticsService.sendAnnouncement(
                              View.of(context),
                              '$tabLabel Arena Tab selected',
                              TextDirection.ltr,
                            );
                          } catch (_) {}
                        },
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? houseColor : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSel ? houseColor : Colors.white.withValues(alpha: 0.12),
                              ),
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: houseColor.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tabs[index]['icon'] as IconData,
                                  size: 16,
                                  color: isSel ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tabLabel,
                                  style: TextStyle(
                                    color: isSel ? Colors.white : Colors.white70,
                                    fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTabBody(HouseMascot mascot, Color houseColor) {
    switch (_activeNav) {
      case 0:
        return _buildSpiritReactorTab(mascot, houseColor);
      case 1:
        return _buildBrainBlitzTab(houseColor);
      case 2:
        return _buildCupOracleTab(houseColor);
      case 3:
        return _buildHolographicBadgesTab(houseColor);
      case 4:
      default:
        return _buildMascotLoreTab(mascot, houseColor);
    }
  }

  // ===========================================================================
  // TAB 1: SPIRIT REACTOR (Interactive Energy Tap Clash)
  // ===========================================================================
  Widget _buildSpiritReactorTab(HouseMascot mascot, Color houseColor) {
    final totalSpirit = _rubySpirit + _sapphireSpirit + _emeraldSpirit + _topazSpirit;
    final maxSpirit = totalSpirit > 0 ? totalSpirit : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          // Live Spirit Multi-Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131A29),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.public_rounded, color: Colors.cyanAccent, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Live Inter-House Spirit Grid',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 10),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Segmented Multi-Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (_rubySpirit / maxSpirit * 1000).toInt().clamp(1, 1000),
                          child: Container(color: HouseColors.ruby),
                        ),
                        Expanded(
                          flex: (_sapphireSpirit / maxSpirit * 1000).toInt().clamp(1, 1000),
                          child: Container(color: HouseColors.sapphire),
                        ),
                        Expanded(
                          flex: (_emeraldSpirit / maxSpirit * 1000).toInt().clamp(1, 1000),
                          child: Container(color: HouseColors.emerald),
                        ),
                        Expanded(
                          flex: (_topazSpirit / maxSpirit * 1000).toInt().clamp(1, 1000),
                          child: Container(color: HouseColors.topaz),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Legend
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _buildSpiritLegendItem('Ruby', _rubySpirit, HouseColors.ruby),
                    _buildSpiritLegendItem('Sapphire', _sapphireSpirit, HouseColors.sapphire),
                    _buildSpiritLegendItem('Emerald', _emeraldSpirit, HouseColors.emerald),
                    _buildSpiritLegendItem('Topaz', _topazSpirit, HouseColors.topaz),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Glowing Interactive Reactor Core
          Text(
            'TAP THE CORE TO ENERGIZE ${widget.userHouse.toUpperCase()}!',
            style: TextStyle(
              color: houseColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Continuous rapid tapping unlocks Overdrive Multipliers (Up to 10x!)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),

          // Particle & Reactor Canvas Box
          GestureDetector(
            onTapDown: (details) => _handleReactorTap(details, const Size(260, 260)),
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow Ring
                  AnimatedBuilder(
                    animation: _pulseScale,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseScale.value,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                houseColor.withValues(alpha: 0.45),
                                houseColor.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Core Disc
                  Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          houseColor.withValues(alpha: 0.85),
                          houseColor.withValues(alpha: 0.45),
                          const Color(0xFF0A0F1E),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: houseColor.withValues(alpha: 0.55),
                          blurRadius: 36,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          mascot.icon,
                          style: const TextStyle(fontSize: 48),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _comboMultiplier > 1
                              ? '${_comboMultiplier}x OVERDRIVE'
                              : 'TAP ME!',
                          style: TextStyle(
                            color: _comboMultiplier > 1 ? Colors.amberAccent : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Custom Particle Painter for tap sparks isolated via AnimatedBuilder & RepaintBoundary
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _particleNotifier,
                          builder: (context, _) {
                            return CustomPaint(
                              size: const Size(280, 280),
                              painter: ParticlePainter(particles: _particles),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tap Metrics Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.offline_bolt_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Your Session Surge: +${_localTapCount * _comboMultiplier} Energy Taps',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Rally Battle Chant Synthesizer Section
          _buildRallySynthesizerSection(houseColor),
        ],
      ),
    );
  }

  Widget _buildRallySynthesizerSection(Color houseColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: houseColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            excludeSemantics: true,
            label: _showChantSynthesizer ? 'Hide Battle Chant Deck' : 'Open Battle Chant Deck',
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                setState(() => _showChantSynthesizer = !_showChantSynthesizer);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: houseColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.graphic_eq_rounded, color: houseColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.userHouse.toUpperCase()} RALLY SYNTHESIZER',
                            style: TextStyle(
                              color: houseColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Institutional Battle Chants & Accessible Audio',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _showChantSynthesizer ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showChantSynthesizer) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: BattleChantSynthesizer(
                userHouse: widget.userHouse,
                onClose: () => setState(() => _showChantSynthesizer = false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpiritLegendItem(String name, double val, Color c) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$name: ${val.toInt()}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: DAILY BRAIN BLITZ (House Trivia Speed Showdown)
  // ===========================================================================
  Widget _buildBrainBlitzTab(Color houseColor) {
    if (!_blitzActive && !_blitzFinished) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: houseColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: houseColor.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(Icons.psychology_rounded, size: 64, color: houseColor),
            ),
            const SizedBox(height: 20),
            const Text(
              'Daily Scholastic Brain Blitz',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Challenge your intellect in a 5-question speed trial. Earn direct House Points and Merits for ${widget.userHouse.toUpperCase()}!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: const Text(
                'ENTER SHOWDOWN (15s PER QUESTION)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: houseColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 6,
              ),
              onPressed: _startBrainBlitz,
            ),
          ],
        ),
      );
    }

    if (_blitzFinished) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 64, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            const Text(
              'Blitz Completed!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $_blitzScore / 100 Points for ${widget.userHouse.toUpperCase()}!',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            if (_blitzIsDemo) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Demo Mode: Points recorded in local standings',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Play Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: houseColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _startBrainBlitz,
            ),
          ],
        ),
      );
    }

    // Active Quiz View
    final q = _quizBank[_blitzQuestionIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Progress & Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Question ${_blitzQuestionIndex + 1} of ${_quizBank.length}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                  if (_blitzComboStreak > 1) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.deepOrange, Colors.amber],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepOrange.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '🔥 ${_blitzComboStreak}x STREAK',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _blitzSecondsLeft <= 5 ? Colors.redAccent : Colors.cyanAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      '${_blitzSecondsLeft}s',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Countdown Linear Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _blitzSecondsLeft / 15.0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                _blitzSecondsLeft <= 5 ? Colors.redAccent : houseColor,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 20),

          // Question Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141C2E),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              q['question'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Options
          ...List.generate((q['options'] as List).length, (idx) {
            final opt = (q['options'] as List)[idx] as String;
            final isChosen = _blitzSelectedOption == idx;
            final isCorrectOpt = idx == q['correct'];

            Color btnColor = const Color(0xFF182338);
            BorderSide border = BorderSide(color: Colors.white.withValues(alpha: 0.12));

            if (_blitzAnswerCorrect != null) {
              if (isCorrectOpt) {
                btnColor = Colors.green.withValues(alpha: 0.3);
                border = const BorderSide(color: Colors.greenAccent, width: 2);
              } else if (isChosen && !_blitzAnswerCorrect!) {
                btnColor = Colors.red.withValues(alpha: 0.3);
                border = const BorderSide(color: Colors.redAccent, width: 2);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _blitzAnswerCorrect == null ? () => _handleBlitzOptionSelected(idx) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: btnColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.fromBorderSide(border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          String.fromCharCode(65 + idx),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          opt,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: CUP ORACLE (Predictive Simulator)
  // ===========================================================================
  Widget _buildCupOracleTab(Color houseColor) {
    // Predictive formula simulation
    final simHousePoints = (_sportsSim * 1.5) + (_academicSim * 1.8) + (_spiritSim * 1.0);
    final benchmarkRival = 550.0;
    final winProb = ((simHousePoints / (simHousePoints + benchmarkRival)) * 100).clamp(5, 95);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  houseColor.withValues(alpha: 0.3),
                  const Color(0xFF101726),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: houseColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: houseColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'The House Cup Oracle Engine',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Simulate upcoming sports, decathlons, and merit surges to project ${widget.userHouse.toUpperCase()}\'s championship probability.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Probability Radial Card
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: CircularProgressIndicator(
                        value: winProb / 100.0,
                        strokeWidth: 12,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                          winProb > 60 ? Colors.greenAccent : (winProb > 40 ? Colors.amber : Colors.redAccent),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${winProb.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                        const Text(
                          'WIN PROBABILITY',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  winProb > 60 ? '🏆 Favorited for Annual Cup' : '⚡ Contender Surge Needed',
                  style: TextStyle(
                    color: winProb > 60 ? Colors.greenAccent : Colors.amberAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Interactive Simulation Sliders
          _buildSimSlider(
            'Upcoming Sports Day Points',
            _sportsSim,
            0,
            300,
            Colors.redAccent,
            (v) => setState(() => _sportsSim = v),
          ),
          _buildSimSlider(
            'Academic Merits & Decathlon Surge',
            _academicSim,
            0,
            300,
            Colors.blueAccent,
            (v) => setState(() => _academicSim = v),
          ),
          _buildSimSlider(
            'Campus Spirit & Attendance Score',
            _spiritSim,
            0,
            150,
            Colors.greenAccent,
            (v) => setState(() => _spiritSim = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSimSlider(
    String label,
    double value,
    double min,
    double max,
    Color c,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121927),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                Text(
                  '+${value.toInt()} Pts',
                  style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: c,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolographicBadgesTab(Color houseColor) {
    return AppleFitnessBadgesVault(
      userHouse: widget.userHouse,
      userName: widget.userName,
      scholarNo: widget.scholarNo,
      isAdmin: widget.isAdmin,
      localTapCount: _localTapCount,
      blitzScore: _blitzScore,
    );
  }

  // ===========================================================================
  // TAB 5: MASCOT LORE & 3D MOVABLE STAGE
  // ===========================================================================
  Widget _buildMascotLoreTab(HouseMascot mascot, Color houseColor) {
    return Mascot3DStage(
      userHouse: widget.userHouse,
      userName: widget.userName,
      scholarNo: widget.scholarNo,
    );
  }
}

/// Custom Painter to render energy spark shockwaves
class ParticlePainter extends CustomPainter {
  final List<EnergyParticle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}
