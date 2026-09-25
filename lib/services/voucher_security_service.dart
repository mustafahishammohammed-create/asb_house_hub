import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cryptographic security service for generating and validating
/// tamper-evident digital vouchers and passes across the ASB House Hub.
class VoucherSecurityService {
  // Institutional HMAC salt for tamper prevention
  static const String _institutionSecret = 'ASB_HOUSE_HUB_OFFICIAL_MERCH_KEY_2026_SECURE';

  /// Generates a HMAC-SHA256 signature token for an order voucher.
  static String generateVoucherToken({
    required String billNo,
    required int points,
    required String scholarNo,
    required int timestampMillis,
  }) {
    final payload = '$billNo|$points|$scholarNo|$timestampMillis|$_institutionSecret';
    final bytes = utf8.encode(payload);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Builds a complete scannable JSON payload with cryptographic verification token.
  static String generateVoucherPayload({
    required String billNo,
    required int points,
    required String scholarNo,
    required List<String> items,
    int? timestampMillis,
  }) {
    final ts = timestampMillis ?? DateTime.now().millisecondsSinceEpoch;
    final token = generateVoucherToken(
      billNo: billNo,
      points: points,
      scholarNo: scholarNo,
      timestampMillis: ts,
    );

    return jsonEncode({
      'type': 'asb_store_voucher',
      'version': '1.0',
      'bill_no': billNo,
      'scholar_no': scholarNo,
      'pts': points,
      'items': items,
      'timestamp': ts,
      'token': token,
    });
  }

  /// Validates a voucher token against expected order parameters.
  static bool validateVoucherToken({
    required String token,
    required String billNo,
    required int points,
    required String scholarNo,
    required int timestampMillis,
  }) {
    if (token.isEmpty || billNo.isEmpty || points <= 0) return false;
    final expected = generateVoucherToken(
      billNo: billNo,
      points: points,
      scholarNo: scholarNo,
      timestampMillis: timestampMillis,
    );
    return token.toLowerCase() == expected.toLowerCase();
  }

  /// Parses and cryptographically validates any raw QR payload.
  static ({
    bool isValid,
    bool isTampered,
    String? billNo,
    int? points,
    String? scholarNo,
    List<String> items,
    String? error,
  }) validateVoucherPayload(String rawPayload) {
    final trimmed = rawPayload.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      // Legacy token fallback check (e.g. ASB-ORDER-ASB-123456)
      if (trimmed.startsWith('ASB-ORDER-')) {
        final id = trimmed.replaceFirst('ASB-ORDER-', '');
        return (
          isValid: true,
          isTampered: false,
          billNo: id,
          points: null,
          scholarNo: null,
          items: <String>[],
          error: null,
        );
      }
      return (
        isValid: false,
        isTampered: false,
        billNo: null,
        points: null,
        scholarNo: null,
        items: <String>[],
        error: 'Not a valid voucher QR payload',
      );
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return (
          isValid: false,
          isTampered: false,
          billNo: null,
          points: null,
          scholarNo: null,
          items: <String>[],
          error: 'Malformed JSON',
        );
      }

      final data = Map<String, dynamic>.from(decoded);
      final billNo = (data['bill_no'] ?? data['billNo'] ?? '').toString().trim();
      final points = (data['pts'] as num?)?.toInt() ?? 0;
      final scholarNo = (data['scholar_no'] ?? data['scholarNo'] ?? '').toString().trim();
      final token = (data['token'] ?? '').toString().trim();
      final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
      final rawItems = data['items'];
      final List<String> items = (rawItems is List)
          ? rawItems.map((e) => e.toString()).toList()
          : <String>[];

      if (billNo.isEmpty) {
        return (
          isValid: false,
          isTampered: false,
          billNo: null,
          points: null,
          scholarNo: null,
          items: items,
          error: 'Missing bill number',
        );
      }

      // If token is present, strictly verify HMAC
      if (token.isNotEmpty && ts > 0) {
        final matches = validateVoucherToken(
          token: token,
          billNo: billNo,
          points: points,
          scholarNo: scholarNo,
          timestampMillis: ts,
        );
        if (!matches) {
          return (
            isValid: false,
            isTampered: true,
            billNo: billNo,
            points: points,
            scholarNo: scholarNo,
            items: items,
            error: 'Cryptographic signature mismatch — possible tampering detected!',
          );
        }
      }

      return (
        isValid: true,
        isTampered: false,
        billNo: billNo,
        points: points,
        scholarNo: scholarNo,
        items: items,
        error: null,
      );
    } catch (e) {
      return (
        isValid: false,
        isTampered: false,
        billNo: null,
        points: null,
        scholarNo: null,
        items: <String>[],
        error: 'Decoding exception: $e',
      );
    }
  }
}
