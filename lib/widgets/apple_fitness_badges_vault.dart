import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'apple_fitness_badge.dart';

/// Complete Apple Fitness Awards Vault featuring 3D interactive medals,
/// gyroscope-like pan inspection, authentic engraved backplates, and progress rings.
class AppleFitnessBadgesVault extends StatefulWidget {
  final String userHouse;
  final String userName;
  final String scholarNo;
  final bool isAdmin;
  final int localTapCount;
  final int blitzScore;

  const AppleFitnessBadgesVault({
    super.key,
    required this.userHouse,
    required this.userName,
    required this.scholarNo,
    this.isAdmin = false,
    this.localTapCount = 0,
    this.blitzScore = 0,
  });

  @override
  State<AppleFitnessBadgesVault> createState() => _AppleFitnessBadgesVaultState();
}

class _AppleFitnessBadgesVaultState extends State<AppleFitnessBadgesVault>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gleamController;
  int _selectedFilterIndex = 0; // 0: All, 1: House Pride, 2: Milestones, 3: Competitions, 4: Unlocked

  final List<String> _filters = [
    'All Badges',
    'House Pride',
    'Milestones',
    'Competitions',
    'Unlocked',
  ];

  @override
  void initState() {
    super.initState();
    _gleamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat();
  }

  @override
  void dispose() {
    _gleamController.dispose();
    super.dispose();
  }

  List<AppleFitnessBadgeData> _getAllBadges() {
    final house = widget.userHouse.toLowerCase();
    final isRuby = house == 'ruby';
    final isSapphire = house == 'sapphire';
    final isEmerald = house == 'emerald';
    final isTopaz = house == 'topaz';

    return [
      // 1. House Pride Crests
      AppleFitnessBadgeData(
        id: 'ruby_ignis',
        title: 'Ignis Firestarter',
        category: 'House Pride',
        desc: 'Champion of the Crimson Dragon. Stoked the eternal flames of Ruby House.',
        criteria: 'Earn 50+ merits specifically during Spirit Week as a Ruby scholar.',
        metal: MetalType.rubyGold,
        shape: BadgeShape.shield,
        icon: Icons.local_fire_department_rounded,
        mascotEmoji: '🔥',
        unlocked: isRuby || widget.isAdmin,
        progress: (isRuby || widget.isAdmin) ? 1.0 : 0.65,
        progressLabel: (isRuby || widget.isAdmin) ? 'Mastered' : '32 / 50 Pts',
        earnedDate: 'Term 1, 2026',
        meritPoints: 75,
        rarity: 'LEGENDARY',
      ),
      AppleFitnessBadgeData(
        id: 'sapphire_zephyr',
        title: 'Zephyr Aeronaut',
        category: 'House Pride',
        desc: 'Ruler of the Tempest Gryphon. Honored for razor-sharp wit and intellect.',
        criteria: 'Achieve 1st place in Inter-House Science or Debate Exhibition.',
        metal: MetalType.sapphireAstral,
        shape: BadgeShape.shield,
        icon: Icons.air_rounded,
        mascotEmoji: '🦅',
        unlocked: isSapphire || widget.isAdmin,
        progress: (isSapphire || widget.isAdmin) ? 1.0 : 0.50,
        progressLabel: (isSapphire || widget.isAdmin) ? 'Mastered' : '1 / 2 Rounds',
        earnedDate: 'Term 1, 2026',
        meritPoints: 75,
        rarity: 'LEGENDARY',
      ),
      AppleFitnessBadgeData(
        id: 'emerald_sylva',
        title: 'Sylva Titan Pack',
        category: 'House Pride',
        desc: 'Steadfast member of the Titan Wolfpack. Unbreakable loyalty and strength.',
        criteria: 'Accumulate zero attendance slips and log 20+ house teamwork hours.',
        metal: MetalType.emeraldJade,
        shape: BadgeShape.shield,
        icon: Icons.forest_rounded,
        mascotEmoji: '🐺',
        unlocked: isEmerald || widget.isAdmin,
        progress: (isEmerald || widget.isAdmin) ? 1.0 : 0.80,
        progressLabel: (isEmerald || widget.isAdmin) ? 'Mastered' : '16 / 20 Hours',
        earnedDate: 'Term 1, 2026',
        meritPoints: 75,
        rarity: 'LEGENDARY',
      ),
      AppleFitnessBadgeData(
        id: 'topaz_solis',
        title: 'Solis Solar Flare',
        category: 'House Pride',
        desc: 'Bearer of the Golden Chimera. Unmatched sportsmanship and radiant charisma.',
        criteria: 'Lead Topaz House to victory in an inter-house athletics match.',
        metal: MetalType.topazSun,
        shape: BadgeShape.shield,
        icon: Icons.wb_sunny_rounded,
        mascotEmoji: '☀️',
        unlocked: isTopaz || widget.isAdmin,
        progress: (isTopaz || widget.isAdmin) ? 1.0 : 0.40,
        progressLabel: (isTopaz || widget.isAdmin) ? 'Mastered' : '2 / 5 Matches',
        earnedDate: 'Term 1, 2026',
        meritPoints: 75,
        rarity: 'LEGENDARY',
      ),

      // 2. Milestones
      AppleFitnessBadgeData(
        id: 'centurion_100',
        title: 'House Centurion',
        category: 'Milestones',
        desc: 'Entered the elite 100+ points club on the official school roster.',
        criteria: 'Accumulate a cumulative lifetime total of 100 or more merit points.',
        metal: MetalType.gold,
        shape: BadgeShape.shield,
        icon: Icons.military_tech_rounded,
        mascotEmoji: '🛡️',
        unlocked: true,
        progress: 1.0,
        progressLabel: '100 / 100 Pts',
        earnedDate: 'September 15, 2026',
        meritPoints: 100,
        rarity: 'EPIC',
      ),
      AppleFitnessBadgeData(
        id: 'pristine_shield',
        title: 'Pristine Shield',
        category: 'Milestones',
        desc: 'Maintained a flawless conduct record with zero campus demerits.',
        criteria: 'Zero uniform infractions or conduct demerits for an entire term.',
        metal: MetalType.platinum,
        shape: BadgeShape.shield,
        icon: Icons.verified_user_rounded,
        mascotEmoji: '🕊️',
        unlocked: true,
        progress: 1.0,
        progressLabel: 'Zero Demerits',
        earnedDate: 'Term 1, 2026',
        meritPoints: 60,
        rarity: 'RARE',
      ),
      AppleFitnessBadgeData(
        id: 'digital_pass',
        title: 'Digital Pioneer',
        category: 'Milestones',
        desc: 'Registered and verified high-security Digital Student ID & NFC credentials.',
        criteria: 'Activate your digital campus NFC credential with verified student photo.',
        metal: MetalType.roseGold,
        shape: BadgeShape.shield,
        icon: Icons.qr_code_2_rounded,
        mascotEmoji: '📱',
        unlocked: true,
        progress: 1.0,
        progressLabel: 'Verified',
        earnedDate: 'Term 1, 2026',
        meritPoints: 35,
        rarity: 'COMMON',
      ),
      AppleFitnessBadgeData(
        id: 'attendance_streak',
        title: 'Perfect Streak',
        category: 'Milestones',
        desc: 'Consecutive 14-day streak of on-time morning assembly arrivals.',
        criteria: 'Check in before 7:45 AM for 14 consecutive school days.',
        metal: MetalType.holographic,
        shape: BadgeShape.shield,
        icon: Icons.all_inclusive_rounded,
        mascotEmoji: '⚡',
        unlocked: false,
        progress: 0.71,
        progressLabel: '10 / 14 Days',
        earnedDate: 'In Progress',
        meritPoints: 80,
        rarity: 'EPIC',
      ),

      // 3. Competitions & Special Editions
      AppleFitnessBadgeData(
        id: 'reactor_overdrive',
        title: 'Overdrive Core',
        category: 'Competitions',
        desc: 'Triggered the 10x Overdrive Resonance in the House Spirit Reactor.',
        criteria: 'Reach 10 taps in rapid succession in the Warroom Clash Reactor.',
        metal: MetalType.holographic,
        shape: BadgeShape.shield,
        icon: Icons.bolt_rounded,
        mascotEmoji: '⚡',
        unlocked: widget.localTapCount >= 10,
        progress: math.min(1.0, widget.localTapCount / 10.0),
        progressLabel: '${widget.localTapCount} / 10 Taps',
        earnedDate: 'September 2026',
        meritPoints: 50,
        rarity: 'RARE',
      ),
      AppleFitnessBadgeData(
        id: 'scholastic_blitz',
        title: 'Scholastic Titan',
        category: 'Competitions',
        desc: 'Conquered the Daily Brain Blitz with an exceptional 80+ score.',
        criteria: 'Score 80% or higher in the daily timed academic showdown.',
        metal: MetalType.platinum,
        shape: BadgeShape.shield,
        icon: Icons.psychology_rounded,
        mascotEmoji: '🧠',
        unlocked: widget.blitzScore >= 80,
        progress: math.min(1.0, widget.blitzScore / 80.0),
        progressLabel: '${widget.blitzScore} / 80 Pts',
        earnedDate: 'September 2026',
        meritPoints: 70,
        rarity: 'EPIC',
      ),
      AppleFitnessBadgeData(
        id: 'claim_champion',
        title: 'Claim Conqueror',
        category: 'Competitions',
        desc: 'Awarded external victory points through verified council claims.',
        criteria: 'Submit an external Olympiad, MUN, or athletics certificate verified by council.',
        metal: MetalType.bronze,
        shape: BadgeShape.shield,
        icon: Icons.workspace_premium_rounded,
        mascotEmoji: '📜',
        unlocked: false,
        progress: 0.45,
        progressLabel: 'Pending Review',
        earnedDate: 'In Progress',
        meritPoints: 65,
        rarity: 'RARE',
      ),
      AppleFitnessBadgeData(
        id: 'cup_guardian',
        title: 'Cup Guardian',
        category: 'Competitions',
        desc: 'Awarded to council leads and champions who defend house integrity.',
        criteria: 'Serve as an elected council representative or verified house prefect.',
        metal: MetalType.gold,
        shape: BadgeShape.shield,
        icon: Icons.shield_rounded,
        mascotEmoji: '👑',
        unlocked: widget.isAdmin,
        progress: widget.isAdmin ? 1.0 : 0.20,
        progressLabel: widget.isAdmin ? 'Honored' : 'Council Exclusive',
        earnedDate: 'Term 1, 2026',
        meritPoints: 120,
        rarity: 'LEGENDARY',
      ),
    ];
  }

  void _openBadgeModal(AppleFitnessBadgeData badge) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppleFitnessBadgeModal(
        badge: badge,
        recipientName: widget.userName,
        scholarNo: widget.scholarNo,
        houseName: widget.userHouse,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allBadges = _getAllBadges();
    final unlockedCount = allBadges.where((b) => b.unlocked).length;
    final totalMerits = allBadges
        .where((b) => b.unlocked)
        .fold<int>(0, (sum, b) => sum + b.meritPoints);

    // Apply Filter
    final filteredBadges = allBadges.where((b) {
      switch (_selectedFilterIndex) {
        case 1:
          return b.category == 'House Pride';
        case 2:
          return b.category == 'Milestones';
        case 3:
          return b.category == 'Competitions';
        case 4:
          return b.unlocked;
        case 0:
        default:
          return true;
      }
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HONOURS TRIPLE-RING SUMMARY HEADER
          _buildHonoursSummaryHeader(unlockedCount, allBadges.length, totalMerits),
          const SizedBox(height: 20),

          // 2. HORIZONTAL CATEGORY FILTER CHIPS
          _buildCategoryFilters(),
          const SizedBox(height: 20),

          // 3. FREESTANDING 3D SHIELDS GRID (NO BOXES)
          AnimatedBuilder(
            animation: _gleamController,
            builder: (context, _) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 210,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 22,
                  childAspectRatio: 0.72,
                ),
                itemCount: filteredBadges.length,
                itemBuilder: (context, index) {
                  final badge = filteredBadges[index];

                  // Staggered periodic wave:
                  // 1. Each shield has a phase offset so they ripple sequentially across the vault
                  final stagger = (index * 0.14) % 1.0;
                  final rawPhase = (_gleamController.value + stagger) % 1.0;

                  // 2. Active sweep is first 36% (~2.5s) with silky smooth cubic easing.
                  // Remaining 64% (~4.5s) is peaceful rest where the metal gleams in ambient light.
                  final double gleam;
                  if (rawPhase < 0.36) {
                    gleam = Curves.easeInOutCubic.transform(rawPhase / 0.36);
                  } else {
                    gleam = -1.0; // Idle rest state: offscreen
                  }

                  return _FreestandingShieldItem(
                    badge: badge,
                    gleam: gleam,
                    userName: widget.userName,
                    scholarNo: widget.scholarNo,
                    userHouse: widget.userHouse,
                    onTap: () => _openBadgeModal(badge),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHonoursSummaryHeader(int unlocked, int total, int totalMerits) {
    final progress = total > 0 ? (unlocked / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        gradient: const RadialGradient(
          center: Alignment(0.7, -0.6),
          radius: 1.4,
          colors: [
            Color(0xFF162035),
            Color(0xFF0A0E18),
            Color(0xFF060910),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Triple-Ring Gauge
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Track
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 9,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                  strokeCap: StrokeCap.round,
                ),
                // Inner Track (Merits ratio)
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: math.min(1.0, totalMerits / 600.0),
                    strokeWidth: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$unlocked/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'HONOURS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w800,
                        fontSize: 7,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Statistics & Glory Level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF9100)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TITAN VAULT',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).toInt()}% Done',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'House Championship Honours',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+$totalMerits Merit Points across collegiate awards.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSel = _selectedFilterIndex == index;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedFilterIndex = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? Colors.white : const Color(0xFF141A26),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSel ? Colors.white : Colors.white12,
                ),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: isSel ? Colors.black : Colors.white70,
                    fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Freestanding 3D Shield without any bounding boxes — supports interactive press-to-tilt
class _FreestandingShieldItem extends StatefulWidget {
  final AppleFitnessBadgeData badge;
  final double gleam;
  final String userName;
  final String scholarNo;
  final String userHouse;
  final VoidCallback onTap;

  const _FreestandingShieldItem({
    required this.badge,
    required this.gleam,
    required this.userName,
    required this.scholarNo,
    required this.userHouse,
    required this.onTap,
  });

  @override
  State<_FreestandingShieldItem> createState() => _FreestandingShieldItemState();
}

class _FreestandingShieldItemState extends State<_FreestandingShieldItem>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  late final AnimationController _springController;
  late Animation<double> _springAnimX;
  late Animation<double> _springAnimY;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          _tiltX = _springAnimX.value;
          _tiltY = _springAnimY.value;
        });
      });
    _springAnimX = const AlwaysStoppedAnimation(0.0);
    _springAnimY = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _springController.stop();
    setState(() {
      _tiltY += details.delta.dx * 0.018;
      _tiltX -= details.delta.dy * 0.018;
      _tiltX = _tiltX.clamp(-0.45, 0.45);
      _tiltY = _tiltY.clamp(-0.45, 0.45);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _springAnimX = Tween<double>(begin: _tiltX, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _springAnimY = Tween<double>(begin: _tiltY, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _springController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    final glowColor = AppleFitnessBadge.getGlowColor(b.metal);

    return GestureDetector(
      onTap: widget.onTap,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Freestanding 3D Shield Stage with Radial Aura & Dynamic Shadow
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Ambient Luminous Aura (No bounding box)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glowColor.withValues(alpha: b.unlocked ? 0.32 : 0.06),
                          glowColor.withValues(alpha: b.unlocked ? 0.10 : 0.01),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // 2. Dynamic 3D Ground Shadow moving with tilt perspective
                Positioned(
                  bottom: 6,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.translationValues(_tiltY * 20, -_tiltX * 10, 0.0),
                    child: Container(
                      width: 80,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.all(Radius.elliptical(80, 18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Freestanding 3D Shield with Interactive Tilt
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002) // 3D Perspective!
                    ..rotateX(_tiltX)
                    ..rotateY(_tiltY),
                  child: AppleFitnessBadge(
                    badge: b,
                    size: 110,
                    gleamOffset: widget.gleam,
                    tiltX: _tiltX,
                    tiltY: _tiltY,
                    recipientName: widget.userName,
                    scholarNo: widget.scholarNo,
                    houseName: widget.userHouse,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Title
          Text(
            b.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: b.unlocked ? Colors.white : Colors.white60,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: -0.2,
              shadows: b.unlocked
                  ? [
                      Shadow(
                        color: glowColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),

          const SizedBox(height: 4),

          // Status & Merits Indicator (Clean typography, no box)
          if (b.unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '+${b.meritPoints} MERITS',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: 90,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: b.progress,
                      minHeight: 3,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    b.progressLabel,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The 3D Shield Inspection Stage with Drag-to-Rotate and Flip Mechanics
class _AppleFitnessBadgeModal extends StatefulWidget {
  final AppleFitnessBadgeData badge;
  final String recipientName;
  final String scholarNo;
  final String houseName;

  const _AppleFitnessBadgeModal({
    required this.badge,
    required this.recipientName,
    required this.scholarNo,
    required this.houseName,
  });

  @override
  State<_AppleFitnessBadgeModal> createState() => _AppleFitnessBadgeModalState();
}

class _AppleFitnessBadgeModalState extends State<_AppleFitnessBadgeModal>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  late final AnimationController _modalGleamController;
  late final AnimationController _springBackController;
  late Animation<double> _springAnimX;
  late Animation<double> _springAnimY;

  // Interactive 3D Rotational Drag angles
  double _dragX = 0.0;
  double _dragY = 0.0;
  bool _isBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    // Modal specular gleam controller (6.5 second majestic cycle)
    _modalGleamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )..repeat();

    // Smooth spring-back physics when releasing 3D rotational drag
    _springBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(() {
        if (!mounted) return;
        setState(() {
          _dragX = _springAnimX.value;
          _dragY = _springAnimY.value;
        });
      });
    _springAnimX = const AlwaysStoppedAnimation(0.0);
    _springAnimY = const AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _modalGleamController.dispose();
    _springBackController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.lightImpact();
    if (_isBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isBack = !_isBack;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    final glowColor = AppleFitnessBadge.getGlowColor(b.metal);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: const Color(0xFF04060A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1)),
        gradient: RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 1.2,
          colors: [
            glowColor.withValues(alpha: b.unlocked ? 0.28 : 0.08),
            const Color(0xFF070B14),
            const Color(0xFF030508),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    b.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 6),

                  // INTERACTIVE 3D FREESTANDING SHIELD IN SPOTLIGHT
                  GestureDetector(
                    onPanUpdate: (details) {
                      _springBackController.stop();
                      setState(() {
                        _dragY += details.delta.dx * 0.015;
                        _dragX -= details.delta.dy * 0.015;
                        _dragX = _dragX.clamp(-0.55, 0.55);
                        _dragY = _dragY.clamp(-0.65, 0.65);
                      });
                    },
                    onPanEnd: (_) {
                      _springAnimX = Tween<double>(begin: _dragX, end: 0.0).animate(
                        CurvedAnimation(parent: _springBackController, curve: Curves.easeOutBack),
                      );
                      _springAnimY = Tween<double>(begin: _dragY, end: 0.0).animate(
                        CurvedAnimation(parent: _springBackController, curve: Curves.easeOutBack),
                      );
                      _springBackController.forward(from: 0.0);
                    },
                    onTap: _toggleFlip,
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Dynamic 3D Ground Shadow moving opposite to tilt
                          Positioned(
                            bottom: 8,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.translationValues(_dragY * 36, -_dragX * 18, 0.0),
                              child: Container(
                                width: 140,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: const BorderRadius.all(Radius.elliptical(140, 26)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.85),
                                      blurRadius: 18,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 2. Giant Freestanding 3D Shield
                          AnimatedBuilder(
                            animation: Listenable.merge([_flipAnimation, _modalGleamController]),
                            builder: (context, _) {
                              final animVal = _flipAnimation.value;
                              final showingBack = animVal >= (math.pi / 2);
                              final renderAngleY = showingBack
                                  ? (animVal - math.pi) + _dragY
                                  : animVal + _dragY;

                              // Smooth modal gleam: sweeps for first 38% (~2.4s) with easeInOutCubic,
                              // followed by 4.1s dignified rest. When inspecting engraved back, gleam is inactive.
                              final rawGleam = _modalGleamController.value;
                              final modalGleam = (!showingBack && rawGleam < 0.38)
                                  ? Curves.easeInOutCubic.transform(rawGleam / 0.38)
                                  : -1.0;

                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.0015) // 3D Perspective!
                                  ..rotateX(_dragX)
                                  ..rotateY(renderAngleY),
                                child: AppleFitnessBadge(
                                  badge: b,
                                  size: 240,
                                  gleamOffset: modalGleam,
                                  tiltX: _dragX,
                                  tiltY: _dragY,
                                  isBack: showingBack,
                                  recipientName: widget.recipientName,
                                  scholarNo: widget.scholarNo,
                                  houseName: widget.houseName,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Floating Glassmorphic Flip Pill
                  InkWell(
                    onTap: _toggleFlip,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sync_rounded, size: 16, color: Colors.amberAccent),
                          const SizedBox(width: 8),
                          Text(
                            _isBack ? 'View Front Crest' : 'Inspect Engraved Plate',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Drag anywhere to tilt in 3D • Tap shield to flip',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Title
                  Text(
                    b.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Rarity & Status Tags
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: b.unlocked
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: b.unlocked ? Colors.greenAccent : Colors.redAccent,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          b.unlocked ? 'EARNED • ${b.earnedDate}' : 'LOCKED',
                          style: TextStyle(
                            color: b.unlocked ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '+${b.meritPoints} MERITS',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Borderless Floating Lore & Criteria
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.amberAccent),
                          SizedBox(width: 6),
                          Text(
                            'HONOUR CHRONICLE',
                            style: TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b.desc,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        children: [
                          Icon(Icons.task_alt_rounded, size: 14, color: Colors.cyanAccent),
                          SizedBox(width: 6),
                          Text(
                            'AWARD CRITERIA',
                            style: TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b.criteria,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: b.unlocked ? Colors.white : Colors.white12,
                        foregroundColor: b.unlocked ? Colors.black : Colors.white60,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: Icon(b.unlocked ? Icons.ios_share_rounded : Icons.lock_outline_rounded),
                      label: Text(
                        b.unlocked ? 'Share House Honour Award' : 'Locked — Keep Competing',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      onPressed: b.unlocked
                          ? () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🛡️ ${b.title} honour certificate ready to share!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
