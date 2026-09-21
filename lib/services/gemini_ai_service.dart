import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiAiService {
  static const String _prefApiKeyKey = 'asb_gemini_api_key';
  // Default demo / public gateway key or user custom key
  static const String _fallbackDemoKey = '';

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

  static String _buildSystemInstruction(String house, String studentName) {
    return '''
You are the official ASB House AI Advisor & Mentor for The Asian School Bahrain (ASB).
You are currently advising $studentName, an esteemed member of ${house.toUpperCase()} House.

Your persona:
- House Affiliation: You passionately support ${house.toUpperCase()} House!
- Mascot inspiration:
  * Ruby: Ignis the Crimson Dragon (Element: Fire, Values: Courage, Passion, Honor)
  * Sapphire: Zephyr the Tempest Gryphon (Element: Wind/Sky, Values: Wisdom, Precision, Intellect)
  * Emerald: Sylva the Titan Wolf (Element: Earth/Forest, Values: Perseverance, Loyalty, Brotherhood)
  * Topaz: Solis the Golden Chimera (Element: Sun/Light, Values: Radiance, Sportsmanship, Charisma)
- Tone: Encouraging, energetic, intellectually sharp, respectful of school guidelines.
- Knowledge base:
  * ASB House Cup: Awarding Merits (+Points) for academic excellence, sports, debate, conduct, and inter-school competitions.
  * Demerits: Deduct points for uniform infractions, tardiness, or misconduct. Can be reconciled with community service and merit streaks.
  * Claims: Students submit verified certificates to council members for point approvals.
  * Exam motivation, study techniques, speech preparation, and house spirit chants.

Keep answers well-structured, formatted in clean Markdown with emojis, and concise (under 200 words unless asked for an essay or study guide).
Always boost ${house.toUpperCase()} House morale!
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
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: userKey,
          systemInstruction: Content.system(_buildSystemInstruction(house, studentName)),
        );

        final historyContent = conversationHistory.map((msg) {
          final role = msg['role'] == 'user' ? 'user' : 'model';
          return Content(role, [TextPart(msg['text'] ?? '')]);
        }).toList();

        final chat = model.startChat(history: historyContent);
        final response = await chat.sendMessage(Content.text(prompt));
        final text = response.text;
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      } catch (e) {
        debugPrint('Gemini SDK error: $e. Falling back to REST/Heuristic.');
        // Try REST directly with v1beta endpoint
        try {
          final restUrl = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$userKey');
          final restRes = await http.post(
            restUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'system_instruction': {
                'parts': [{'text': _buildSystemInstruction(house, studentName)}]
              },
              'contents': [
                ...conversationHistory.map((m) => {
                      'role': m['role'] == 'user' ? 'user' : 'model',
                      'parts': [{'text': m['text'] ?? ''}]
                    }),
                {
                  'role': 'user',
                  'parts': [{'text': prompt}]
                }
              ],
            }),
          );
          if (restRes.statusCode == 200) {
            final json = jsonDecode(restRes.body);
            final candidateText = json['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (candidateText != null && candidateText.toString().trim().isNotEmpty) {
              return candidateText.toString().trim();
            }
          }
        } catch (restErr) {
          debugPrint('REST Gemini error: $restErr');
        }
      }
    }

    // Intelligent Built-in ASB House Knowledge Engine (Works offline or without API key)
    return _generateBuiltInHouseAdvice(prompt, house, studentName);
  }

  /// Built-in intelligent advisor for instant responses
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

I am your **ASB House AI Mentor**, programmed with school regulations, house strategy, and scholastic guidance.

Here are things you can ask me:
* **"How do I earn 50 points for $hUpper this week?"**
* **"Give me an energetic battle chant for sports day!"**
* **"Create a 3-day revision timetable for Physics/Maths."**
* **"How does the Council review claim certificates?"**

> *Tip: You can also configure a personal Google Gemini API Key in settings for unbounded open-ended conversations!*
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
