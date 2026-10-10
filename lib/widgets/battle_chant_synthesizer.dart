import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// =============================================================================
// 1. DATA MODELS & INSTITUTIONAL HOUSE CHANTS
// =============================================================================

enum ChantMode {
  warCry('War Cry', Icons.whatshot_rounded),
  heavyMarch('Heavy March', Icons.directions_walk_rounded),
  stompClap('Stomp-Clap', Icons.sports_kabaddi_rounded),
  victoryAnthem('Victory Anthem', Icons.emoji_events_rounded);

  final String label;
  final IconData icon;
  const ChantMode(this.label, this.icon);
}

enum ChantTempo {
  march(95, 'March (95 BPM)'),
  stomp(110, 'Stomp (110 BPM)'),
  allegro(130, 'Allegro (130 BPM)'),
  surge(150, 'Surge (150 BPM)');

  final int bpm;
  final String label;
  const ChantTempo(this.bpm, this.label);
}

class HouseChantData {
  final String houseId;
  final String warCry;
  final String heavyMarch;
  final String stompClap;
  final String victoryAnthem;

  const HouseChantData({
    required this.houseId,
    required this.warCry,
    required this.heavyMarch,
    required this.stompClap,
    required this.victoryAnthem,
  });

  String getChant(ChantMode mode) {
    switch (mode) {
      case ChantMode.warCry:
        return warCry;
      case ChantMode.heavyMarch:
        return heavyMarch;
      case ChantMode.stompClap:
        return stompClap;
      case ChantMode.victoryAnthem:
        return victoryAnthem;
    }
  }

  static const Map<String, HouseChantData> houseChants = {
    'ruby': HouseChantData(
      houseId: 'ruby',
      warCry: 'RUBY ROARS! IN FIRE WE CONQUER! 🔥',
      heavyMarch: 'Red and Gold, Fierce and Bold! Ignis strikes, the prize we hold!',
      stompClap: 'BOOM! CLAP! RUBY MIGHT! WE CONQUER THE FIGHT!',
      victoryAnthem: 'Through the flame we rise as one! Crimson warriors under the sun!',
    ),
    'sapphire': HouseChantData(
      houseId: 'sapphire',
      warCry: 'SAPPHIRE SOARS! WISDOM STRIKES TRUE! ⚡',
      heavyMarch: 'Wings of Azure, Minds of Steel! Thunder rolls, the victors kneel!',
      stompClap: "CLAP! STOMP! ZEPHYR'S CLOUD! SAPPHIRE STRONG AND PROUD!",
      victoryAnthem: 'Clear the skies, let wisdom reign! Blue supremacy claims the plain!',
    ),
    'emerald': HouseChantData(
      houseId: 'emerald',
      warCry: 'EMERALD STANDS! PACK RUNS ETERNAL! 🐺',
      heavyMarch: 'Roots run deep and wolves run fast! Verdant fury built to last!',
      stompClap: 'THUD! HOWL! TITAN CLAW! PACK DEFIES EVERY FLAW!',
      victoryAnthem: 'Forest shadows, branches tall! Emerald pack will never fall!',
    ),
    'topaz': HouseChantData(
      houseId: 'topaz',
      warCry: 'TOPAZ SHINES! GOLDEN SUN ASCENDS! ☀️',
      heavyMarch: "Golden light across the field! Solis' glory will not yield!",
      stompClap: 'FLASH! ROAR! GOLDEN SUN! TOPAZ VICTORY HAS BEGUN!',
      victoryAnthem: 'Radiance soaring through the haze! Golden champions win the days!',
    ),
  };

  static HouseChantData forHouse(String house) {
    final lower = house.toLowerCase();
    return houseChants[lower] ?? houseChants['ruby']!;
  }
}

// =============================================================================
// 2. BATTLE CHANT SYNTHESIZER WIDGET
// =============================================================================

class BattleChantSynthesizer extends StatefulWidget {
  final String userHouse;
  final ChantMode initialMode;
  final ChantTempo initialTempo;
  final bool autoPlay;
  final VoidCallback? onClose;
  final void Function(SystemSoundType)? soundPlayer;

  const BattleChantSynthesizer({
    super.key,
    required this.userHouse,
    this.initialMode = ChantMode.warCry,
    this.initialTempo = ChantTempo.stomp,
    this.autoPlay = false,
    this.onClose,
    this.soundPlayer,
  });

  @override
  State<BattleChantSynthesizer> createState() => _BattleChantSynthesizerState();
}

