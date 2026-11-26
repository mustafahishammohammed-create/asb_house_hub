import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_record.dart';
import '../models/sports_tournament.dart';
import '../services/auth_service.dart';

class GeminiAiService {
  static const String _prefApiKeyKey = 'asb_gemini_api_key';

  /// Official Google Gemini production models in priority fallback order
  static const List<String> _candidateModels = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
  ];

  /// Public read-only view of official candidate models in priority fallback order
  static List<String> get candidateModels => List.unmodifiable(_candidateModels);

  @visibleForTesting
  static http.Client? httpClientOverride;

  static Future<http.Response> _post({
    required Uri url,
    required Map<String, String> headers,
    required Object body,
    required Duration timeout,
  }) {
    final client = httpClientOverride;
    if (client != null) {
      return client.post(url, headers: headers, body: body).timeout(timeout);
    }
    return http.post(url, headers: headers, body: body).timeout(timeout);
  }

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
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
        );
        final res = await _post(
          url: url,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': trimmed,
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [{'text': 'Respond with "OK"'}]
              }
            ],
          }),
          timeout: const Duration(seconds: 10),
        );

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

  /// Assembles comprehensive live student context across all 7 school subsystems.
  static String buildStudentLiveContext({
    required String scholarNo,
    required String house,
    required String studentName,
    String? classLevel,
  }) {
    final effectiveClass = classLevel ??
        (AuthService.getCachedProfile()?['class_level']?.toString() ?? 'Grade 10');
    final buffer = StringBuffer();

    buffer.writeln('=== LIVE ASB STUDENT CONTEXT (REAL-TIME DATA) ===');
    buffer.writeln('Student Name: $studentName');
    buffer.writeln('Scholar No: $scholarNo');
    buffer.writeln('House: ${house.toUpperCase()}');
    buffer.writeln('Class Level: $effectiveClass');

    // 1. Attendance Subsystem (CBSE 75% Statutory Check)
    try {
      final records = AuthService.getCachedAttendanceRecords(scholarNo: scholarNo);
      if (records.isNotEmpty) {
        final summary = AttendanceSummary.fromRecords(records);
        final pct = summary.percentage!;
        buffer.writeln('\n[Attendance Metrics]');
        buffer.writeln('Total Tracked Days: ${summary.totalDays}, Present: ${summary.presentDays}, Late: ${summary.lateDays}, Excused: ${summary.excusedDays}, Absent: ${summary.absentDays}');
        buffer.writeln('Attendance Percentage: ${pct.toStringAsFixed(1)}%');
        if (pct < 75.0) {
          buffer.writeln('⚠️ STATUTORY ATTENDANCE WARNING: Student attendance (${pct.toStringAsFixed(1)}%) is BELOW the mandatory CBSE 75% minimum threshold!');
        } else {
          buffer.writeln('✅ Attendance Status: Satisfies statutory CBSE 75% threshold.');
        }
      } else {
        buffer.writeln('\n[Attendance Metrics] No attendance records logged yet. Attendance data is unavailable.');
      }
    } catch (_) {}

    // 2. Timetable Subsystem
    try {
      final timetable = AuthService.getCachedTimetable(classLevel: effectiveClass);
      buffer.writeln('\n[Today\'s Timetable]');
      if (timetable.isNotEmpty) {
        for (final p in timetable) {
          buffer.writeln('- Period ${p.periodNumber}: ${p.subject} with ${p.teacherName} in Room ${p.room} (${p.timeSlot})');
        }
      } else {
        buffer.writeln('No active classes scheduled in cache for today.');
      }
    } catch (_) {}

    // 3. Academic Assignments & Homework
    try {
      final assignments = AuthService.getCachedAssignments(classLevel: effectiveClass);
      buffer.writeln('\n[Academic Assignments & Homework]');
      if (assignments.isNotEmpty) {
        for (final a in assignments) {
          final due = '${a.dueDateTime.day}/${a.dueDateTime.month}/${a.dueDateTime.year}';
          buffer.writeln('- ${a.subject}: "${a.title}" (Due: $due, Status: ${a.status.displayName})');
        }
      } else {
        buffer.writeln('No pending assignments logged.');
      }
    } catch (_) {}

    // 4. Exam Schedule
    try {
      final exams = AuthService.getCachedExamSchedule(classLevel: effectiveClass);
      buffer.writeln('\n[Upcoming Exam Schedule]');
      if (exams.isNotEmpty) {
        for (final e in exams) {
          final examDate = '${e.examDateTime.day}/${e.examDateTime.month}/${e.examDateTime.year}';
          final syllabus = e.syllabusTopics.isNotEmpty ? e.syllabusTopics.join(', ') : 'All Term Topics';
          buffer.writeln('- ${e.subject} (${e.paperTitle}): $examDate (Duration: ${e.durationMinutes}m, Room: ${e.examHall}, Syllabus: $syllabus)');
        }
      } else {
        buffer.writeln('No upcoming examinations scheduled.');
      }
    } catch (_) {}

    // 5. House Leaderboard & Contribution
    try {
      final standings = AuthService.getCachedHouseStandings();
      final sorted = standings.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final houseRank = sorted.indexWhere((e) => e.key.toLowerCase() == house.toLowerCase()) + 1;
      final housePts = standings[house.toLowerCase()] ?? 0;
      final contrib = AuthService.getCachedStudentContribution(scholarNo);

      final syncedAt = AuthService.getStandingsLastSyncedAt();
      final isFresh = AuthService.isFirebaseLive &&
          syncedAt != null &&
          DateTime.now().difference(syncedAt).inMinutes < 15;
      final provenanceStr = isFresh
          ? 'Live Server Verified (synced ${syncedAt.hour.toString().padLeft(2, '0')}:${syncedAt.minute.toString().padLeft(2, '0')})'
          : (syncedAt != null
              ? 'Cached Offline (last synced ${syncedAt.hour.toString().padLeft(2, '0')}:${syncedAt.minute.toString().padLeft(2, '0')})'
              : 'Offline Baseline');
      buffer.writeln('\n[House Standings & Contribution ($provenanceStr)]');
      buffer.writeln('Current House Rank: #${houseRank == 0 ? 1 : houseRank} / 4 (${house.toUpperCase()} has $housePts PTS)');
      buffer.writeln('Student Contribution: ${contrib.totalPoints} PTS (Merits: ${contrib.merits}, Demerits: ${contrib.demerits})');
      final standingsList = sorted.map((e) => '${e.key.toUpperCase()}: ${e.value} pts').join(' | ');
      buffer.writeln('Full Standings: $standingsList');
    } catch (_) {}

    // 6. Sports League & Trophies
    try {
      final fixtures = AuthService.getCachedSportsFixtures();
      final userFixtures = fixtures.where((f) =>
        f.houseA.toLowerCase() == house.toLowerCase() ||
        f.houseB.toLowerCase() == house.toLowerCase()
      ).toList();

      final trophies = AuthService.getCachedSportsTrophies();
      final userTrophies = trophies.where((t) => t.winningHouse.toLowerCase() == house.toLowerCase()).toList();

      buffer.writeln('\n[Inter-House Sports League]');
      if (userFixtures.isNotEmpty) {
        buffer.writeln('Recent / Upcoming Fixtures:');
        for (final f in userFixtures.take(3)) {
          final statusStr = f.status == MatchStatus.completed
              ? 'Completed (${f.houseA.toUpperCase()} ${f.scoreA} - ${f.scoreB} ${f.houseB.toUpperCase()})'
              : (f.status == MatchStatus.live ? 'LIVE NOW!' : 'Upcoming');
          buffer.writeln('- ${f.tournamentTitle} (${f.sportType.displayName}): ${f.houseA.toUpperCase()} vs ${f.houseB.toUpperCase()} [$statusStr]');
        }
      } else {
        buffer.writeln('No fixtures currently scheduled for ${house.toUpperCase()}.');
      }
      if (userTrophies.isNotEmpty) {
        buffer.writeln('Championship Trophies Won: ${userTrophies.map((t) => t.tournamentTitle).join(', ')}');
      }
    } catch (_) {}

    buffer.writeln('=== END OF LIVE STUDENT CONTEXT ===');
    return buffer.toString();
  }

  static String _buildSystemInstruction(String house, String studentName, {String? liveContext}) {
    final hUpper = house.toUpperCase();
    return '''
You are the official ASB House AI Advisor & Mentor for The Asian School Bahrain (ASB).
You are currently advising $studentName, an esteemed member of $hUpper House.

Identity & Persona:
- You are powered by Google Gemini generative AI with conversational reasoning.
- You passionately champion $hUpper House!
- Mascots:
  • Ruby: Ignis the Crimson Dragon (Fire, Courage, Passion, Honor)
  • Sapphire: Zephyr the Tempest Gryphon (Sky, Wisdom, Precision, Intellect)
  • Emerald: Sylva the Titan Wolf (Earth, Perseverance, Loyalty, Brotherhood)
  • Topaz: Solis the Golden Chimera (Sun, Radiance, Sportsmanship, Charisma)
- Tone: Natural, friendly, witty, encouraging, and knowledgeable. Talk like a real conversational mentor.
- Formatting Rules:
  • DO NOT use markdown headers (# or ## or ###).
  • DO NOT use double asterisks (**bold**). Use clean plain text formatting with bullet points (•) and relevant emojis.
  • Enforce CBSE compliance awareness (75% minimum attendance rule).

${liveContext ?? ''}
''';
  }

  /// Cleans and sanitizes raw AI output, stripping markdown headers and double asterisks
  static String sanitizeAiOutput(String text) {
    if (text.isEmpty) return text;
    String clean = text;
    // Strip markdown headers (e.g. ### Header -> Header)
    clean = clean.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    // Strip bold asterisks (e.g. **Text** -> Text)
    clean = clean.replaceAll('**', '');
    // Strip raw offline notes if any
    clean = clean.replaceAll(RegExp(r'>\s*💡\s*\*Note:[^\n]*', multiLine: true), '');
    // Strip standalone backticks
    clean = clean.replaceAll('`', '');
    return clean.trim();
  }

  /// Sends message to Gemini AI model or falls back to intelligent local context heuristic
  static Future<String> generateResponse({
    required String prompt,
    required String house,
    required String studentName,
    String? scholarNo,
    String? classLevel,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    final userKey = await getSavedApiKey();
    final sNo = scholarNo ?? (AuthService.getCachedScholarNo() ?? '2310910');
    final cLevel = classLevel ?? (AuthService.getCachedProfile()?['class_level']?.toString() ?? 'Grade 10');

    if (userKey == null || userKey.isEmpty) {
      // Default / offline state: return intelligent contextual response using live cached data
      final localRes = _generateContextualLocalResponse(
        prompt,
        house,
        studentName,
        scholarNo: sNo,
        classLevel: cLevel,
      );
      return sanitizeAiOutput(localRes);
    }

    final liveContext = buildStudentLiveContext(
      scholarNo: sNo,
      house: house,
      studentName: studentName,
      classLevel: cLevel,
    );

    String lastError = '';

    for (final modelName in _candidateModels) {
      try {
        final restUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent',
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
            'parts': [
              {
                'text': _buildSystemInstruction(
                  house,
                  studentName,
                  liveContext: liveContext,
                )
              }
            ]
          },
          'contents': contents,
          'generationConfig': {
            'temperature': 0.75,
            'topP': 0.95,
            'maxOutputTokens': 1500,
          }
        };

        final res = await _post(
          url: restUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': userKey,
          },
          body: jsonEncode(payload),
          timeout: const Duration(seconds: 15),
        );

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          final candidateText = json['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (candidateText != null && candidateText.toString().trim().isNotEmpty) {
            return sanitizeAiOutput(candidateText.toString().trim());
          }
        } else {
          String errMsg = 'HTTP ${res.statusCode}';
          try {
            final errJson = jsonDecode(res.body);
            if (errJson is Map && errJson['error']?['message'] != null) {
              errMsg = errJson['error']['message'].toString();
            }
          } catch (_) {}
          lastError = errMsg;
          debugPrint('Gemini model $modelName returned error: $lastError');
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('Gemini exception on $modelName: $e');
      }
    }

    // Graceful offline fallback when Gemini API endpoint is unreachable or key limit is exceeded
    final fallback = _generateContextualLocalResponse(
      prompt,
      house,
      studentName,
      scholarNo: sNo,
      classLevel: cLevel,
    );
    return sanitizeAiOutput(fallback);
  }

  /// Built-in intelligent advisor that utilizes local write-through cache across all 7 subsystems
  static String _generateContextualLocalResponse(
    String prompt,
    String house,
    String studentName, {
    String? scholarNo,
    String? classLevel,
  }) {
    final lower = prompt.toLowerCase();
    final hUpper = house.toUpperCase();
    final effectiveScholar = scholarNo ?? (AuthService.getCachedScholarNo() ?? '2310910');
    final effectiveClass = classLevel ?? (AuthService.getCachedProfile()?['class_level']?.toString() ?? 'Grade 10');

    // 1. Timetable / Schedule Queries
    if (lower.contains('timetable') || lower.contains('period') || lower.contains('class schedule') || lower.contains('my class') || lower.contains('next class') || lower.contains('schedule for today') || (lower.contains('schedule') && !lower.contains('exam'))) {
      final periods = AuthService.getCachedTimetable(classLevel: effectiveClass);
      if (periods.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('📅 Today\'s Timetable for $studentName ($effectiveClass)\n');
        for (final p in periods) {
          buffer.writeln('• Period ${p.periodNumber} (${p.timeSlot}): ${p.subject}');
          buffer.writeln('  📍 Room: ${p.room} | Teacher: ${p.teacherName}');
        }
        buffer.writeln('\nHave a productive academic day in $hUpper! 📚');
        return buffer.toString();
      } else {
        return '📅 Timetable Schedule\nNo classes are currently scheduled in your cached timetable for today. Check back after next sync!';
      }
    }

    // 2. Attendance Queries (with 75% CBSE compliance check)
    if (lower.contains('attendance') || lower.contains('present') || lower.contains('absent') || lower.contains('percentage')) {
      final records = AuthService.getCachedAttendanceRecords(scholarNo: effectiveScholar);
      if (records.isNotEmpty) {
        final summary = AttendanceSummary.fromRecords(records);
        final pct = summary.percentage!;
        final isUnderThreshold = pct < 75.0;

        final buffer = StringBuffer();
        buffer.writeln('📊 Live Attendance Audit for $studentName\n');
        buffer.writeln('• Scholar No: $effectiveScholar');
        buffer.writeln('• Total Recorded Sessions: ${summary.totalDays} days');
        buffer.writeln('• Present: ${summary.presentDays} | Late: ${summary.lateDays} | Excused: ${summary.excusedDays} | Absent: ${summary.absentDays}');
        buffer.writeln('• Attendance Percentage: ${pct.toStringAsFixed(1)}%\n');

        if (isUnderThreshold) {
          buffer.writeln('⚠️ STATUTORY WARNING: Your attendance is below the mandatory 75% CBSE minimum requirement! Ensure regular attendance to avoid eligibility restrictions.');
        } else {
          buffer.writeln('✅ EXCELLENT: Your attendance meets the statutory 75% CBSE minimum threshold.');
        }
        return buffer.toString();
      } else {
        return '📊 Live Attendance Audit\nNo attendance logs recorded yet for Scholar $effectiveScholar. Attendance data is unavailable.';
      }
    }

    // 3. Homework / Academic Assignments Queries
    if (lower.contains('homework') || lower.contains('assignment') || lower.contains('due') || lower.contains('pending')) {
      final assignments = AuthService.getCachedAssignments(classLevel: effectiveClass);
      if (assignments.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('📝 Active Academic Homework & Assignments\n');
        for (final a in assignments) {
          final dueStr = '${a.dueDateTime.day}/${a.dueDateTime.month}/${a.dueDateTime.year}';
          buffer.writeln('• ${a.subject}: ${a.title}');
          buffer.writeln('  📅 Due: $dueStr | Status: ${a.status.displayName}');
        }
        buffer.writeln('\nStay ahead of deadlines to keep $hUpper shining! 🌟');
        return buffer.toString();
      } else {
        return '📝 Homework Tracker\nYou have no pending homework or assignments recorded in the academic portal!';
      }
    }

    // 4. Upcoming Exams Queries
    if (lower.contains('exam') || lower.contains('test') || lower.contains('portion') || lower.contains('syllabus')) {
      final exams = AuthService.getCachedExamSchedule(classLevel: effectiveClass);
      if (exams.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('🧠 Upcoming Examination Schedule ($effectiveClass)\n');
        for (final e in exams) {
          final dt = '${e.examDateTime.day}/${e.examDateTime.month}/${e.examDateTime.year}';
          final syllabus = e.syllabusTopics.isNotEmpty ? e.syllabusTopics.join(', ') : 'All Term Syllabus';
          buffer.writeln('• ${e.subject} (${e.paperTitle}): $dt (Duration: ${e.durationMinutes}m)');
          buffer.writeln('  📍 Hall: ${e.examHall} | Syllabus: $syllabus');
        }
        buffer.writeln('\nStart your revision cycles early! High scores earn massive house merits! 🏆');
        return buffer.toString();
      } else {
        return '''🧠 High-Performance Study Protocol for $studentName

1. The 50/10 Pomodoro Sprint:
   • Study with zero distractions for 50 minutes, then take a 10-minute mental reset.
2. Active Recall & Feynman Technique:
   • Explain the concept in simple terms without looking at your notes.
3. House Energy Mindset:
   • A sharp mind brings pride to $hUpper. Conquer every question!''';
      }
    }

    // 5. Sports League & Fixtures Queries
    if (lower.contains('sport') || lower.contains('fixture') || lower.contains('match') || lower.contains('tournament') || lower.contains('league') || lower.contains('football') || lower.contains('basketball') || lower.contains('volleyball') || lower.contains('track')) {
      final fixtures = AuthService.getCachedSportsFixtures();
      final houseFixtures = fixtures.where((f) =>
        f.houseA.toLowerCase() == house.toLowerCase() ||
        f.houseB.toLowerCase() == house.toLowerCase()
      ).toList();

      final trophies = AuthService.getCachedSportsTrophies();
      final houseTrophies = trophies.where((t) => t.winningHouse.toLowerCase() == house.toLowerCase()).toList();

      final buffer = StringBuffer();
      buffer.writeln('🏟️ $hUpper Inter-House Sports League Intel\n');
      if (houseFixtures.isNotEmpty) {
        buffer.writeln('Match Fixtures:');
        for (final f in houseFixtures) {
          final statusStr = f.status == MatchStatus.completed
              ? '✅ Final Score: ${f.scoreA} - ${f.scoreB}'
              : (f.status == MatchStatus.live ? '🔴 LIVE NOW' : '⏳ Scheduled');
          buffer.writeln('• ${f.tournamentTitle} (${f.sportType.displayName}): ${f.houseA.toUpperCase()} vs ${f.houseB.toUpperCase()} — $statusStr');
        }
      } else {
        buffer.writeln('No upcoming fixtures currently scheduled for $hUpper.');
      }
      if (houseTrophies.isNotEmpty) {
        buffer.writeln('\n🏆 Championship Trophies Won:');
        for (final t in houseTrophies) {
          buffer.writeln('• 🥇 ${t.tournamentTitle} (${t.sportType.displayName}) - +${t.pointsAwarded} PTS');
        }
      }
      return buffer.toString();
    }

    // 6. Leaderboard / Merits / Points Queries
    if (lower.contains('point') || lower.contains('merit') || lower.contains('standing') || lower.contains('leaderboard') || lower.contains('rank') || lower.contains('earn')) {
      final standings = AuthService.getCachedHouseStandings();
      final sorted = standings.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final rawRank = sorted.indexWhere((e) => e.key.toLowerCase() == house.toLowerCase()) + 1;
      final houseRank = rawRank == 0 ? 1 : rawRank;
      final housePts = standings[house.toLowerCase()] ?? 0;
      final contrib = AuthService.getCachedStudentContribution(effectiveScholar);

      final buffer = StringBuffer();
      final syncedAt = AuthService.getStandingsLastSyncedAt();
      final isFresh = AuthService.isFirebaseLive &&
          syncedAt != null &&
          DateTime.now().difference(syncedAt).inMinutes < 15;
      final provenanceStr = isFresh
          ? 'Live Server Verified'
          : (syncedAt != null
              ? 'Cached (synced ${syncedAt.hour.toString().padLeft(2, '0')}:${syncedAt.minute.toString().padLeft(2, '0')})'
              : 'Offline / Cached');
      buffer.writeln('🏆 House Standings ($provenanceStr) & Strategy for $studentName ($hUpper)\n');
      buffer.writeln('• $hUpper Current Rank: #$houseRank with $housePts PTS');
      buffer.writeln('• Your Contribution: ${contrib.totalPoints} PTS (Merits: ${contrib.merits}, Demerits: ${contrib.demerits})\n');
      buffer.writeln('Current Standings:');
      for (int i = 0; i < sorted.length; i++) {
        final icon = i == 0 ? '🥇' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : '🛡️'));
        buffer.writeln('$icon #${i + 1} ${sorted[i].key.toUpperCase()}: ${sorted[i].value} PTS');
      }
      buffer.writeln('\nTactics to Climb the Board:');
      buffer.writeln('1. Academic Excellence & Top Quiz Scores (+10 to +25 PTS)');
      buffer.writeln('2. Submit Inter-House Verified Certificates (+20 to +50 PTS)');
      buffer.writeln('3. Win Sports Championship Fixtures (+100 PTS)');
      return buffer.toString();
    }

    // 7. Chants / Anthems
    if (lower.contains('chant') || lower.contains('anthem') || lower.contains('cry') || lower.contains('cheer')) {
      return '''🔥 Official $hUpper Battle Chant for $studentName!

(Rally your housemates in the corridors and stands!)

"From the fires of honor, from the heights we reign,
$hUpper House marches, we shatter every chain!
With wisdom and courage, our legacy is bold,
The Asian School Champion, crowned in glory and gold!"

Mascot Rally:
"${_getMascotCry(house)}" 🛡️''';
    }

    // 8. Claims / Certificate Queries
    if (lower.contains('claim') || lower.contains('certificate')) {
      return '''📜 How to Submit Verified Claims for $hUpper

1. Tap Submit House Claim on your Dashboard.
2. Enter the competition name (e.g. CBSE Inter-School Athletics, Science Olympiad).
3. Select your award rank (1st, 2nd, 3rd, or Participation).
4. Take a clear photo of your official certificate.
5. Once verified by Faculty or Council Leads, points credit directly to your scholar profile!''';
    }

    // Default Greeting & Mentor Menu
    return '''⚔️ Greetings, $studentName of $hUpper!

I am your ASB House AI Mentor, connected to all campus data systems.

Ask me about any aspect of your school day:
• "What is my timetable today?" (Today's periods, rooms & teachers)
• "What is my attendance percentage?" (CBSE 75% compliance check)
• "What homework is pending?" (Assignments & due dates)
• "When are my upcoming exams?" (Exams & syllabus)
• "How is $hUpper doing on the leaderboard?" (Live standings & points)
• "What sports matches are coming up?" (Sports fixtures & trophies)
• "Give me a battle chant!" (Official house cheer)''';
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
