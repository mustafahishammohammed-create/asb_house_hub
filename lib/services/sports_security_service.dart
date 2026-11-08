// lib/services/sports_security_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class SportsSecurityService {
  static String? _testOverrideSalt;

  @visibleForTesting
  static void setTestSalt(String? salt) {
    _testOverrideSalt = salt;
  }

  /// Secure fail-closed getter for sports certification HMAC salt.
  /// Live builds require --dart-define=SPORTS_CERT_SECRET=...
  /// Test harnesses inject via setTestSalt(...).
  static String get _kSportsCertificationSalt {
    const envSalt = String.fromEnvironment('SPORTS_CERT_SECRET');
    if (envSalt.isNotEmpty) return envSalt;
    if (_testOverrideSalt != null && _testOverrideSalt!.isNotEmpty) {
      return _testOverrideSalt!;
    }
    throw StateError(
      'Security Exception: SPORTS_CERT_SECRET is not configured. '
      'Live operation requires a configured salt via --dart-define=SPORTS_CERT_SECRET=... '
      'or SportsSecurityService.setTestSalt(...) in test harnesses.',
    );
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Generates a tamper-proof HMAC-SHA256 cryptographic signature for a certified match result.
  static String generateMatchCertificationToken({
    required String fixtureId,
    required String sportType,
    required String houseA,
    required String houseB,
    required int scoreA,
    required int scoreB,
    required String refereeScholarNo,
    required DateTime timestamp,
  }) {
    final key = utf8.encode(_kSportsCertificationSalt);
    final payload =
        '${fixtureId.trim()}::${sportType.trim()}::${houseA.trim().toLowerCase()}::${houseB.trim().toLowerCase()}::$scoreA::$scoreB::${refereeScholarNo.trim()}::${timestamp.millisecondsSinceEpoch}';
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Cryptographically verifies a match certification token against post-match score tampering.
  static bool verifyMatchCertificationToken({
    required String token,
    required String fixtureId,
    required String sportType,
    required String houseA,
    required String houseB,
    required int scoreA,
    required int scoreB,
    required String refereeScholarNo,
    required DateTime timestamp,
  }) {
    final expected = generateMatchCertificationToken(
      fixtureId: fixtureId,
      sportType: sportType,
      houseA: houseA,
      houseB: houseB,
      scoreA: scoreA,
      scoreB: scoreB,
      refereeScholarNo: refereeScholarNo,
      timestamp: timestamp,
    );
    return _constantTimeEquals(expected, token);
  }

  /// Formats an institutional verification code for the official sports gazette.
  static String formatCertificationNumber(String token) {
    final prefix = token.length >= 8 ? token.substring(0, 8).toUpperCase() : token.toUpperCase();
    return 'ASB-SPORT-$prefix';
  }
}
