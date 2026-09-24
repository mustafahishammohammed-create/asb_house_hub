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
      duration: const Duration(seconds: 4),
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
        shape: BadgeShape.diamond,
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
        shape: BadgeShape.hexagon,
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
        shape: BadgeShape.octagon,
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
        shape: BadgeShape.circle,
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
        shape: BadgeShape.circle,
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
        desc: 'Registered and verified high-security Digital Student ID in Apple Wallet.',
        criteria: 'Activate your digital campus NFC credential with verified student photo.',
        metal: MetalType.roseGold,
        shape: BadgeShape.hexagon,
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
        shape: BadgeShape.circle,
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
        shape: BadgeShape.hexagon,
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
        shape: BadgeShape.octagon,
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
          // 1. APPLE FITNESS RING SUMMARY HEADER
          _buildAppleFitnessSummaryHeader(unlockedCount, allBadges.length, totalMerits),
          const SizedBox(height: 18),

          // 2. HORIZONTAL CATEGORY FILTER CHIPS
          _buildCategoryFilters(),
          const SizedBox(height: 18),

          // 3. APPLE FITNESS DARK STUDIO BADGES GRID
          AnimatedBuilder(
            animation: _gleamController,
            builder: (context, _) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.76,
                ),
                itemCount: filteredBadges.length,
                itemBuilder: (context, index) {
                  final badge = filteredBadges[index];
                  // Offset each badge's light gleam slightly for natural ripple
                  final gleam = (_gleamController.value + (index * 0.12)) % 1.0;

                  return _buildBadgeCard(badge, gleam);
                },
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAppleFitnessSummaryHeader(int unlocked, int total, int totalMerits) {
    final progress = total > 0 ? (unlocked / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C101A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
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
          // Apple Activity Circular Triple-Ring Gauge
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
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5FF)),
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
                      'AWARDS',
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
                  'Apple Activity Awards',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '+$totalMerits Merit Points earned from earned medals.',
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
                          color: Colors.white.withValues(alpha: 0.25),
                          blurRadius: 10,
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

  Widget _buildBadgeCard(AppleFitnessBadgeData badge, double gleam) {
    return GestureDetector(
      onTap: () => _openBadgeModal(badge),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF111724),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: badge.unlocked ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating 3D Badge
            AppleFitnessBadge(
              badge: badge,
              size: 100,
              gleamOffset: gleam,
              recipientName: widget.userName,
              scholarNo: widget.scholarNo,
              houseName: widget.userHouse,
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              badge.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: badge.unlocked ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            // Status Chip or Progress
            if (badge.unlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'EARNED',
                      style: TextStyle(
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
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: badge.progress,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(Colors.white38),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    badge.progressLabel,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The Apple Fitness 3D Inspection Modal with Drag-to-Rotate and Flip Mechanics
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

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
  }

  @override
  void dispose() {
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    b.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.8,
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
                  const SizedBox(height: 10),

                  // INTERACTIVE 3D ROTATABLE MEDAL
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        // Clamp 3D tilt angles for realistic weight
                        _dragY += details.delta.dx * 0.015;
                        _dragX -= details.delta.dy * 0.015;
                        _dragX = _dragX.clamp(-0.45, 0.45);
                        _dragY = _dragY.clamp(-0.6, 0.6);
                      });
                    },
                    onPanEnd: (_) {
                      // Gently spring back tilt when released
                      setState(() {
                        _dragX = 0.0;
                        _dragY = 0.0;
                      });
                    },
                    onTap: _toggleFlip,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, _) {
                        final totalRotY = _dragY + _flipAnimation.value;
                        final showingBack = (totalRotY.abs() % (math.pi * 2)) > (math.pi / 2) &&
                            (totalRotY.abs() % (math.pi * 2)) < (math.pi * 1.5);

                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0015) // 3D Perspective!
                            ..rotateX(_dragX)
                            ..rotateY(totalRotY),
                          child: AppleFitnessBadge(
                            badge: b,
                            size: 210,
                            gleamOffset: 0.45,
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
                  ),

                  const SizedBox(height: 12),
                  // Tap to Flip Prompt
                  TextButton.icon(
                    onPressed: _toggleFlip,
                    icon: const Icon(Icons.sync_rounded, size: 16, color: Colors.amberAccent),
                    label: Text(
                      _isBack ? 'View Front Face' : 'Tap to View Engraved Plate',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title & Rarity
                  Text(
                    b.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 18),

                  // Description Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131926),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Acheivement Story',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        const Text(
                          'Earning Criteria',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b.criteria,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

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
                        b.unlocked ? 'Share Apple Activity Award' : 'Locked — Keep Competing',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      onPressed: b.unlocked
                          ? () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🏆 ${b.title} award ready to share with your housemates!'),
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
