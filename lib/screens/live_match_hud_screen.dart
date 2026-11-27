// lib/screens/live_match_hud_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sports_tournament.dart';
import '../models/match_telemetry.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../services/sports_security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/managed_modal_scope.dart';

class LiveMatchHudScreen extends StatefulWidget {
  final SportsMatchFixture fixture;
  final String userHouse;

  const LiveMatchHudScreen({
    super.key,
    required this.fixture,
    required this.userHouse,
  });

  @override
  State<LiveMatchHudScreen> createState() => _LiveMatchHudScreenState();
}

class _LiveMatchHudScreenState extends State<LiveMatchHudScreen> {
  final _authService = AuthService();
  late SportsMatchFixture _currentFixture;
  late String _activePeriod;
  Timer? _matchTimer;
  late int _totalPeriodSeconds;
  late int _remainingSeconds;
  bool _isTimerRunning = false;
  bool _isPeriodTimeFinished = false;
  late Stream<List<LiveMatchEvent>> _commentaryStream;

  @override
  void initState() {
    super.initState();
    _currentFixture = widget.fixture;
    _commentaryStream =
        _authService.getLiveMatchEventsStream(_currentFixture.fixtureId);
    final periods = LiveMatchClock.getPeriodsForSport(_currentFixture.sportType);
    _activePeriod = periods.isNotEmpty ? periods.first : '1st Half';
    final defaultMins = LiveMatchClock.getDefaultDurationMinutes(
      sport: _currentFixture.sportType,
      period: _activePeriod,
    );
    _totalPeriodSeconds = defaultMins * 60;
    _remainingSeconds = _totalPeriodSeconds;
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    super.dispose();
  }

  void _selectPeriod(String newPeriod) {
    _matchTimer?.cancel();
    final defaultMins = LiveMatchClock.getDefaultDurationMinutes(
      sport: _currentFixture.sportType,
      period: newPeriod,
    );
    setState(() {
      _activePeriod = newPeriod;
      _totalPeriodSeconds = defaultMins * 60;
      _remainingSeconds = _totalPeriodSeconds;
      _isTimerRunning = false;
      _isPeriodTimeFinished = false;
    });
  }

