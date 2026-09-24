import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gemini_ai_service.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class HouseAiChatScreen extends StatefulWidget {
  final String userHouse;
  final String studentName;
  final String scholarNo;

  const HouseAiChatScreen({
    super.key,
    required this.userHouse,
    required this.studentName,
    required this.scholarNo,
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

  final List<String> _suggestedPrompts = [
    '🏆 How can I earn 50 points for my house?',
    '🔥 Write an epic battle cry for sports day',
    '🧠 Give me a high-focus exam revision routine',
    '📜 Tips to get my competition claim approved',
    '⚡ Explain a tricky science or math concept',
    '🎭 Write a 1-minute speech on house unity',
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
    setState(() {
      _hasApiKey = hasKey;
      _messages.add(
        ChatMessage(
          text: hasKey
              ? '✨ Greetings, ${widget.studentName}! I am your **${widget.userHouse.toUpperCase()} House AI Advisor** powered by **Google Gemini Live**.\n\nAsk me anything: house strategies, study routines, debate arguments, code, or creative ideas!'
              : 'Greetings, ${widget.studentName}! I am your **${widget.userHouse.toUpperCase()} House AI Advisor**.\n\nCurrently operating with offline house guidance. To unlock full open-ended Gemini conversational intelligence, tap the 🔑 icon above to connect your Google Gemini API key!',
          isUser: false,
          timestamp: DateTime.now(),
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

  Future<void> _handleSendMessage([String? customPrompt]) async {
    final text = (customPrompt ?? _textController.text).trim();
    if (text.isEmpty || _isGenerating) return;

    if (customPrompt == null) {
      _textController.clear();
      _focusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
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
        conversationHistory: history,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: aiResponse,
              isUser: false,
              timestamp: DateTime.now(),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseColor = HouseColors.getHouseColor(widget.userHouse);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B101D) : const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [houseColor, Colors.indigoAccent],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ASB House AI Advisor',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hasApiKey ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _hasApiKey
                          ? '${widget.userHouse.toUpperCase()} Mentor • Gemini Live'
                          : '${widget.userHouse.toUpperCase()} Mentor • Offline Mode',
                      style: TextStyle(
                        fontSize: 10,
                        color: _hasApiKey ? Colors.greenAccent : houseColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(
              Icons.vpn_key_rounded,
              size: 20,
              color: _hasApiKey ? Colors.greenAccent : null,
            ),
            tooltip: _hasApiKey ? 'Gemini API Key Active' : 'Configure Gemini API Key',
            onPressed: _showApiKeyModal,
          ),
          IconButton(
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
          // Messages ListView
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
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
                    '${widget.userHouse.toUpperCase()} AI is thinking...',
                    style: TextStyle(
                      color: houseColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // Suggested Prompts Carousel
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestedPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final prompt = _suggestedPrompts[idx];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _handleSendMessage(prompt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: houseColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: houseColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      prompt,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
                    onTap: _handleSendMessage,
                    child: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
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
                height: 1.4,
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
                      size: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
