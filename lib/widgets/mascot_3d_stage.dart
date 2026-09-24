import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Rich mythological and athletic data for the 4 Great House Mascots
class MascotLoreData {
  final String houseId;
  final String name;
  final String title;
  final String beastSpecies;
  final String element;
  final String motto;
  final String battleCry;
  final String primaryEmoji;
  final IconData beastIcon;
  final String description;
  final String legendStory;
  final String sacredRelicTitle;
  final String sacredRelicDesc;
  final IconData sacredRelicIcon;
  final Color primaryColor;
  final Color accentColor;
  final Color glowColor;
  final Map<String, double> powerStats; // 0.0 to 1.0
  final List<String> virtues;
  final String sacredRite;

  const MascotLoreData({
    required this.houseId,
    required this.name,
    required this.title,
    required this.beastSpecies,
    required this.element,
    required this.motto,
    required this.battleCry,
    required this.primaryEmoji,
    required this.beastIcon,
    required this.description,
    required this.legendStory,
    required this.sacredRelicTitle,
    required this.sacredRelicDesc,
    required this.sacredRelicIcon,
    required this.primaryColor,
    required this.accentColor,
    required this.glowColor,
    required this.powerStats,
    required this.virtues,
    required this.sacredRite,
  });

  static List<MascotLoreData> get allMascots => [
        // 1. RUBY: Ignis
        const MascotLoreData(
          houseId: 'ruby',
          name: 'Ignis the Crimson Dragon',
          title: 'Sovereign of the Blazing Hearth',
          beastSpecies: 'Pyre-Forged Greatwyrm',
          element: 'Solar Flare & Molten Fury',
          motto: 'Courage, Honor & Unyielding Fire',
          battleCry: 'RUBY ROARS! IN FIRE WE CONQUER! 🔥',
          primaryEmoji: '🐉',
          beastIcon: Icons.local_fire_department_rounded,
          description:
              'Forged in the heart of courage and relentless passion. Ignis embodies the fearless drive of Ruby House warriors who conquer every summit and never back down.',
          legendStory:
              'According to ASB founding chronicles, when the first collegiate championship was held in the northern mountains, a sudden blizzard threatened to extinguish the ceremony torch. Ignis descended from the volcanic peaks, breathing an eternal crimson ember into the hearth that burns to this day in Ruby Tower.',
          sacredRelicTitle: 'The Cinder Core Sceptre',
          sacredRelicDesc:
              'Carved from volcanic obsidian and bound with dragon-tempered red gold. Bestows +25% spirit surge during inter-house athletics and exam sprints.',
          sacredRelicIcon: Icons.fireplace_rounded,
          primaryColor: HouseColors.ruby,
          accentColor: Color(0xFFFF7875),
          glowColor: Color(0xFFFF2A4B),
          powerStats: {
            'Elemental Power': 0.98,
            'Physical Might': 0.95,
            'Aerial Speed': 0.88,
            'Battle Wisdom': 0.84,
            'House Leadership': 0.96,
          },
          virtues: [
            'Fearless Fortitude',
            'Relentless Passion',
            'Honor in Victory',
          ],
          sacredRite:
              'The Rite of the First Ember: Conferred upon scholars who show unmatched bravery by championing their team when the odds seem insurmountable.',
        ),

        // 2. SAPPHIRE: Zephyr
        const MascotLoreData(
          houseId: 'sapphire',
          name: 'Zephyr the Tempest Gryphon',
          title: 'Master of the Endless Azure Sky',
          beastSpecies: 'Celestial Storm Gryphon',
          element: 'Aero-Dynamic Gale & High Voltage',
          motto: 'Wisdom, Precision & Infallible Focus',
          battleCry: 'SAPPHIRE SOARS! WISDOM STRIKES TRUE! ⚡',
          primaryEmoji: '🦅',
          beastIcon: Icons.air_rounded,
          description:
              'Born in the calm before the thunder, Zephyr rules through razor-sharp intellect, analytical supremacy, and unwavering team precision.',
          legendStory:
              'Legend tells of the Great Debate of 1991, where the four houses contested the fundamental mathematics of the campus observatory. When all calculations stalled, Zephyr circled the dome in razor-sharp spirals, guiding the scholars to decipher the celestial alignments with breathtaking elegance.',
          sacredRelicTitle: 'The Aegis of Tempest Skies',
          sacredRelicDesc:
              'Forged from sky-iron and inlaid with star lapis lazuli. Vibrates with high-frequency cognitive clarity during STEM bowls and academic exhibitions.',
          sacredRelicIcon: Icons.electric_bolt_rounded,
          primaryColor: HouseColors.sapphire,
          accentColor: Color(0xFF69C0FF),
          glowColor: Color(0xFF2979FF),
          powerStats: {
            'Elemental Power': 0.88,
            'Physical Might': 0.84,
            'Aerial Speed': 0.99,
            'Battle Wisdom': 0.99,
            'House Leadership': 0.92,
          },
          virtues: [
            'Razor-Sharp Intellect',
            'Analytical Mastery',
            'Forensic Precision',
          ],
          sacredRite:
              'The Rite of the Zenith Flight: Conferred upon scholars who discover breakthrough solutions, excel in debate, and elevate house intellectual prestige.',
        ),

        // 3. EMERALD: Sylva
        const MascotLoreData(
          houseId: 'emerald',
          name: 'Sylva the Titan Wolf',
          title: 'Guardian of the Verdant Forest',
          beastSpecies: 'Ancient Alpha Direwolf',
          element: 'Primal Earth & Enduring Roots',
          motto: 'Perseverance, Growth & Indomitable Might',
          battleCry: 'EMERALD STANDS! PACK RUNS ETERNAL! 🐺',
          primaryEmoji: '🐺',
          beastIcon: Icons.forest_rounded,
          description:
              'Rooted in unshakeable resilience and relentless work ethic. Sylva defends the pack with loyal brotherhood and unstoppable momentum.',
          legendStory:
              'When the campus foundation expanded through the ancient woodlands, heavy timber and stone seemed impassable. Sylva led the pack to clear the roads shoulder-to-shoulder, proving that unified endurance and collective grit will outlast any mountain.',
          sacredRelicTitle: 'The Fang of the Ancient Oak',
          sacredRelicDesc:
              'Petrified elderwood harvested from the founding groves and ringed in sterling silver. Fortifies endurance, teamwork synergy, and attendance integrity.',
          sacredRelicIcon: Icons.eco_rounded,
          primaryColor: HouseColors.emerald,
          accentColor: Color(0xFF95DE64),
          glowColor: Color(0xFF00E676),
          powerStats: {
            'Elemental Power': 0.92,
            'Physical Might': 0.97,
            'Aerial Speed': 0.90,
            'Battle Wisdom': 0.89,
            'House Leadership': 0.97,
          },
          virtues: [
            'Unbreakable Loyalty',
            'Steadfast Resilience',
            'Relentless Growth',
          ],
          sacredRite:
              'The Rite of the Pack Vigil: Conferred upon scholars who sacrifice individual limelight to bolster their fellow classmates and keep house spirit unbreakable.',
        ),

        // 4. TOPAZ: Solis
        const MascotLoreData(
          houseId: 'topaz',
          name: 'Solis the Golden Chimera',
          title: 'Bringer of Dawn & Sovereign Sun',
          beastSpecies: 'Solar Lion-Dragon Chimera',
          element: 'Pure Solar Luminescence',
          motto: 'Radiance, Loyalty & Sovereign Glory',
          battleCry: 'TOPAZ SHINES! GOLDEN SUN ASCENDS! ☀️',
          primaryEmoji: '🦁',
          beastIcon: Icons.wb_sunny_rounded,
          description:
              'Radiating warmth, sportsmanship, and electric brilliance. Solis illuminates every corridor with relentless optimism and supreme leadership.',
          legendStory:
              'During the darkest winter tournament in campus history, morale dwindled as clouds covered the stadium for three weeks. Solis roared from the quadrangle clocktower, summoning rays of golden sunlight that melted the frost and revitalized thousands of spectators.',
          sacredRelicTitle: 'The Sunforged Crown',
          sacredRelicDesc:
              'Minted from golden solstice meteoric ore. Emits an aura of infectious charisma, sportsmanship, and radiant house pride across every arena match.',
          sacredRelicIcon: Icons.stars_rounded,
          primaryColor: HouseColors.topaz,
          accentColor: Color(0xFFFFD666),
          glowColor: Color(0xFFFFC107),
          powerStats: {
            'Elemental Power': 0.95,
            'Physical Might': 0.91,
            'Aerial Speed': 0.93,
            'Battle Wisdom': 0.91,
            'House Leadership': 0.98,
          },
          virtues: [
            'Radiant Sportsmanship',
            'Supreme Optimism',
            'Charismatic Leadership',
          ],
          sacredRite:
              'The Rite of the Golden Dawn: Conferred upon scholars who uplift others, display exceptional sportsmanship on the pitch, and lead with warmth and joy.',
        ),
      ];

