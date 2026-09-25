import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiAiService {
  static const String _prefApiKeyKey = 'asb_gemini_api_key';
  static const String _fallbackDemoKey = '';

  /// High-performance 2026 Gemini model candidates in fallback order
  static const List<String> _candidateModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.6-flash',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  static Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefApiKeyKey);
    if (key != null && key.trim().isNotEmpty) {
      return key.trim();
    }
    return null;
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKeyKey, key.trim());
  }

  static Future<bool> hasConfiguredApiKey() async {
    final key = await getSavedApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Tests an API key against the Gemini service to verify credentials
  static Future<({bool isValid, String message})> validateApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return (isValid: false, message: 'API key cannot be empty.');
    }

    for (final model in _candidateModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$trimmed',
        );
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [{'text': 'Respond with "OK"'}]
              }
            ],
          }),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          return (isValid: true, message: 'Connected to Gemini Live ($model)!');
        } else if (res.statusCode == 400 || res.statusCode == 403) {
          try {
            final err = jsonDecode(res.body);
            final msg = err['error']?['message'] ?? 'Invalid API key or unauthorized.';
            return (isValid: false, message: msg.toString());
          } catch (_) {
            return (isValid: false, message: 'HTTP ${res.statusCode}: Authentication failed.');
          }
        }
      } catch (e) {
        debugPrint('Validation ping failed on $model: $e');
      }
    }
    return (isValid: false, message: 'Could not connect to Gemini servers. Check network/key.');
  }

  static String _buildSystemInstruction(String house, String studentName) {
    final hUpper = house.toUpperCase();
    return '''
You are the official ASB House AI Advisor & Mentor for The Asian School Bahrain (ASB).
You are currently advising $studentName, an esteemed member of $hUpper House.

Identity & Persona:
- You are powered by real Google Gemini generative AI with full conversational reasoning.
- You passionately champion $hUpper House!
- Mascots:
  * Ruby: Ignis the Crimson Dragon (Fire, Courage, Passion, Honor)
  * Sapphire: Zephyr the Tempest Gryphon (Sky, Wisdom, Precision, Intellect)
  * Emerald: Sylva the Titan Wolf (Earth, Perseverance, Loyalty, Brotherhood)
  * Topaz: Solis the Golden Chimera (Sun, Radiance, Sportsmanship, Charisma)
- Tone: Natural, friendly, witty, encouraging, and deeply knowledgeable. Talk like a real conversational mentor, never robotic or templated.
- Capabilities:
  * You can discuss ANY subject: math problems, science concepts, literature, history, coding/computer science, study schedules, exam prep, speeches, debate rebuttals, or creative writing.
  * You know ASB school life: merits (+points), demerits, inter-house competitions, certificate claims, assembly chants, and sports day tactics.
  * When asked for ideas, study plans, or explanations, provide rich, thoughtful, practical advice formatted with clean Markdown and emojis.
  * Infuse natural house spirit without being overly repetitive.
''';
  }

  /// Sends message to Gemini AI model
  static Future<String> generateResponse({
    required String prompt,
    required String house,
    required String studentName,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    final userKey = await getSavedApiKey() ?? _fallbackDemoKey;

    if (userKey.isNotEmpty) {
      String lastError = '';

      for (final modelName in _candidateModels) {
        try {
          final restUrl = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$userKey',
          );

          final contents = [
            ...conversationHistory.map((m) {
              final role = m['role'] == 'user' ? 'user' : 'model';
              return {
                'role': role,
                'parts': [{'text': m['text'] ?? ''}]
              };
            }),
            {
              'role': 'user',
              'parts': [{'text': prompt}]
            }
          ];

          final payload = {
            'system_instruction': {
              'parts': [{'text': _buildSystemInstruction(house, studentName)}]
            },
            'contents': contents,
            'generationConfig': {
              'temperature': 0.75,
              'topP': 0.95,
              'maxOutputTokens': 1500,
            }
          };

          final res = await http.post(
            restUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 20));

          if (res.statusCode == 200) {
            final json = jsonDecode(res.body);
            final candidateText = json['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (candidateText != null && candidateText.toString().trim().isNotEmpty) {
              return candidateText.toString().trim();
            }
          } else if (res.statusCode == 400 || res.statusCode == 403) {
            final errJson = jsonDecode(res.body);
            final msg = errJson['error']?['message'] ?? 'Authentication failed.';
            return '❌ **Gemini API Error**: $msg\n\n*Please tap the 🔑 key icon in the top bar to re-enter or update your Gemini API key.*';
          } else {
            final errJson = jsonDecode(res.body);
            lastError = errJson['error']?['message'] ?? 'HTTP ${res.statusCode}';
            debugPrint('Gemini model $modelName returned error: $lastError');
          }
        } catch (e) {
          lastError = e.toString();
          debugPrint('Gemini exception on $modelName: $e');
        }
      }

      // If user supplied an API key, explain server status rather than masquerading as hardcoded text
      return '⚠️ **Gemini Service Notice**: Could not reach Gemini servers ($lastError).\n\nPlease verify your internet connection or check the Gemini API key in settings.';
    }

    // Only when NO API key has been entered at all, provide immediate offline advice:
    return _generateBuiltInHouseAdvice(prompt, house, studentName);
  }

  /// Built-in offline intelligent advisor for instant responses when no key is set
  static String _generateBuiltInHouseAdvice(String prompt, String house, String studentName) {
    final lower = prompt.toLowerCase();
    final hUpper = house.toUpperCase();

    if (lower.contains('point') || lower.contains('merit') || lower.contains('earn')) {
      return '''
### 🏆 Blueprint to Surge $hUpper Points!

Hey $studentName! Here is the tactical game plan to climb the leaderboard for **$hUpper**:

1. **Academic Excellence (+10 to +25 Pts)**:
   * Score in the top tier on unit assessments and term projects. Teachers scan student Digital IDs directly to award instant merits!
2. **Submit Inter-House Claims (+20 to +50 Pts)**:
   * Upload external certificates from Olympiads, MUNs, athletics, or coding competitions in the **Submit Claim** portal.
3. **Daily Brain Blitz (+20 Pts)**:
   * Play the 5-question speed showdown in the **House Warroom Arena** every morning.
4. **Zero Demerit Bonus**:
   * Maintaining pristine conduct and punctuality grants bonus house multiplier badges!

*$hUpper to the top! Every single merit counts!* ⚡

> *Tip: Connect a free Google Gemini API Key (tap 🔑 at top right) to unlock unbounded live AI conversations!*
''';
    }

    if (lower.contains('chant') || lower.contains('anthem') || lower.contains('cry') || lower.contains('cheer')) {
      return '''
### 🔥 Official $hUpper Battle Chant!

*(Rally your housemates in the corridors and stands!)*

> *"From the fires of honor, from the heights we reign,*
> *$hUpper House marches, we shatter every chain!*
> *With wisdom and courage, our legacy is bold,*
> *The Asian School Champion, crowned in glory and gold!"*

**Mascot Rally**:
**"${_getMascotCry(house)}"** 🛡️
''';
    }

    if (lower.contains('study') || lower.contains('exam') || lower.contains('tip') || lower.contains('schedule')) {
      return '''
### 🧠 High-Performance Study Protocol for $studentName

1. **The 50/10 Pomodoro Sprint**:
   * Study with zero distractions for 50 minutes, then take a 10-minute mental reset.
2. **Active Recall & Feynman Technique**:
   * Explain the concept in simple terms without looking at your notes. If you stumble, review that specific subtopic.
3. **Past Papers & Question Banks**:
   * Solve at least 3 previous term exam questions under timed conditions.
4. **House Energy Mindset**:
   * A sharp mind brings pride to **$hUpper**. Stay hydrated, get 7 hours of sleep, and conquer!
''';
    }

    if (lower.contains('claim') || lower.contains('certificate')) {
      return '''
### 📜 How to Submit Verified Claims for $hUpper

1. Tap **Submit House Claim** on your Dashboard.
2. Enter the competition name (e.g. *CBSE Inter-School Athletics*, *Science Olympiad*).
3. Select your award rank (*1st, 2nd, 3rd, or Participation*).
4. Take a clear photo of your official certificate.
5. Once verified by Faculty or Council Leads, points credit directly to your scholar profile!
''';
    }

    return '''
### ⚔️ Greetings, Champion of $hUpper!

I am your **ASB House AI Mentor**, running currently in offline mode.

To unlock **real Google Gemini AI** that can answer any question, solve math problems, write essays, and chat freely:
👉 Tap the **🔑 Key Icon** at the top right of this screen and paste your free Google Gemini API key!

Here are some built-in house guides you can ask offline:
* **"How do I earn 50 points for $hUpper this week?"**
* **"Give me an energetic battle chant for sports day!"**
* **"Create a 3-day revision timetable for Physics/Maths."**
* **"How does the Council review claim certificates?"**
''';
  }

  static String _getMascotCry(String house) {
    switch (house.toLowerCase()) {
      case 'ruby':
        return 'RUBY ROARS! IN FIRE WE CONQUER! 🔥';
      case 'sapphire':
        return 'SAPPHIRE SOARS! WISDOM STRIKES TRUE! ⚡';
      case 'emerald':
        return 'EMERALD STANDS! PACK RUNS ETERNAL! 🐺';
      case 'topaz':
      default:
        return 'TOPAZ SHINES! GOLDEN SUN ASCENDS! ☀️';
    }
  }
}