  void _toggleTimer() {
    if (_isTimerRunning) {
      _matchTimer?.cancel();
      setState(() => _isTimerRunning = false);
    } else {
      if (_remainingSeconds <= 0) {
        _remainingSeconds = _totalPeriodSeconds;
      }
      _isTimerRunning = true;
      _isPeriodTimeFinished = false;
      _matchTimer?.cancel();
      _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          timer.cancel();
          HapticFeedback.heavyImpact();
          setState(() {
            _isTimerRunning = false;
            _isPeriodTimeFinished = true;
          });
        }
      });
      setState(() {});
    }
  }

  void _resetTimer() {
    _matchTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _isPeriodTimeFinished = false;
      _remainingSeconds = _totalPeriodSeconds;
    });
  }

  void _showSetDurationDialog() {
    final durations = [1, 2, 5, 10, 12, 15, 20, 25, 30, 45];
    final customCtrl = TextEditingController(text: '${_totalPeriodSeconds ~/ 60}');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ManagedModalScope(
          controllers: [customCtrl],
          child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timer_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Set Period Duration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Select standard or custom minutes for $_activePeriod:',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: durations.map((mins) {
                    final isSel = _totalPeriodSeconds == mins * 60;
                    return ChoiceChip(
                      label: Text(
                        '${mins}m',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isSel ? Colors.black : Colors.white,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: Colors.amber,
                      backgroundColor: Colors.white10,
                      onSelected: (_) {
                        Navigator.pop(ctx);
                        _matchTimer?.cancel();
                        setState(() {
                          _isTimerRunning = false;
                          _isPeriodTimeFinished = false;
                          _totalPeriodSeconds = mins * 60;
                          _remainingSeconds = _totalPeriodSeconds;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Custom Minutes',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(80, 48),
                      ),
                      onPressed: () {
                        final parsed = int.tryParse(customCtrl.text.trim());
                        if (parsed != null && parsed > 0) {
                          Navigator.pop(ctx);
                          _matchTimer?.cancel();
                          setState(() {
                            _isTimerRunning = false;
                            _isPeriodTimeFinished = false;
                            _totalPeriodSeconds = parsed * 60;
                            _remainingSeconds = _totalPeriodSeconds;
                          });
                        }
                      },
                      child: const Text('Set', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  Color _getHouseColor(String house) {
    switch (house.toLowerCase()) {
      case 'sapphire':
        return HouseColors.sapphire;
      case 'emerald':
        return HouseColors.emerald;
      case 'topaz':
        return HouseColors.topaz;
      case 'ruby':
      default:
        return HouseColors.ruby;
    }
  }

  bool get _canScore {
    final profile = AuthService.getCachedProfile();
    final role = (profile?['role'] ?? '').toString();
    final scholar = (profile?['scholar_no'] ?? '').toString();
    final name = (profile?['full_name'] ?? '').toString();
    return HierarchyService.isCouncilOrTeacher(
      scholarNo: scholar,
      role: role,
      fullName: name,
    );
  }

  Future<void> _handleScoreIncrement({
    required String houseName,
    required MatchEventType eventType,
    required int points,
  }) async {
    if (_currentFixture.isCertified || _currentFixture.status == MatchStatus.completed) {
      // Prevent any score modification once match is officially certified by referee
      return;
    }
    HapticFeedback.heavyImpact();
    final success = await _authService.recordMatchScoreEvent(
      fixture: _currentFixture,
      scoringHouse: houseName,
      eventType: eventType,
      pointsToAdd: points,
      periodDescription: _activePeriod,
    );

    if (success && mounted) {
      setState(() {
        final isA = houseName.toLowerCase() == _currentFixture.houseA.toLowerCase();
        _currentFixture = SportsMatchFixture(
          fixtureId: _currentFixture.fixtureId,
          tournamentTitle: _currentFixture.tournamentTitle,
          sportType: _currentFixture.sportType,
          houseA: _currentFixture.houseA,
          houseB: _currentFixture.houseB,
          scoreA: isA ? _currentFixture.scoreA + points : _currentFixture.scoreA,
          scoreB: !isA ? _currentFixture.scoreB + points : _currentFixture.scoreB,
          venue: _currentFixture.venue,
          scheduledAt: _currentFixture.scheduledAt,
          status: MatchStatus.live,
          mvpScholarNo: _currentFixture.mvpScholarNo,
          mvpName: _currentFixture.mvpName,
          isCertified: _currentFixture.isCertified,
          certifiedBy: _currentFixture.certifiedBy,
          refereeScholarNo: _currentFixture.refereeScholarNo,
          certifiedAt: _currentFixture.certifiedAt,
          certificationToken: _currentFixture.certificationToken,
          fairPlayRating: _currentFixture.fairPlayRating,
          refereeNotes: _currentFixture.refereeNotes,
        );
      });
    }
  }

  void _showCertificationDialog() {
    int selectedRating = 5;
    final notesController = TextEditingController();
    final profile = AuthService.getCachedProfile();
    final refereeName = (profile?['full_name'] ?? 'Faculty Referee').toString();
    final refereeScholar = (profile?['scholar_no'] ?? '2310910').toString();
    final refereeRole = (profile?['role'] ?? 'captain').toString();
    final parentMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ManagedModalScope(
          controllers: [notesController],
          child: StatefulBuilder(
            builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.gavel_rounded, color: Colors.amber, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Referee Match Certification',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Official Final Score: ${_currentFixture.scoreA} - ${_currentFixture.scoreB}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fair Play & Conduct Rating',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: Icon(
                            star <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setModalState(() => selectedRating = star);
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Referee match notes / fair play remarks...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.verified_user_rounded, size: 20),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Sign & Certify Result (HMAC-SHA256)',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final notesValue = notesController.text.trim();
                          Navigator.pop(ctx);
                          final res = await _authService.certifyMatchResult(
                            fixture: _currentFixture,
                            refereeScholarNo: refereeScholar,
                            refereeName: refereeName,
                            refereeRole: refereeRole,
                            finalScoreA: _currentFixture.scoreA,
                            finalScoreB: _currentFixture.scoreB,
                            fairPlayRating: selectedRating,
                            refereeNotes: notesValue,
                          );

                          if (res.success && mounted) {
                            setState(() {
                              _currentFixture = SportsMatchFixture(
                                fixtureId: _currentFixture.fixtureId,
                                tournamentTitle: _currentFixture.tournamentTitle,
                                sportType: _currentFixture.sportType,
                                houseA: _currentFixture.houseA,
                                houseB: _currentFixture.houseB,
                                scoreA: _currentFixture.scoreA,
                                scoreB: _currentFixture.scoreB,
                                venue: _currentFixture.venue,
                                scheduledAt: _currentFixture.scheduledAt,
                                status: MatchStatus.completed,
                                mvpScholarNo: _currentFixture.mvpScholarNo,
                                mvpName: _currentFixture.mvpName,
                                isCertified: true,
                                certifiedBy: refereeName,
                                refereeScholarNo: refereeScholar,
                                certifiedAt: DateTime.now(),
                                certificationToken: res.token,
                                fairPlayRating: selectedRating,
                                refereeNotes: notesValue,
                              );
                            });
                          } else if (mounted) {
                            parentMessenger.showSnackBar(
                              SnackBar(
                                content: Text(res.error ?? 'Match certification failed. Please check connection.'),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
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

  void _showMvpNominationModal() {
    final scholarController = TextEditingController();
    final nameController = TextEditingController();
    String selectedHouse = _currentFixture.houseA;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ManagedModalScope(
          controllers: [scholarController, nameController],
          child: StatefulBuilder(
            builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.military_tech_rounded, color: Colors.amber, size: 24),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nominate Match Day MVP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: scholarController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'MVP Scholar Number',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'e.g. 2310910',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Player Full Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'e.g. Tariq Mansoor',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Select Player House',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [_currentFixture.houseA, _currentFixture.houseB].map((house) {
                        final isSelected = selectedHouse.toLowerCase() == house.toLowerCase();
                        final hColor = _getHouseColor(house);
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: hColor,
                            radius: 6,
                          ),
                          label: Text(
                            house.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.amber,
                          onSelected: (_) {
                            setModalState(() => selectedHouse = house);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.star_rounded, size: 20),
                        label: const Text(
                          'Award Official Match MVP',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final mvpScholarValue = scholarController.text.trim();
                          final mvpNameValue = nameController.text.trim();
                          if (mvpScholarValue.isEmpty || mvpNameValue.isEmpty) {
                            return;
                          }
                          Navigator.pop(ctx);
                          final success = await _authService.awardMatchMvp(
                            fixtureId: _currentFixture.fixtureId,
                            scholarNo: mvpScholarValue,
                            studentName: mvpNameValue,
                            houseName: selectedHouse,
                            sportType: _currentFixture.sportType,
                          );

                          if (success && mounted) {
                            setState(() {
                              _currentFixture = SportsMatchFixture(
                                fixtureId: _currentFixture.fixtureId,
                                tournamentTitle: _currentFixture.tournamentTitle,
                                sportType: _currentFixture.sportType,
                                houseA: _currentFixture.houseA,
                                houseB: _currentFixture.houseB,
                                scoreA: _currentFixture.scoreA,
                                scoreB: _currentFixture.scoreB,
                                venue: _currentFixture.venue,
                                scheduledAt: _currentFixture.scheduledAt,
                                status: _currentFixture.status,
                                mvpScholarNo: mvpScholarValue,
                                mvpName: mvpNameValue,
                                isCertified: _currentFixture.isCertified,
                                certifiedBy: _currentFixture.certifiedBy,
                                refereeScholarNo: _currentFixture.refereeScholarNo,
                                certifiedAt: _currentFixture.certifiedAt,
                                certificationToken: _currentFixture.certificationToken,
                                fairPlayRating: _currentFixture.fairPlayRating,
                                refereeNotes: _currentFixture.refereeNotes,
                              );
                            });
                          }
                        },
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

  Widget _buildMvpBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.military_tech_rounded, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'MATCH MVP: ${_currentFixture.mvpName ?? 'Awarded'} ⭐',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationBanner() {
    final token = _currentFixture.certificationToken != null
        ? SportsSecurityService.formatCertificationNumber(_currentFixture.certificationToken!)
        : 'ASB-SPORT-CERTIFIED';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'OFFICIALLY CERTIFIED RESULT 🛡️',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Certified by ${_currentFixture.certifiedBy ?? 'Faculty Referee'} • $token',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          if (_currentFixture.fairPlayRating != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _currentFixture.fairPlayRating!,
                (_) => const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colA = _getHouseColor(_currentFixture.houseA);
    final colB = _getHouseColor(_currentFixture.houseB);
    final periods = LiveMatchClock.getPeriodsForSport(_currentFixture.sportType);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          '${_currentFixture.sportType.emoji} ${_currentFixture.tournamentTitle}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topSections = <Widget>[
              // 1. Digital Scoreboard HUD
              _buildScoreboardCard(colA, colB),

              // 2. Period Selector & Interactive Clock HUD
              _buildPeriodAndTimerHUD(isDark, periods),

              // 3. MVP Banner (if awarded)
              if (_currentFixture.mvpName != null) _buildMvpBanner(),

              // 4. Certified Banner or Captain Scoring Controls
              if (_currentFixture.isCertified)
                _buildCertificationBanner()
              else if (_canScore) ...[
                _buildScoringControls(colA, colB),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.star_rounded, size: 16),
                          label: const Text(
                            'Nominate MVP',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orangeAccent,
                            side: const BorderSide(color: Colors.orangeAccent),
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: _showMvpNominationModal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.gavel_rounded, size: 16),
                          label: const Text(
                            'Certify & End Match',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.amber,
                            side: const BorderSide(color: Colors.amber),
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: _showCertificationDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 1),
            ];

            if (constraints.maxHeight < 640) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    ...topSections,
                    SizedBox(
                      height: 260,
                      child: _buildCommentaryTicker(),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                ...topSections,
                // 5. Live Commentary Ticker with Screen Reader liveRegion
                Expanded(
                  child: _buildCommentaryTicker(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScoreboardCard(Color colA, Color colB) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colA.withValues(alpha: 0.25),
            const Color(0xFF0F172A),
            colB.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 1),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'MATCH DAY LIVE',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // House A Crest & Name
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colA.withValues(alpha: 0.3),
                      child: Text(
                        _currentFixture.houseA.isNotEmpty ? _currentFixture.houseA[0].toUpperCase() : '?',
                        style: TextStyle(color: colA, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentFixture.houseA.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Digital Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  _currentFixture.formattedScore,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.amber,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              // House B Crest & Name
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colB.withValues(alpha: 0.3),
                      child: Text(
                        _currentFixture.houseB.isNotEmpty ? _currentFixture.houseB[0].toUpperCase() : '?',
                        style: TextStyle(color: colB, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentFixture.houseB.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '📍 ${_currentFixture.venue}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScoringControls(Color colA, Color colB) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚡ Sports Captain Scoring Console',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    '${_currentFixture.houseA.toUpperCase()} (+1)',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colA,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => _handleScoreIncrement(
                    houseName: _currentFixture.houseA,
                    eventType: _currentFixture.sportType == SportType.football
                        ? MatchEventType.goal
                        : MatchEventType.point,
                    points: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    '${_currentFixture.houseB.toUpperCase()} (+1)',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colB,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () => _handleScoreIncrement(
                    houseName: _currentFixture.houseB,
                    eventType: _currentFixture.sportType == SportType.football
                        ? MatchEventType.goal
                        : MatchEventType.point,
                    points: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodAndTimerHUD(bool isDark, List<String> periods) {
    final isFinal = LiveMatchClock.isFinalPeriod(
      sport: _currentFixture.sportType,
      period: _activePeriod,
    );
    final isBreak = LiveMatchClock.isBreakPeriod(_activePeriod);
    final timeStr = LiveMatchClock.formatSeconds(_remainingSeconds);

    String matchWinnerResultText;
    if (_currentFixture.scoreA > _currentFixture.scoreB) {
      matchWinnerResultText = '🏆 ${_currentFixture.houseA.toUpperCase()} WINS THE MATCH!';
    } else if (_currentFixture.scoreB > _currentFixture.scoreA) {
      matchWinnerResultText = '🏆 ${_currentFixture.houseB.toUpperCase()} WINS THE MATCH!';
    } else {
      matchWinnerResultText = '🤝 MATCH TIED / DRAW!';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        children: [
          // Row 1: Period Dropdown + Countdown Timer Display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Period Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _activePeriod,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    items: periods.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(
                          p,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _selectPeriod(val);
                    },
                  ),
                ),
              ),

              // Countdown Timer Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isPeriodTimeFinished
                      ? Colors.redAccent.withValues(alpha: 0.2)
                      : (_isTimerRunning
                          ? Colors.greenAccent.withValues(alpha: 0.2)
                          : Colors.amber.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isPeriodTimeFinished
                        ? Colors.redAccent
                        : (_isTimerRunning ? Colors.greenAccent : Colors.amber),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPeriodTimeFinished
                          ? Icons.alarm_off_rounded
                          : (_isTimerRunning ? Icons.alarm_on_rounded : Icons.timer_outlined),
                      size: 16,
                      color: _isPeriodTimeFinished
                          ? Colors.redAccent
                          : (_isTimerRunning ? Colors.greenAccent : Colors.amber),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: _isPeriodTimeFinished
                            ? Colors.redAccent
                            : (_isTimerRunning ? Colors.greenAccent : Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Period Status Notifications
          if (_isPeriodTimeFinished) ...[
            const SizedBox(height: 10),
            if (isFinal)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF831843), Color(0xFF1E1B4B)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_score_rounded, color: Colors.amber, size: 20),
                        SizedBox(width: 6),
                        Text(
                          '🏁 MATCH ENDED! FINAL WHISTLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      matchWinnerResultText,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Final Score: ${_currentFixture.formattedScore}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (_canScore && !_currentFixture.isCertified) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.verified_user_rounded, size: 18),
                        label: const Text(
                          'Certify & End Match 🛡️',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(0, 40),
                        ),
                        onPressed: _showCertificationDialog,
                      ),
                    ],
                  ],
                ),
              )
            else if (isBreak)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.coffee_rounded, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '☕ Break Over! Ready to start next period.',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.alarm_rounded, color: Colors.orangeAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⏰ Time Finished! Halftime / Break time commenced.',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          // Timer Management Console for Teacher / Referee
          if (_canScore && !_currentFixture.isCertified) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isTimerRunning ? 'Pause ⏸️' : 'Start Timer ▶️',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTimerRunning
                          ? Colors.orangeAccent
                          : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _toggleTimer,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: Text(
                      '${_totalPeriodSeconds ~/ 60}m Set',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _showSetDurationDialog,
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(42, 42),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _resetTimer,
                  child: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentaryTicker() {
    final cached = AuthService.getCachedLiveMatchEvents(_currentFixture.fixtureId);

    return StreamBuilder<List<LiveMatchEvent>>(
      stream: _commentaryStream,
      initialData: cached,
      builder: (context, snapshot) {
        if (snapshot.hasError && (snapshot.data == null || snapshot.data!.isEmpty)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unable to load live commentary feed.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
          );
        }
        final events = snapshot.data ?? [];

        return Semantics(
          liveRegion: true,
          label: events.isNotEmpty
              ? events.first.commentaryText
              : 'Live commentary feed ready',
          child: events.isEmpty
              ? Center(
                  child: Text(
                    'Live commentary will appear here once the match starts.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final ev = events[index];
                    final col = _getHouseColor(ev.houseName);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              ev.houseName.isNotEmpty ? ev.houseName[0].toUpperCase() : '?',
                              style: TextStyle(color: col, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ev.commentaryText,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${ev.timestamp.hour.toString().padLeft(2, '0')}:${ev.timestamp.minute.toString().padLeft(2, '0')} • ${ev.periodDescription}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}
