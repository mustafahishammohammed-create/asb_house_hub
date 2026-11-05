// lib/services/sports_security_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class SportsSecurityService {
  static const String _kSportsCertificationSalt =
      'ASB_SPORTS_CERTIFICATION_KEY_2026_SECURE_SALT_v1';

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
    return expected == token;
  }

  /// Formats an institutional verification code for the official sports gazette.
  static String formatCertificationNumber(String token) {
    final prefix = token.length >= 8 ? token.substring(0, 8).toUpperCase() : token.toUpperCase();
    return 'ASB-SPORT-$prefix';
  }
}