  static MascotLoreData forHouse(String house) {
    final lower = house.toLowerCase();
    return allMascots.firstWhere(
      (m) => m.houseId == lower,
      orElse: () => allMascots.first,
    );
  }
}

/// Particle model for elemental aura surrounding the 3D mascot
class _MascotParticle {
  double x;
  double y;
  double z;
  double vx;
  double vy;
  double size;
  double opacity;
  double life;
  double maxLife;

  _MascotParticle({
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.life,
    required this.maxLife,
  });
}

/// Interactive 3D Movable Mascot Stage featuring 360-degree rotational physics,
/// multi-layer stereoscopic depth, kinetic roar shockwaves, and the Ancient Lore Codex.
class Mascot3DStage extends StatefulWidget {
  final String userHouse;
  final String userName;
  final String scholarNo;

  const Mascot3DStage({
    super.key,
    required this.userHouse,
    required this.userName,
    required this.scholarNo,
  });

  @override
  State<Mascot3DStage> createState() => _Mascot3DStageState();
}

class _Mascot3DStageState extends State<Mascot3DStage>
    with TickerProviderStateMixin {
  late String _activeHouse;
  late MascotLoreData _currentMascot;

  // 3D Rotational angles
  double _rotX = 0.0;
  double _rotY = 0.0;
  bool _isAutoRotating = false;

  // Animation Controllers
  late final AnimationController _idleFloatController;
  late final AnimationController _altarSpinController;
  late final AnimationController _turntableController;
  late final AnimationController _roarController;
  late final AnimationController _springBackController;
  late Animation<double> _springAnimX;
  late Animation<double> _springAnimY;

  // Particle System
  final List<_MascotParticle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _activeHouse = widget.userHouse.toLowerCase();
    _currentMascot = MascotLoreData.forHouse(_activeHouse);

    // 1. Continuous Idle Floating / Breathing Bob
    _idleFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    // 2. Altar runic pedestal rotation (12s smooth 360 spin)
    _altarSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    // 3. Turntable 360 Auto-Rotation Controller
    _turntableController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..addListener(() {
        if (_isAutoRotating) {
          setState(() {
            _rotY = _turntableController.value * math.pi * 2;
          });
        }
      });

    // 4. Kinetic Roar Shockwave Controller
    _roarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    // 5. Spring-back physics when releasing drag
    _springBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        setState(() {
          _rotX = _springAnimX.value;
          _rotY = _springAnimY.value;
        });
      });
    _springAnimX = const AlwaysStoppedAnimation(0.0);
    _springAnimY = const AlwaysStoppedAnimation(0.0);

    // Initialize elemental particles
    _initParticles();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < 28; i++) {
      _particles.add(
        _MascotParticle(
          x: (_rng.nextDouble() - 0.5) * 220,
          y: (_rng.nextDouble() - 0.5) * 220,
          z: (_rng.nextDouble() - 0.5) * 60,
          vx: (_rng.nextDouble() - 0.5) * 0.8,
          vy: -(_rng.nextDouble() * 0.9 + 0.3),
          size: _rng.nextDouble() * 4.0 + 2.0,
          opacity: _rng.nextDouble() * 0.6 + 0.2,
          life: _rng.nextDouble() * 60,
          maxLife: 60 + _rng.nextDouble() * 40,
        ),
      );
    }
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.y += p.vy;
      p.x += p.vx;
      p.life += 1.0;
      if (p.life >= p.maxLife || p.y < -130) {
        p.x = (_rng.nextDouble() - 0.5) * 200;
        p.y = 80 + _rng.nextDouble() * 40;
        p.z = (_rng.nextDouble() - 0.5) * 60;
        p.life = 0;
        p.opacity = _rng.nextDouble() * 0.6 + 0.2;
      }
    }
  }

  @override
  void dispose() {
    _idleFloatController.dispose();
    _altarSpinController.dispose();
    _turntableController.dispose();
    _roarController.dispose();
    _springBackController.dispose();
    super.dispose();
  }

  void _switchMascot(String house) {
    if (_activeHouse == house) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeHouse = house;
      _currentMascot = MascotLoreData.forHouse(house);
      _rotX = 0.0;
      _rotY = 0.0;
      _isAutoRotating = false;
    });
    _turntableController.stop();
    _initParticles();
  }

  void _triggerRoar() {
    HapticFeedback.heavyImpact();
    _roarController.forward(from: 0.0);
    // Burst particles outward
    for (final p in _particles) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = _rng.nextDouble() * 4.0 + 3.0;
      p.vx = math.cos(angle) * speed;
      p.vy = math.sin(angle) * speed;
      p.opacity = 1.0;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(_currentMascot.primaryEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _currentMascot.battleCry,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: _currentMascot.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleAutoRotate() {
    HapticFeedback.lightImpact();
    setState(() {
      _isAutoRotating = !_isAutoRotating;
      if (_isAutoRotating) {
        _turntableController.repeat();
      } else {
        _turntableController.stop();
        _springBackToNeutral();
      }
    });
  }

  void _springBackToNeutral() {
    _springAnimX = Tween<double>(begin: _rotX, end: 0.0).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.easeOutBack),
    );
    _springAnimY = Tween<double>(begin: _rotY, end: 0.0).animate(
      CurvedAnimation(parent: _springBackController, curve: Curves.easeOutBack),
    );
    _springBackController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    _updateParticles();
    final mascot = _currentMascot;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FOUR GREAT HOUSES SELECTOR PILLS
          _buildHouseSelectorBar(),
          const SizedBox(height: 16),

          // 2. 3D MOVABLE MASCOT STAGE (THE SPOTLIGHT CHAMBER)
          _buildInteractive3DStage(mascot),
          const SizedBox(height: 14),

          // 3. 3D CONTROL HUD (Turntable, Reset, Roar)
          _build3DControlHud(mascot),
          const SizedBox(height: 20),

          // 4. MASCOT IDENTITY & NOBLE BEAST SPECIES
          _buildMascotHeaderCard(mascot),
          const SizedBox(height: 18),

          // 5. COMBAT & POWER ATTRIBUTES RADAR / BARS
          _buildMascotPowerStats(mascot),
          const SizedBox(height: 18),

          // 6. SACRED RELIC OF THE HOUSE ARCHIVES
          _buildSacredRelicCard(mascot),
          const SizedBox(height: 18),

          // 7. ANCIENT FOUNDING ERA CHRONICLES
          _buildLoreChroniclesCard(mascot),
          const SizedBox(height: 18),

          // 8. HOUSE VIRTUES & THE SACRED RITE
          _buildVirtuesAndRiteCard(mascot),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. HOUSE SELECTOR BAR
  // ===========================================================================
  Widget _buildHouseSelectorBar() {
    final houses = [
      {'id': 'ruby', 'name': 'Ruby', 'emoji': '🐉', 'color': HouseColors.ruby},
      {'id': 'sapphire', 'name': 'Sapphire', 'emoji': '🦅', 'color': HouseColors.sapphire},
      {'id': 'emerald', 'name': 'Emerald', 'emoji': '🐺', 'color': HouseColors.emerald},
      {'id': 'topaz', 'name': 'Topaz', 'emoji': '🦁', 'color': HouseColors.topaz},
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: houses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final h = houses[index];
          final isSel = _activeHouse == h['id'];
          final color = h['color'] as Color;

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _switchMascot(h['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? color : const Color(0xFF101624),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSel ? Colors.white : Colors.white12,
                  width: isSel ? 1.5 : 1.0,
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(h['emoji'] as String, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    h['name'] as String,
                    style: TextStyle(
                      color: isSel ? Colors.white : Colors.white70,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 2. THE 3D MOVABLE MASCOT STAGE (THE INTERACTIVE VIEWPORT)
  // ===========================================================================
  Widget _buildInteractive3DStage(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF060911),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: mascot.glowColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.3,
          colors: [
            mascot.glowColor.withValues(alpha: 0.28),
            const Color(0xFF0C1322),
            const Color(0xFF04060B),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: mascot.glowColor.withValues(alpha: 0.15),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: GestureDetector(
          onPanUpdate: (details) {
            if (_isAutoRotating) {
              _isAutoRotating = false;
              _turntableController.stop();
            }
            _springBackController.stop();
            setState(() {
              _rotY += details.delta.dx * 0.015;
              _rotX -= details.delta.dy * 0.015;
              _rotX = _rotX.clamp(-0.55, 0.55);
              // allow free 360 horizontal rotation
            });
          },
          onPanEnd: (_) {
            if (!_isAutoRotating) {
              _springBackToNeutral();
            }
          },
          onDoubleTap: _triggerRoar,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // A. Swirling Ambient Elemental Particles (Embers/Sparks/Leaves)
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticleCanvasPainter(
                    particles: _particles,
                    glowColor: mascot.glowColor,
                  ),
                ),
              ),

              // B. 3D Obsidian Altar Pedestal on the Chamber Floor
              Positioned(
                bottom: 24,
                child: AnimatedBuilder(
                  animation: _altarSpinController,
                  builder: (context, _) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateX(1.15) // Deep 3D perspective floor tilt
                        ..rotateZ(_altarSpinController.value * math.pi * 2),
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: mascot.glowColor.withValues(alpha: 0.5),
                            width: 2.0,
                          ),
                          gradient: RadialGradient(
                            colors: [
                              mascot.glowColor.withValues(alpha: 0.22),
                              Colors.black.withValues(alpha: 0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: mascot.glowColor.withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _AltarRunicRingPainter(color: mascot.glowColor),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // C. Dynamic 3D Ground Shadow moving opposite to tilt
              Positioned(
                bottom: 30,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.translationValues(
                    math.sin(_rotY) * 35,
                    -_rotX * 18,
                    0.0,
                  ),
                  child: Container(
                    width: 130,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: const BorderRadius.all(Radius.elliptical(130, 26)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.85),
                          blurRadius: 16,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // D. 3D MOVABLE MASCOT ENTITY (Sculpture with Multi-Layer Parallax)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _idleFloatController,
                  _roarController,
                ]),
                builder: (context, _) {
                  final floatVal = _idleFloatController.value;
                  final floatY = math.sin(floatVal * math.pi * 2) * 9.0;
                  final floatTilt = math.cos(floatVal * math.pi * 2) * 0.04;

                  // Roar scale & vibration pulse
                  final roarVal = _roarController.value;
                  final roarScale = 1.0 + (math.sin(roarVal * math.pi) * 0.16);
                  final shakeX = (roarVal > 0.0 && roarVal < 0.7)
                      ? (math.sin(roarVal * math.pi * 12) * 4.0)
                      : 0.0;

                  return Transform.translate(
                    offset: Offset(shakeX, floatY - 12),
                    child: Transform.scale(
                      scale: roarScale,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0016) // 3D Perspective Depth
                          ..rotateX(_rotX + floatTilt)
                          ..rotateY(_rotY),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Layer 1 (Z: -25): Background Luminous Aura Flare
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.translationValues(-_rotY * 12, _rotX * 12, -25.0),
                              child: Container(
                                width: 210,
                                height: 210,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      mascot.glowColor.withValues(alpha: 0.45),
                                      mascot.glowColor.withValues(alpha: 0.12),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Layer 2 (Z: 0): Central 3D Beast Sculpture & Shield Medallion
                            _MascotCenterSculpture(
                              mascot: mascot,
                              rotX: _rotX,
                              rotY: _rotY,
                            ),

                            // Layer 3 (Z: +30): Foreground Floating Gilded Orbit Ring (Stereoscopic Parallax!)
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.translationValues(_rotY * 18, -_rotX * 18, 30.0),
                              child: Container(
                                width: 175,
                                height: 175,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // E. Kinetic Roar Shockwave Ring
              AnimatedBuilder(
                animation: _roarController,
                builder: (context, _) {
                  final roarVal = _roarController.value;
                  if (roarVal <= 0.0 || roarVal >= 1.0) return const SizedBox.shrink();

                  final ringSize = 100.0 + (roarVal * 260.0);
                  final ringOpacity = (1.0 - roarVal).clamp(0.0, 1.0);

                  return Container(
                    width: ringSize,
                    height: ringSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: mascot.glowColor.withValues(alpha: ringOpacity * 0.9),
                        width: 4.0 * (1.0 - roarVal) + 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: mascot.glowColor.withValues(alpha: ringOpacity * 0.5),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // F. Interactive Overlay Hint
              Positioned(
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 14, color: mascot.accentColor),
                      const SizedBox(width: 6),
                      const Text(
                        'Drag to rotate 360° • Double tap to Roar',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. 3D CONTROL HUD (Turntable, Reset, Roar)
  // ===========================================================================
  Widget _build3DControlHud(MascotLoreData mascot) {
    return Row(
      children: [
        // 1. Turntable 360 Auto-Spin Toggle
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(
              _isAutoRotating ? Icons.pause_circle_filled_rounded : Icons.rotate_right_rounded,
              size: 18,
              color: _isAutoRotating ? Colors.amberAccent : Colors.white70,
            ),
            label: Text(
              _isAutoRotating ? 'Spinning' : '360° Spin',
              style: TextStyle(
                color: _isAutoRotating ? Colors.amberAccent : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: _isAutoRotating ? Colors.amber.withValues(alpha: 0.12) : const Color(0xFF101624),
              side: BorderSide(
                color: _isAutoRotating ? Colors.amberAccent : Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _toggleAutoRotate,
          ),
        ),
        const SizedBox(width: 10),

        // 2. Reset View to Neutral Front
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.center_focus_strong_rounded, size: 18, color: Colors.white70),
            label: const Text(
              'Reset View',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF101624),
              side: const BorderSide(color: Colors.white12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (_isAutoRotating) {
                _isAutoRotating = false;
                _turntableController.stop();
              }
              _springBackToNeutral();
            },
          ),
        ),
        const SizedBox(width: 10),

        // 3. Unleash Roar Button
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Roar!',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mascot.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              shadowColor: mascot.glowColor.withValues(alpha: 0.5),
              elevation: 4,
            ),
            onPressed: _triggerRoar,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. MASCOT IDENTITY & NOBLE BEAST SPECIES
  // ===========================================================================
  Widget _buildMascotHeaderCard(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        gradient: RadialGradient(
          center: const Alignment(0.8, -0.6),
          radius: 1.4,
          colors: [
            mascot.glowColor.withValues(alpha: 0.16),
            const Color(0xFF111827),
            const Color(0xFF0A0E18),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mascot.primaryColor.withValues(alpha: 0.25),
                  border: Border.all(color: mascot.accentColor.withValues(alpha: 0.6), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(mascot.primaryEmoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mascot.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mascot.title.toUpperCase(),
                      style: TextStyle(
                        color: mascot.accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPillTag(Icons.pets_rounded, mascot.beastSpecies, mascot.accentColor),
              _buildPillTag(Icons.bolt_rounded, mascot.element, Colors.amberAccent),
              _buildPillTag(Icons.flag_rounded, '${mascot.houseId.toUpperCase()} HOUSE', Colors.white70),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            mascot.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. COMBAT & POWER ATTRIBUTES BARS
  // ===========================================================================
  Widget _buildMascotPowerStats(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.query_stats_rounded, color: mascot.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Mascot Power Attributes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mascot.powerStats.entries.map((entry) {
            final pct = (entry.value * 100).toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$pct / 100',
                        style: TextStyle(
                          color: mascot.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(mascot.primaryColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // 6. SACRED RELIC OF THE HOUSE ARCHIVES
  // ===========================================================================
  Widget _buildSacredRelicCard(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.12),
            const Color(0xFF131A29),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Icon(mascot.sacredRelicIcon, color: Colors.amberAccent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SACRED HOUSE RELIC',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mascot.sacredRelicTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mascot.sacredRelicDesc,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. ANCIENT FOUNDING ERA CHRONICLES
  // ===========================================================================
  Widget _buildLoreChroniclesCard(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_stories_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Founding Era Chronicles',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mascot.legendStory,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_quote_rounded, color: Colors.amberAccent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mascot.motto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 8. HOUSE VIRTUES & THE SACRED RITE
  // ===========================================================================
  Widget _buildVirtuesAndRiteCard(MascotLoreData mascot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded, color: mascot.accentColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'House Virtues & Sacred Rite',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...mascot.virtues.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: mascot.accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      v,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(color: Colors.white12, height: 24),
          Text(
            mascot.sacredRite,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Central 3D Beast Sculpture with Metallic Finish, Dynamic Rim Highlights, and Embossing
class _MascotCenterSculpture extends StatelessWidget {
  final MascotLoreData mascot;
  final double rotX;
  final double rotY;

  const _MascotCenterSculpture({
    required this.mascot,
    required this.rotX,
    required this.rotY,
  });

  @override
  Widget build(BuildContext context) {
    final lightShiftX = (-rotY * 0.5).clamp(-0.8, 0.8);
    final lightShiftY = (rotX * 0.5).clamp(-0.8, 0.8);

    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(lightShiftX - 0.2, lightShiftY - 0.2),
          radius: 1.2,
          colors: [
            mascot.accentColor,
            mascot.primaryColor,
            const Color(0xFF090E1A),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: mascot.glowColor.withValues(alpha: 0.65),
            blurRadius: 28,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Concentric lathe grooves
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0),
            ),
          ),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.0),
            ),
          ),

          // Central Beast Emblem
          Text(
            mascot.primaryEmoji,
            style: TextStyle(
              fontSize: 68,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                Shadow(
                  color: mascot.glowColor.withValues(alpha: 0.6),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Canvas Painter for Altar Floor Runic Laser Rings
class _AltarRunicRingPainter extends CustomPainter {
  final Color color;

  _AltarRunicRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, radius * 0.75, ringPaint);
    canvas.drawCircle(center, radius * 0.50, ringPaint);

    // 8 Radial runic spikes
    final spikePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * math.pi / 180;
      final p1 = Offset(center.dx + math.cos(angle) * (radius * 0.50), center.dy + math.sin(angle) * (radius * 0.50));
      final p2 = Offset(center.dx + math.cos(angle) * (radius * 0.95), center.dy + math.sin(angle) * (radius * 0.95));
      canvas.drawLine(p1, p2, spikePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AltarRunicRingPainter oldDelegate) => oldDelegate.color != color;
}

/// Canvas Painter for ambient elemental particles (embers/sparks/leaves)
class _ParticleCanvasPainter extends CustomPainter {
  final List<_MascotParticle> particles;
  final Color glowColor;

  _ParticleCanvasPainter({required this.particles, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final paint = Paint()
        ..color = glowColor.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(center.dx + p.x, center.dy + p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleCanvasPainter oldDelegate) => true;
}
