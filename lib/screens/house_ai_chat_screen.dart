import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/attendance_record.dart';
import '../services/auth_service.dart';
import '../services/gemini_ai_service.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? followUpChips;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.followUpChips,
  });
}

class HouseAiChatScreen extends StatefulWidget {
  final String userHouse;
  final String studentName;
  final String scholarNo;
  final String? classLevel;

  const HouseAiChatScreen({
    super.key,
    required this.userHouse,
    required this.studentName,
    required this.scholarNo,
    this.classLevel,
  });

  @override
  State<HouseAiChatScreen> createState() => _HouseAiChatScreenState();
}

class _HouseAiChatScreenState extends State<HouseAiChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isGenerating = false;
  bool _hasApiKey = false;

  final List<({String label, String prompt, IconData icon})> _smartActionPrompts = [
    (label: 'Timetable', prompt: 'What is my timetable schedule for today?', icon: Icons.schedule_rounded),
    (label: 'Attendance %', prompt: 'What is my current attendance percentage and CBSE 75% status?', icon: Icons.fact_check_rounded),
    (label: 'Homework', prompt: 'What pending homework or assignments do I have?', icon: Icons.assignment_rounded),
    (label: 'House Rank', prompt: 'How is my house performing on the live leaderboard and points?', icon: Icons.leaderboard_rounded),
    (label: 'Sports League', prompt: 'What are the upcoming inter-house sports matches and trophies?', icon: Icons.sports_soccer_rounded),
    (label: 'Exam Syllabus', prompt: 'Show my upcoming examination dates and syllabus portions.', icon: Icons.school_rounded),
    (label: 'Battle Chant', prompt: 'Give me our official house battle chant and mascot rally!', icon: Icons.local_fire_department_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _checkApiKeyStatus();
    _addInitialGreeting();
  }

  Future<void> _checkApiKeyStatus() async {
    final hasKey = await GeminiAiService.hasConfiguredApiKey();
    if (mounted) {
      setState(() {
        _hasApiKey = hasKey;
      });
    }
  }

  void _addInitialGreeting() async {
    final hasKey = await GeminiAiService.hasConfiguredApiKey();
    if (!mounted) return;
    final mascotInfo = _getMascotDetails(widget.userHouse);
    setState(() {
      _hasApiKey = hasKey;
      _messages.add(
        ChatMessage(
          text: hasKey
              ? '✨ Greetings, ${widget.studentName}! I am ${mascotInfo.name}, your ${widget.userHouse.toUpperCase()} House AI Mentor powered by Google Gemini Live.\n\nConnected in real-time to your attendance, timetable, homework, leaderboard points, and sports fixtures. How can I assist you today?'
              : '⚔️ Greetings, ${widget.studentName}! I am ${mascotInfo.name}, your ${widget.userHouse.toUpperCase()} House AI Mentor.\n\nConnected in real-time to your school timetable, attendance records, homework, points, and sports fixtures. Tap 🔑 to connect your Google Gemini API key for unbounded creative conversations!',
          isUser: false,
          timestamp: DateTime.now(),
          followUpChips: [
            '📅 Today\'s Timetable',
            '📊 Attendance % Check',
            '📝 Pending Homework',
            '🏆 Leaderboard Standings',
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  List<String> _generateContextualFollowUps(String userPrompt) {
    final lower = userPrompt.toLowerCase();
    if (lower.contains('timetable') || lower.contains('schedule')) {
      return ['📝 Any homework today?', '🧠 Exam schedule', '🔥 Give me a chant'];
    }
    if (lower.contains('attendance') || lower.contains('present')) {
      return ['⚠️ How do I improve attendance?', '🏆 My house points contribution', '📅 Timetable'];
    }
    if (lower.contains('homework') || lower.contains('assignment')) {
      return ['🧠 High-focus study plan', '📅 Timetable', '🏆 Earn 50 house points'];
    }
    if (lower.contains('sport') || lower.contains('match') || lower.contains('fixture')) {
      return ['⚽ Sports rules & scoring', '🏆 Championship trophies', '🔥 Sports battle chant'];
    }
    if (lower.contains('point') || lower.contains('standing') || lower.contains('merit')) {
      return ['📜 How to submit certificate claims', '⚽ Inter-house sports points', '🔥 Battle chant'];
    }
    return ['📅 Timetable schedule', '📊 Attendance %', '🏆 House standings'];
  }

  Future<void> _handleSendMessage([String? customPrompt]) async {
    final text = (customPrompt ?? _textController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    if (customPrompt == null) {
      _textController.clear();
      _focusNode.requestFocus();
    }

    HapticFeedback.lightImpact();
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final history = _messages.sublist(0, _messages.length - 1).map((m) {
        return {
          'role': m.isUser ? 'user' : 'model',
          'text': m.text,
        };
      }).toList();

      final aiResponse = await GeminiAiService.generateResponse(
        prompt: text,
        house: widget.userHouse,
        studentName: widget.studentName,
        scholarNo: widget.scholarNo,
        classLevel: widget.classLevel,
        conversationHistory: history,
      );

      final followUps = _generateContextualFollowUps(text);

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: aiResponse,
              isUser: false,
              timestamp: DateTime.now(),
              followUpChips: followUps,
            ),
          );
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: '⚠️ An error occurred: $e\nPlease try again.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isGenerating = false;
        });
        _scrollToBottom();
      }
    }
  }

  ({String name, String title, String emoji, String traits, Color color}) _getMascotDetails(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return (
          name: 'Ignis the Crimson Dragon',
          title: 'Guardian of Fire & Valor',
          emoji: '🔥',
          traits: 'Courage • Passion • Honor',
          color: const Color(0xFFEF4444),
        );
      case 'sapphire':
        return (
          name: 'Zephyr the Tempest Gryphon',
          title: 'Keeper of Wisdom & Sky',
          emoji: '⚡',
          traits: 'Precision • Intellect • Vision',
          color: const Color(0xFF3B82F6),
        );
      case 'emerald':
        return (
          name: 'Sylva the Titan Wolf',
          title: 'Protector of Earth & Unity',
          emoji: '🐺',
          traits: 'Loyalty • Perseverance • Brotherhood',
          color: const Color(0xFF10B981),
        );
      case 'topaz':
      default:
        return (
          name: 'Solis the Golden Chimera',
          title: 'Radiance of the Sun',
          emoji: '☀️',
          traits: 'Charisma • Radiance • Sportsmanship',
          color: const Color(0xFFF59E0B),
        );
    }
  }

  void _showApiKeyModal() async {
    final currentKey = await GeminiAiService.getSavedApiKey() ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        bool isChecking = false;
        String? statusMsg;
        bool isSuccess = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141C2E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Google Gemini API Key',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Paste your Google AI Studio Gemini API Key here to enable real-time, open-ended conversational AI for ASB House Hub:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        obscureText: false,
                        decoration: InputDecoration(
                          hintText: 'Paste Gemini Key (e.g. AIzaSy... or AQ....)',
                          filled: true,
                          fillColor: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.key_rounded, size: 20),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    controller.clear();
                                    setModalState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      if (statusMsg != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                color: isSuccess ? Colors.green : Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  statusMsg!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSuccess ? Colors.green : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (currentKey.isNotEmpty) ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await GeminiAiService.saveApiKey('');
                                await _checkApiKeyStatus();
                                if (modalContext.mounted) {
                                  Navigator.pop(modalContext);
                                }
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Gemini API Key removed. Running in offline mode.')),
                                  );
                                }
                              },
                              child: const Text('Clear Key', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: HouseColors.getHouseColor(widget.userHouse),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: isChecking
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final key = controller.text.trim();
                                      if (key.isEmpty) {
                                        setModalState(() {
                                          statusMsg = 'Please paste an API key first.';
                                          isSuccess = false;
                                        });
                                        return;
                                      }

                                      setModalState(() {
                                        isChecking = true;
                                        statusMsg = 'Validating key with Google Gemini servers...';
                                        isSuccess = false;
                                      });

                                      final val = await GeminiAiService.validateApiKey(key);

                                      if (modalContext.mounted) {
                                        setModalState(() {
                                          isChecking = false;
                                          statusMsg = val.message;
                                          isSuccess = val.isValid;
                                        });
                                      }

                                      if (val.isValid) {
                                        await GeminiAiService.saveApiKey(key);
                                        await _checkApiKeyStatus();
                                        await Future.delayed(const Duration(milliseconds: 500));
                                        if (modalContext.mounted) {
                                          Navigator.pop(modalContext);
                                        }
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('✅ Connected! Real Gemini conversational AI is active.'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: isChecking
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Verify & Save', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
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
      },
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          controller.dispose();
        } catch (_) {}
      });
    });
  }

  Widget _buildMascotHeroHud(Color houseColor, bool isDark) {
    final mascot = _getMascotDetails(widget.userHouse);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            houseColor.withValues(alpha: isDark ? 0.25 : 0.12),
            isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: houseColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: houseColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              mascot.emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        mascot.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _hasApiKey ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _hasApiKey ? 'Gemini Live' : 'Offline Mode',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _hasApiKey ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${mascot.title} • ${mascot.traits}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGlanceStatusBar(Color houseColor, bool isDark) {
    // 1. Attendance pill
    final records = AuthService.getCachedAttendanceRecords(scholarNo: widget.scholarNo);
    final totalAtt = records.length;
    final presentAtt = records.where((r) => r.status == AttendanceStatus.present).length;
    final attPct = totalAtt > 0 ? (presentAtt / totalAtt) * 100.0 : 100.0;
    final attWarning = attPct < 75.0 && totalAtt > 0;

    // 2. House Standings pill
    final standings = AuthService.getCachedHouseStandings();
    final sorted = standings.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final rawRank = sorted.indexWhere((e) => e.key.toLowerCase() == widget.userHouse.toLowerCase()) + 1;
    final houseRank = rawRank == 0 ? 1 : rawRank;
    final housePts = standings[widget.userHouse.toLowerCase()] ?? 0;

    // 3. Pending HW pill
    final effectiveClass = widget.classLevel ?? (AuthService.getCachedProfile()?['class_level']?.toString() ?? 'Grade 10');
    final assignments = AuthService.getCachedAssignments(classLevel: effectiveClass);

    // 4. Next Sports match
    final fixtures = AuthService.getCachedSportsFixtures();
    final houseFixtures = fixtures.where((f) =>
      f.houseA.toLowerCase() == widget.userHouse.toLowerCase() ||
      f.houseB.toLowerCase() == widget.userHouse.toLowerCase()
    ).toList();
    final hasActiveFixture = houseFixtures.isNotEmpty;

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Attendance Chip
          _buildStatusPill(
            icon: attWarning ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            label: '${attPct.toStringAsFixed(0)}% Attendance',
            color: attWarning ? Colors.redAccent : Colors.green,
            isDark: isDark,
            onTap: () => _handleSendMessage('What is my attendance percentage and CBSE compliance status?'),
          ),
          const SizedBox(width: 8),

          // House Standings Chip
          _buildStatusPill(
            icon: Icons.emoji_events_rounded,
            label: '#$houseRank ${widget.userHouse.toUpperCase()} ($housePts pts)',
            color: houseColor,
            isDark: isDark,
            onTap: () => _handleSendMessage('How is my house performing on the leaderboard?'),
          ),
          const SizedBox(width: 8),

          // Assignments Chip
          _buildStatusPill(
            icon: Icons.edit_note_rounded,
            label: '${assignments.length} Homework Tasks',
            color: Colors.deepPurpleAccent,
            isDark: isDark,
            onTap: () => _handleSendMessage('What pending homework assignments do I have?'),
          ),
          const SizedBox(width: 8),

          // Sports Fixtures Chip
          _buildStatusPill(
            icon: Icons.sports_soccer_rounded,
            label: hasActiveFixture ? '${houseFixtures.length} Sports Fixtures' : 'Sports League',
            color: Colors.teal,
            isDark: isDark,
            onTap: () => _handleSendMessage('What are our upcoming inter-house sports matches?'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseColor = HouseColors.getHouseColor(widget.userHouse);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B101D) : const Color(0xFFF3F6FA),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [houseColor, Colors.indigoAccent],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ASB House AI',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _hasApiKey ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _hasApiKey
                              ? '${widget.userHouse.toUpperCase()} • Gemini Live'
                              : '${widget.userHouse.toUpperCase()} • Offline',
                          style: TextStyle(
                            fontSize: 9,
                            color: _hasApiKey ? Colors.greenAccent : houseColor,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(
              Icons.vpn_key_rounded,
              size: 20,
              color: _hasApiKey ? Colors.greenAccent : null,
            ),
            tooltip: _hasApiKey ? 'Gemini API Key Active' : 'Configure Gemini API Key',
            onPressed: _showApiKeyModal,
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.delete_sweep_rounded, size: 22),
            tooltip: 'Clear Conversation',
            onPressed: () {
              setState(() {
                _messages.clear();
                _addInitialGreeting();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Mascot Hero HUD
          _buildMascotHeroHud(houseColor, isDark),

          // Quick-Glance Context Status Bar
          _buildQuickGlanceStatusBar(houseColor, isDark),

          // Messages ListView
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, houseColor, isDark);
              },
            ),
          ),

          // Generating indicator
          if (_isGenerating)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(houseColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${widget.userHouse.toUpperCase()} AI Mentor is analyzing...',
                    style: TextStyle(
                      color: houseColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // Categorized Smart Prompts Carousel
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _smartActionPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final item = _smartActionPrompts[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _handleSendMessage(item.prompt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: houseColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: houseColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 14, color: houseColor),
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Text Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A29) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A2438) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Ask your House AI Mentor...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _handleSendMessage(),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: houseColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: houseColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
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

  Widget _buildMessageBubble(ChatMessage msg, Color houseColor, bool isDark) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser
                    ? houseColor
                    : (isDark ? const Color(0xFF162032) : Colors.white),
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(18),
                  bottomLeft: !msg.isUser ? const Radius.circular(4) : const Radius.circular(18),
                ),
                border: !msg.isUser
                    ? Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    msg.text,
                    style: TextStyle(
                      color: msg.isUser
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 9,
                          color: msg.isUser ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      if (!msg.isUser) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: msg.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied response to clipboard!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Interactive Follow-Up Suggestion Chips
            if (!msg.isUser && msg.followUpChips != null && msg.followUpChips!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: msg.followUpChips!.map((chip) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _handleSendMessage(chip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: houseColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: houseColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        chip,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : houseColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
