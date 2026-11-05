import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ScoreProofVerificationResult = ({
  bool isValid,
  bool isTampered,
  bool isExpired,
  bool isCeilingExceeded,
  int points,
  String? scholarNo,
  String? activityId,
  String? error,
});

typedef CooldownCheckResult = ({
  bool allowed,
  Duration remainingCooldown,
  String formattedRemaining,
});

/// Cryptographic security, score anti-tampering, and rate-limiting service
/// for ASB House Hub gamification activities and daily challenges.
class GamificationSecurityService {
  static const String _institutionSecret = 'ASB_GAMIFICATION_SECRET_HMAC_KEY_2026_V1';
  static const int maxScoreCeiling = 50;
  static const int slidingWindowToleranceMs = 5 * 60 * 1000; // 5 minutes

  static SharedPreferences? _prefs;

  /// Fast in-memory timestamp store for rapid lookups and test execution.
  static final Map<String, int> _memoryTimestamps = {};

  /// Initializes SharedPreferences instance.
  static Future<void> initPreferences([SharedPreferences? instance]) async {
    if (instance != null) {
      _prefs = instance;
      return;
    }
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static String _generateSecureNonce() {
    final rnd = Random.secure();
    final values = List<int>.generate(16, (i) => rnd.nextInt(256));
    return base64Url.encode(values);
  }

  /// Generates the raw cryptographic HMAC-SHA256 signature string.
  static String generateSignature({
    required String scholarNo,
    required String activityId,
    required int pointsEarned,
    required int timestampMillis,
    required String nonce,
  }) {
    final payload = '$scholarNo|$activityId|$pointsEarned|$timestampMillis|$nonce';
    final hmac = Hmac(sha256, utf8.encode(_institutionSecret));
    return hmac.convert(utf8.encode(payload)).toString();
  }

  /// Generates a signed tamper-evident base64Url encoded Score Proof Token.
  static String generateScoreProofToken({
    required String scholarNo,
    required String activityId,
    int? pointsEarned,
    int? points,
    int? timestampMillis,
    String? nonce,
  }) {
    final effectivePoints = pointsEarned ?? points ?? 0;
    final ts = timestampMillis ?? DateTime.now().millisecondsSinceEpoch;
    final n = nonce ?? _generateSecureNonce();
    final sig = generateSignature(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: effectivePoints,
      timestampMillis: ts,
      nonce: n,
    );

    final payloadMap = {
      'v': '1.0',
      'scholar_no': scholarNo,
      'activity_id': activityId,
      'points': effectivePoints,
      'timestamp': ts,
      'nonce': n,
      'sig': sig,
    };

    return base64Url.encode(utf8.encode(jsonEncode(payloadMap)));
  }

  /// Cryptographically verifies a Score Proof Token.
  /// - Enforces maximum point ceiling (<= 50 pts).
  /// - Enforces valid HMAC-SHA256 signature matching the payload.
  /// - Enforces 5-minute sliding window time-drift slice.
  /// - Verifies expected scholar number & activity ID if provided.
  static ScoreProofVerificationResult verifyScoreProofToken({
    required String token,
    String? expectedScholarNo,
    String? expectedActivityId,
    int maxCeiling = maxScoreCeiling,
    DateTime? currentTime,
  }) {
    if (token.trim().isEmpty) {
      return (
        isValid: false,
        isTampered: true,
        isExpired: false,
        isCeilingExceeded: false,
        points: 0,
        scholarNo: null,
        activityId: null,
        error: 'Token is empty',
      );
    }

    Map<String, dynamic> data;
    try {
      final decodedJson = utf8.decode(base64Url.decode(base64Url.normalize(token.trim())));
      final parsed = jsonDecode(decodedJson);
      if (parsed is! Map<String, dynamic>) {
        return (
          isValid: false,
          isTampered: true,
          isExpired: false,
          isCeilingExceeded: false,
          points: 0,
          scholarNo: null,
          activityId: null,
          error: 'Malformed token payload format',
        );
      }
      data = parsed;
    } catch (_) {
      // In case raw JSON string was passed instead of base64Url
      try {
        final parsed = jsonDecode(token);
        if (parsed is! Map<String, dynamic>) {
          throw const FormatException();
        }
        data = parsed;
      } catch (e) {
        return (
          isValid: false,
          isTampered: true,
          isExpired: false,
          isCeilingExceeded: false,
          points: 0,
          scholarNo: null,
          activityId: null,
          error: 'Invalid token encoding: $e',
        );
      }
    }

    final scholarNo = data['scholar_no']?.toString() ?? '';
    final activityId = data['activity_id']?.toString() ?? '';
    final points = (data['points'] as num?)?.toInt() ?? 0;
    final timestamp = (data['timestamp'] as num?)?.toInt() ?? 0;
    final nonce = data['nonce']?.toString() ?? '';
    final signature = data['sig']?.toString() ?? '';

    // 1. Hard Mathematical Ceiling Clamp Check
    if (points < 0 || points > maxCeiling) {
      return (
        isValid: false,
        isTampered: false,
        isExpired: false,
        isCeilingExceeded: true,
        points: points,
        scholarNo: scholarNo,
        activityId: activityId,
        error: 'Score exceeds authorized ceiling of $maxCeiling points (attempted: $points)',
      );
    }

    // 2. Anti-Tampering Check: Context matching
    if (expectedScholarNo != null &&
        scholarNo.trim().toLowerCase() != expectedScholarNo.trim().toLowerCase()) {
      return (
        isValid: false,
        isTampered: true,
        isExpired: false,
        isCeilingExceeded: false,
        points: points,
        scholarNo: scholarNo,
        activityId: activityId,
        error: 'Scholar number mismatch: expected $expectedScholarNo, got $scholarNo',
      );
    }

    if (expectedActivityId != null &&
        activityId.trim().toLowerCase() != expectedActivityId.trim().toLowerCase()) {
      return (
        isValid: false,
        isTampered: true,
        isExpired: false,
        isCeilingExceeded: false,
        points: points,
        scholarNo: scholarNo,
        activityId: activityId,
        error: 'Activity ID mismatch: expected $expectedActivityId, got $activityId',
      );
    }

    // 3. Cryptographic Signature Verification
    final expectedSig = generateSignature(
      scholarNo: scholarNo,
      activityId: activityId,
      pointsEarned: points,
      timestampMillis: timestamp,
      nonce: nonce,
    );

    if (signature.toLowerCase() != expectedSig.toLowerCase()) {
      return (
        isValid: false,
        isTampered: true,
        isExpired: false,
        isCeilingExceeded: false,
        points: points,
        scholarNo: scholarNo,
        activityId: activityId,
        error: 'Cryptographic signature verification failed. Token payload has been altered.',
      );
    }

    // 4. Sliding Window Tolerance Check (5-minute sliding window)
    final nowMs = (currentTime ?? DateTime.now()).millisecondsSinceEpoch;
    final diff = (nowMs - timestamp).abs();
    if (diff > slidingWindowToleranceMs) {
      return (
        isValid: false,
        isTampered: false,
        isExpired: true,
        isCeilingExceeded: false,
        points: points,
        scholarNo: scholarNo,
        activityId: activityId,
        error: 'Score proof token expired outside 5-minute sliding window (drift: ${(diff / 1000).round()}s)',
      );
    }

    return (
      isValid: true,
      isTampered: false,
      isExpired: false,
      isCeilingExceeded: false,
      points: points,
      scholarNo: scholarNo,
      activityId: activityId,
      error: null,
    );
  }

  /// Formats remaining duration as HH:MM:SS or Xh Ym
  static String formatDuration(Duration d) {
    if (d.isNegative || d == Duration.zero) return '00:00:00';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 24-Hour Cooldown Check per student per activity
  static CooldownCheckResult canParticipateDaily(
    String scholarNo,
    String activityId, {
    DateTime? now,
  }) {
    final key = 'gamification_cd_${scholarNo.trim().toLowerCase()}_${activityId.trim().toLowerCase()}';
    final ts = _prefs?.getInt(key) ?? _memoryTimestamps[key];
    if (ts == null) {
      return (
        allowed: true,
        remainingCooldown: Duration.zero,
        formattedRemaining: '00:00:00',
      );
    }

    final lastCompletion = DateTime.fromMillisecondsSinceEpoch(ts);
    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(lastCompletion);
    const cooldownWindow = Duration(hours: 24);

    if (elapsed < cooldownWindow && !elapsed.isNegative) {
      final remaining = cooldownWindow - elapsed;
      return (
        allowed: false,
        remainingCooldown: remaining,
        formattedRemaining: formatDuration(remaining),
      );
    }

    return (
      allowed: true,
      remainingCooldown: Duration.zero,
      formattedRemaining: '00:00:00',
    );
  }

  /// Records an activity completion timestamp for 24-hour cooldown enforcement.
  static Future<void> recordActivityCompletion(
    String scholarNo,
    String activityId, [
    DateTime? time,
  ]) async {
    final key = 'gamification_cd_${scholarNo.trim().toLowerCase()}_${activityId.trim().toLowerCase()}';
    final ts = (time ?? DateTime.now()).millisecondsSinceEpoch;
    _memoryTimestamps[key] = ts;
    await _prefs?.setInt(key, ts);
  }

  /// 60-Second Rapid-Fire Throttle Check per student
  static CooldownCheckResult checkRapidFireThrottle(
    String scholarNo, {
    DateTime? now,
  }) {
    final key = 'gamification_throttle_${scholarNo.trim().toLowerCase()}';
    final ts = _prefs?.getInt(key) ?? _memoryTimestamps[key];
    if (ts == null) {
      return (
        allowed: true,
        remainingCooldown: Duration.zero,
        formattedRemaining: '0s',
      );
    }

    final lastAttempt = DateTime.fromMillisecondsSinceEpoch(ts);
    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(lastAttempt);
    const throttleWindow = Duration(seconds: 60);

    if (elapsed < throttleWindow && !elapsed.isNegative) {
      final remaining = throttleWindow - elapsed;
      return (
        allowed: false,
        remainingCooldown: remaining,
        formattedRemaining: '${remaining.inSeconds}s',
      );
    }

    return (
      allowed: true,
      remainingCooldown: Duration.zero,
      formattedRemaining: '0s',
    );
  }

  /// Records a submission attempt timestamp for 60-second rapid-fire debounce.
  static Future<void> recordSubmissionAttempt(
    String scholarNo, [
    DateTime? time,
  ]) async {
    final key = 'gamification_throttle_${scholarNo.trim().toLowerCase()}';
    final ts = (time ?? DateTime.now()).millisecondsSinceEpoch;
    _memoryTimestamps[key] = ts;
    await _prefs?.setInt(key, ts);
  }

  /// Clears all gamification cooldowns and throttles (for tests/reset).
  static Future<void> clearCooldowns() async {
    _memoryTimestamps.clear();
    final keys = _prefs?.getKeys() ?? {};
    for (final k in keys) {
      if (k.startsWith('gamification_cd_') || k.startsWith('gamification_throttle_')) {
        await _prefs?.remove(k);
      }
    }
  }
}