class _BattleChantSynthesizerState extends State<BattleChantSynthesizer>
    with SingleTickerProviderStateMixin {
  late ChantMode _selectedMode;
  late ChantTempo _selectedTempo;
  late HouseChantData _chantData;

  Timer? _rhythmTimer;
  int _currentBeat = 0;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _showCaptions = true;

  // 8-band frequency level simulation
  final List<double> _bandLevels = List.filled(8, 0.15);
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _selectedTempo = widget.initialTempo;
    _chantData = HouseChantData.forHouse(widget.userHouse);

    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startSequencer());
    }
  }

  @override
  void dispose() {
    _rhythmTimer?.cancel();
    super.dispose();
  }

  void _playSound(SystemSoundType type) {
    if (_isMuted) return;
    if (widget.soundPlayer != null) {
      widget.soundPlayer!(type);
    } else {
      try {
        SystemSound.play(type);
      } catch (_) {}
    }
  }

  void _startSequencer() {
    _rhythmTimer?.cancel();
    setState(() {
      _isPlaying = true;
    });

    final ms = (60000 / _selectedTempo.bpm).round();
    _rhythmTimer = Timer.periodic(Duration(milliseconds: ms), (timer) {
      if (!mounted) return;
      _tick();
    });

    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${_selectedMode.label} battle chant playing at ${_selectedTempo.bpm} BPM',
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  void _pauseSequencer() {
    _rhythmTimer?.cancel();
    setState(() {
      _isPlaying = false;
      for (int i = 0; i < 8; i++) {
        _bandLevels[i] = 0.15;
      }
    });

    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Battle chant paused',
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  void _stopSequencer() {
    _rhythmTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentBeat = 0;
      for (int i = 0; i < 8; i++) {
        _bandLevels[i] = 0.15;
      }
    });

    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Battle chant stopped and reset',
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  void _tick() {
    setState(() {
      _currentBeat++;
      final isAccent = (_currentBeat % 4) == 0;

      // 1. Play rhythm sound click
      _playSound(isAccent ? SystemSoundType.alert : SystemSoundType.click);

      // 2. Haptic feedback
      if (!_isMuted) {
        if (isAccent) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }

      // 3. Update dynamic 8-band visual equalizer
      for (int i = 0; i < 8; i++) {
        final base = isAccent ? 0.75 : 0.45;
        _bandLevels[i] = (base + _rng.nextDouble() * 0.45).clamp(0.1, 1.0);
      }
    });
  }

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
    });

    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _isMuted ? 'Audio muted' : 'Audio unmuted',
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  void _toggleCaptions() {
    HapticFeedback.selectionClick();
    setState(() {
      _showCaptions = !_showCaptions;
    });

    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _showCaptions ? 'Closed captions enabled' : 'Closed captions disabled',
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  void _changeMode(ChantMode mode) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMode = mode;
      _currentBeat = 0;
    });

    if (_isPlaying) {
      _startSequencer();
    }

    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Chant mode changed to ${mode.label}',
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  void _changeTempo(ChantTempo tempo) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTempo = tempo;
    });

    if (_isPlaying) {
      _startSequencer();
    }

    try {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Tempo changed to ${tempo.label}',
        TextDirection.ltr,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final houseColor = HouseColors.getHouseColor(widget.userHouse);
    final chantText = _chantData.getChant(_selectedMode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.25;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: houseColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: houseColor.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Header, Close button, Mute & CC
              _buildTopHeader(houseColor, isLargeText),
              const SizedBox(height: 14),

              // 8-Band Dynamic Equalizer Canvas (Protected via ExcludeSemantics)
              _buildVisualEqualizer(houseColor),
              const SizedBox(height: 14),

              // Synchronized Closed Captions Banner (Live Region)
              _buildClosedCaptions(chantText, houseColor),
              const SizedBox(height: 16),

              // Chant Mode Selection Chips
              _buildChantModeSelector(houseColor),
              const SizedBox(height: 14),

              // Tempo Selection Chips
              _buildTempoSelector(houseColor),
              const SizedBox(height: 16),

              // Audio Transport Actions (Play/Pause, Stop, Mute, CC)
              _buildAudioTransportActions(houseColor, isLargeText),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SUB-COMPONENTS
  // ===========================================================================

  Widget _buildTopHeader(Color houseColor, bool isLargeText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: houseColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: houseColor.withValues(alpha: 0.5)),
                ),
                child: Icon(Icons.graphic_eq_rounded, color: houseColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.userHouse.toUpperCase()} BATTLE CHANT',
                      style: TextStyle(
                        color: houseColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Rally Synthesizer & Audio FX',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.onClose != null)
          Semantics(
            button: true,
            label: 'Close Battle Chant Synthesizer',
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: widget.onClose,
                tooltip: 'Close Synthesizer',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVisualEqualizer(Color houseColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF04060B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
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
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isPlaying ? Colors.greenAccent : Colors.white30,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _isPlaying ? 'BEAT OSCILLATOR: ACTIVE' : 'BEAT OSCILLATOR: IDLE',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedTempo.bpm} BPM',
                style: TextStyle(
                  color: houseColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ExcludeSemantics shields 60fps/rapid audio frequency animation from Windows AXTree bridge
          ExcludeSemantics(
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: CustomPaint(
                painter: _AudioEqualizerPainter(
                  bandLevels: _bandLevels,
                  color: houseColor,
                  isPlaying: _isPlaying,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedCaptions(String chantText, Color houseColor) {
    if (!_showCaptions) {
      return const SizedBox.shrink();
    }

    final words = chantText.split(' ');
    final activeWordIndex = _isPlaying && words.isNotEmpty ? _currentBeat % words.length : -1;

    return Semantics(
      container: true,
      liveRegion: true,
      excludeSemantics: true,
      label: 'Active Battle Chant: $chantText',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // 7:1 high contrast against white text
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: houseColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: houseColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: houseColor.withValues(alpha: 0.7)),
                        ),
                        child: const Text(
                          'CC LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _selectedMode.label,
                          style: TextStyle(
                            color: houseColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isPlaying ? 'BEAT ${_currentBeat + 1}' : 'PAUSED',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (int i = 0; i < words.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: i == activeWordIndex
                          ? houseColor.withValues(alpha: 0.4)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: i == activeWordIndex
                            ? Colors.white
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      words[i],
                      style: TextStyle(
                        color: i == activeWordIndex ? Colors.white : Colors.white70,
                        fontWeight: i == activeWordIndex ? FontWeight.w900 : FontWeight.w600,
                        fontSize: i == activeWordIndex ? 14 : 13.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChantModeSelector(Color houseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHANT CADENCE',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ChantMode.values.map((mode) {
              final isSel = _selectedMode == mode;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: true,
                  selected: isSel,
                  excludeSemantics: true,
                  label: '${mode.label} Mode',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _changeMode(mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSel ? houseColor : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              mode.icon,
                              size: 16,
                              color: isSel ? Colors.white : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mode.label,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
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
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTempoSelector(Color houseColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TEMPO (BPM)',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ChantTempo.values.map((tempo) {
              final isSel = _selectedTempo == tempo;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: true,
                  selected: isSel,
                  excludeSemantics: true,
                  label: '${tempo.label} Tempo',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _changeTempo(tempo),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSel ? houseColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel ? houseColor : Colors.white12,
                            width: isSel ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          tempo.label,
                          style: TextStyle(
                            color: isSel ? Colors.white : Colors.white70,
                            fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioTransportActions(Color houseColor, bool isLargeText) {
    final playPauseButton = Semantics(
      button: true,
      excludeSemantics: true,
      label: _isPlaying ? 'Pause Battle Chant' : 'Play Battle Chant',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: ElevatedButton.icon(
          onPressed: _isPlaying ? _pauseSequencer : _startSequencer,
          style: ElevatedButton.styleFrom(
            backgroundColor: houseColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20),
          label: Text(
            _isPlaying ? 'PAUSE' : 'PLAY CHANT',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        ),
      ),
    );

    final stopButton = Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Stop Battle Chant',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: OutlinedButton.icon(
          onPressed: _stopSequencer,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.stop_rounded, size: 18),
          label: const Text('STOP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ),
    );

    final muteButton = Semantics(
      button: true,
      toggled: _isMuted,
      excludeSemantics: true,
      label: _isMuted ? 'Unmute Audio' : 'Mute Audio',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: OutlinedButton.icon(
          onPressed: _toggleMute,
          style: OutlinedButton.styleFrom(
            foregroundColor: _isMuted ? Colors.amberAccent : Colors.white,
            side: BorderSide(color: _isMuted ? Colors.amberAccent : Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(_isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 18),
          label: Text(
            _isMuted ? 'MUTED' : 'MUTE',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ),
    );

    final ccButton = Semantics(
      button: true,
      toggled: _showCaptions,
      excludeSemantics: true,
      label: _showCaptions ? 'Hide Closed Captions' : 'Show Closed Captions',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: OutlinedButton.icon(
          onPressed: _toggleCaptions,
          style: OutlinedButton.styleFrom(
            foregroundColor: _showCaptions ? Colors.cyanAccent : Colors.white60,
            side: BorderSide(color: _showCaptions ? Colors.cyanAccent : Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.closed_caption_rounded, size: 18),
          label: Text(
            _showCaptions ? 'CC ON' : 'CC OFF',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ),
    );

    if (isLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          playPauseButton,
          const SizedBox(height: 8),
          stopButton,
          const SizedBox(height: 8),
          muteButton,
          const SizedBox(height: 8),
          ccButton,
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          playPauseButton,
          const SizedBox(width: 8),
          stopButton,
          const SizedBox(width: 8),
          muteButton,
          const SizedBox(width: 8),
          ccButton,
        ],
      ),
    );
  }
}

// =============================================================================
// 3. 8-BAND DYNAMIC EQUALIZER PAINTER
// =============================================================================

class _AudioEqualizerPainter extends CustomPainter {
  final List<double> bandLevels;
  final Color color;
  final bool isPlaying;

  _AudioEqualizerPainter({
    required this.bandLevels,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final totalSpacing = (bandLevels.length - 1) * 6.0;
    final bandWidth = (size.width - totalSpacing) / bandLevels.length;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < bandLevels.length; i++) {
      final heightPct = isPlaying ? bandLevels[i].clamp(0.12, 1.0) : 0.15;
      final barHeight = size.height * heightPct;
      final x = i * (bandWidth + 6.0);
      final y = size.height - barHeight;

      paint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color,
          color.withValues(alpha: 0.7),
          Colors.white,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(x, y, bandWidth, barHeight));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, bandWidth, barHeight),
          const Radius.circular(5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AudioEqualizerPainter oldDelegate) => true;
}
