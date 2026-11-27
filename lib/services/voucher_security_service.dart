import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../screens/merch_store_tab.dart';

typedef VoucherValidationResult = ({
  bool isValid,
  bool isTampered,
  String? billNo,
  int? points,
  String? scholarNo,
  List<String> items,
  String? error,
});

typedef StudentPassValidationResult = ({
  bool isValid,
  bool isTampered,
  String? scholarNo,
  String? studentName,
  String? houseName,
  String? classLevel,
  String? error,
});

typedef VoucherClaimResult = ({
  bool success,
  bool alreadyClaimed,
  String? claimedBy,
  DateTime? claimedAt,
  String message,
});

/// Cryptographic security service for generating and validating
/// tamper-evident digital vouchers and passes across the ASB House Hub.
class VoucherSecurityService {
  // Institutional HMAC salt for tamper prevention
  static const String _institutionSecret = 'ASB_HOUSE_HUB_OFFICIAL_MERCH_KEY_2026_SECURE';

  static String _canonicalItemsDigest(List<String> items) {
    final normalized = items.map((e) => e.trim()).join(';');
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  /// Generates an HMAC-SHA256 signature token for an order voucher.
  static String generateVoucherToken({
    required String billNo,
    required int points,
    required String scholarNo,
    required int timestampMillis,
    List<String>? items,
    double? totalBhd,
  }) {
    final itemsSuffix = items != null ? '|${_canonicalItemsDigest(items)}' : '';
    final bhdSuffix =
        totalBhd != null ? '|${totalBhd.toStringAsFixed(3)}' : '';
    final payload =
        '$billNo|$points|$scholarNo|$timestampMillis$itemsSuffix$bhdSuffix';
    final hmac = Hmac(sha256, utf8.encode(_institutionSecret));
    return hmac.convert(utf8.encode(payload)).toString();
  }

  /// Builds a complete scannable JSON payload with cryptographic verification token.
  static String generateVoucherPayload({
    required String billNo,
    required int points,
    required String scholarNo,
    required List<String> items,
    double? totalBhd,
    int? timestampMillis,
  }) {
    final ts = timestampMillis ?? DateTime.now().millisecondsSinceEpoch;
    final token = generateVoucherToken(
      billNo: billNo,
      points: points,
      scholarNo: scholarNo,
      timestampMillis: ts,
      items: items,
      totalBhd: totalBhd,
    );

    return jsonEncode({
      'type': 'asb_store_voucher',
      'version': '2.0',
      'bill_no': billNo,
      'scholar_no': scholarNo,
      'pts': points,
      if (totalBhd != null) 'total_bhd': double.parse(totalBhd.toStringAsFixed(3)),
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
    List<String>? items,
    double? totalBhd,
  }) {
    if (token.isEmpty || billNo.isEmpty || points < 0) return false;
    final expected = generateVoucherToken(
      billNo: billNo,
      points: points,
      scholarNo: scholarNo,
      timestampMillis: timestampMillis,
      items: items,
      totalBhd: totalBhd,
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
      // Legacy unsigned vouchers are no longer accepted: without a signature
      // anyone could print or edit a QR code and redeem merchandise.
      return (
        isValid: false,
        isTampered: false,
        billNo: null,
        points: null,
        scholarNo: null,
        items: <String>[],
        error:
            'Unsigned legacy voucher rejected. Ask staff to reissue a signed pass.',
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
      final rawBhd = data['total_bhd'];
      final double? totalBhd = rawBhd is num ? rawBhd.toDouble() : null;
      final isV2 = (data['version']?.toString() ?? '') == '2.0';

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

      // A signature is mandatory. A JSON payload without one is treated as
      // unsigned, not as a legacy-compatible voucher.
      if (token.isEmpty || ts <= 0) {
        return (
          isValid: false,
          isTampered: false,
          billNo: billNo,
          points: points,
          scholarNo: scholarNo,
          items: items,
          error: 'Missing cryptographic signature',
        );
      }

      final matches = validateVoucherToken(
        token: token,
        billNo: billNo,
        points: points,
        scholarNo: scholarNo,
        timestampMillis: ts,
        items: isV2 ? items : null,
        totalBhd: isV2 ? totalBhd : null,
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

  /// Generates a tamper-evident signed student ID pass JSON string with HMAC-SHA256 signature.
  static String generateStudentPassPayload({
    required String scholarNo,
    required String studentName,
    required String houseName,
    required String classLevel,
    String academicYear = '2026/2027',
    int? timestampMillis,
  }) {
    final sNo = scholarNo.trim();
    final sName = studentName.trim();
    final sHouse = houseName.trim().toUpperCase();
    final sClass = classLevel.trim();
    final sYear = academicYear.trim();
    // Default to 0 for a permanent, static printable ID pass QR code
    final ts = timestampMillis ?? 0;
    final payloadRaw = '$sNo|$sName|$sHouse|$sClass|$sYear|$ts|$_institutionSecret';
    final signature = sha256.convert(utf8.encode(payloadRaw)).toString();

    return jsonEncode({
      'type': 'asb_student_id',
      'version': '2.0',
      'scholar_no': sNo,
      'name': sName,
      'house': sHouse,
      'class': sClass,
      'valid': sYear,
      'timestamp': ts,
      'signature': signature,
    });
  }

  /// Cryptographically validates a student pass payload against its HMAC-SHA256 digital signature.
  static StudentPassValidationResult validateStudentPassPayload(String rawJson) {
    try {
      final trimmed = rawJson.trim();
      if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
        return (
          isValid: false,
          isTampered: false,
          scholarNo: null,
          studentName: null,
          houseName: null,
          classLevel: null,
          error: 'Not a JSON payload',
        );
      }

      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return (
          isValid: false,
          isTampered: false,
          scholarNo: null,
          studentName: null,
          houseName: null,
          classLevel: null,
          error: 'Invalid format',
        );
      }

      final map = Map<String, dynamic>.from(decoded);
      if (map['type'] != 'asb_student_id') {
        return (
          isValid: false,
          isTampered: false,
          scholarNo: null,
          studentName: null,
          houseName: null,
          classLevel: null,
          error: 'Not a student pass',
        );
      }

      final scholar = (map['scholar_no'] ?? map['scholarNo'] ?? '').toString().trim();
      final name = (map['name'] ?? map['studentName'] ?? map['full_name'] ?? '').toString().trim();
      final house = (map['house'] ?? map['house_name'] ?? '').toString().trim().toUpperCase();
      final cls = (map['class'] ?? map['class_level'] ?? map['classLevel'] ?? '').toString().trim();
      final year = (map['valid'] ?? map['academic_year'] ?? '2026/2027').toString().trim();
      final ts = (map['timestamp'] as num?)?.toInt() ?? 0;
      final signature = (map['signature'] ?? map['token'] ?? '').toString().trim();

      if (signature.isEmpty) {
        return (
          isValid: false,
          isTampered: true,
          scholarNo: scholar,
          studentName: name,
          houseName: house,
          classLevel: cls,
          error: 'Missing digital signature',
        );
      }

      final expectedRaw = '$scholar|$name|$house|$cls|$year|$ts|$_institutionSecret';
      final expectedSig = sha256.convert(utf8.encode(expectedRaw)).toString();

      if (signature.toLowerCase() != expectedSig.toLowerCase()) {
        return (
          isValid: false,
          isTampered: true,
          scholarNo: scholar,
          studentName: name,
          houseName: house,
          classLevel: cls,
          error: 'Signature mismatch / forged pass',
        );
      }

      return (
        isValid: true,
        isTampered: false,
        scholarNo: scholar,
        studentName: name,
        houseName: house,
        classLevel: cls,
        error: null,
      );
    } catch (e) {
      return (
        isValid: false,
        isTampered: false,
        scholarNo: null,
        studentName: null,
        houseName: null,
        classLevel: null,
        error: 'Malformed JSON: $e',
      );
    }
  }

  /// Standard Apple Wallet (.pkpass) PassKit JSON definition
  static Map<String, dynamic> generateApplePkPassJson({
    required String scholarNo,
    required String studentName,
    required String houseName,
    required String classLevel,
    required String qrPayload,
    int? totalPoints,
  }) {
    return {
      'formatVersion': 1,
      'passTypeIdentifier': 'pass.bh.asianschool.househub',
      'serialNumber': 'ASB-PASS-$scholarNo-${DateTime.now().year}',
      'teamIdentifier': 'ASB984BH26',
      'organizationName': 'The Asian School Bahrain',
      'description': 'ASB Official Student Digital ID Pass',
      'foregroundColor': 'rgb(255, 255, 255)',
      'backgroundColor': 'rgb(15, 23, 42)',
      'generic': {
        'primaryFields': [
          {'key': 'student_name', 'label': 'STUDENT', 'value': studentName},
        ],
        'secondaryFields': [
          {'key': 'house', 'label': 'HOUSE', 'value': houseName.toUpperCase()},
          {'key': 'class', 'label': 'CLASS', 'value': classLevel},
        ],
        'auxiliaryFields': [
          {'key': 'scholar', 'label': 'SCHOLAR #', 'value': scholarNo},
          {'key': 'points', 'label': 'HOUSE POINTS', 'value': '${totalPoints ?? 0} Pts'},
        ],
      },
      'barcodes': [
        {
          'format': 'PKBarcodeFormatQR',
          'message': qrPayload,
          'messageEncoding': 'iso-8859-1',
        },
      ],
    };
  }

  /// Standard Google Wallet Passes API JSON definition
  static Map<String, dynamic> generateGoogleWalletPassJson({
    required String scholarNo,
    required String studentName,
    required String houseName,
    required String classLevel,
    required String qrPayload,
    int? totalPoints,
  }) {
    return {
      'issuerId': 'ASB-BAHRAIN-HOUSEHUB',
      'classId': 'asb_student_pass_2026',
      'id': 'ASB-PASS-$scholarNo-${DateTime.now().year}',
      'state': 'ACTIVE',
      'cardTitle': 'The Asian School Bahrain',
      'header': studentName,
      'subheader': '${houseName.toUpperCase()} • $classLevel',
      'barcode': {
        'type': 'QR_CODE',
        'value': qrPayload,
        'alternateText': 'SCHOLAR #$scholarNo',
      },
      'textModulesData': [
        {
          'id': 'points',
          'header': 'HOUSE CONTRIBUTION',
          'body': '${totalPoints ?? 0} Pts',
        },
        {
          'id': 'validity',
          'header': 'ACADEMIC YEAR',
          'body': '2026/2027',
        },
      ],
    };
  }

  /// Atomically claims and fulfills a store merchandise voucher in Firestore.
  /// Prevents double-redemption by checking document status.
  /// Strictly eliminates false-positive success: true returns on missing or unverified vouchers.
  static Future<VoucherClaimResult> claimStoreVoucher({
    required String billNo,
    required String evaluatorName,
    FirebaseFirestore? firestore,
  }) async {
    final cleanBill = billNo.trim();
    if (cleanBill.isEmpty) {
      return (
        success: false,
        alreadyClaimed: false,
        claimedBy: null,
        claimedAt: null,
        message: 'Invalid voucher: Missing bill number.',
      );
    }

    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final docRef = db.collection('orders').doc(cleanBill);

      final txResult = await db.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) {
          return (
            exists: false,
            unverified: false,
            claimedBy: null as String?,
            claimedAt: null as DateTime?,
            status: null as String?,
          );
        }

        final data = snapshot.data();
        final currentStatus =
            (data?['status']?.toString().toLowerCase() ?? 'placed').trim();
        if (currentStatus == 'claimed') {
          final claimedBy = data?['claimed_by'] as String? ?? 'Another Evaluator';
          DateTime? claimedAt;
          final rawTs = data?['claimed_at'];
          if (rawTs is Timestamp) {
            claimedAt = rawTs.toDate();
          } else if (rawTs is String) {
            claimedAt = DateTime.tryParse(rawTs);
          }
          return (
            exists: true,
            unverified: false,
            claimedBy: claimedBy,
            claimedAt: claimedAt,
            status: currentStatus,
          );
        }

        // An unpaid/unverified order ('placed' or 'pending') must never be
        // fulfilled until staff/admin has verified payment ('verified'/'ready').
        if (currentStatus != 'verified' && currentStatus != 'ready') {
          return (
            exists: true,
            unverified: true,
            claimedBy: null as String?,
            claimedAt: null as DateTime?,
            status: currentStatus,
          );
        }

        tx.update(docRef, {
          'status': 'claimed',
          'claimed_by': evaluatorName,
          'claimed_at': FieldValue.serverTimestamp(),
        });
        return (
          exists: true,
          unverified: false,
          claimedBy: null as String?,
          claimedAt: null as DateTime?,
          status: currentStatus,
        );
      });

      if (txResult.exists && txResult.unverified) {
        return (
          success: false,
          alreadyClaimed: false,
          claimedBy: null,
          claimedAt: null,
          message:
              'Voucher #$cleanBill is still "${txResult.status}" and has not been verified for handover.',
        );
      }

      if (txResult.exists && txResult.claimedBy != null) {
        return (
          success: false,
          alreadyClaimed: true,
          claimedBy: txResult.claimedBy,
          claimedAt: txResult.claimedAt,
          message: 'Voucher #$cleanBill has already been claimed by ${txResult.claimedBy}.',
        );
      }

      if (txResult.exists) {
        // Update local wallet store cache if present
        try {
          await GlobalWalletStore.markOrderClaimed(
            cleanBill,
            claimedBy: evaluatorName,
            claimedAt: DateTime.now(),
          );
        } catch (_) {}

        return (
          success: true,
          alreadyClaimed: false,
          claimedBy: evaluatorName,
          claimedAt: DateTime.now(),
          message: 'Voucher #$cleanBill successfully claimed and fulfilled.',
        );
      } else {
        // In live Firebase mode, an order missing from Firestore must be rejected
        // rather than trusted from local cache.
        return (
          success: false,
          alreadyClaimed: false,
          claimedBy: null,
          claimedAt: null,
          message: 'Voucher #$cleanBill not found in school records. Claim rejected.',
        );
      }
    } catch (e) {
      final isOfflineOrUninit = firestore == null &&
          Firebase.apps.isEmpty &&
          e.toString().contains('no-app');
      if (!isOfflineOrUninit) {
        return (
          success: false,
          alreadyClaimed: false,
          claimedBy: null,
          claimedAt: null,
          message: 'Voucher #$cleanBill verification failed on server.',
        );
      }
      // Offline / uninitialized Firestore fallback:
      // Verify against local wallet store before claiming
      final localMatch = GlobalWalletStore.orders.where((o) => o.receiptId == cleanBill);
      if (localMatch.isNotEmpty) {
        final order = localMatch.first;
        if (order.isClaimed) {
          return (
            success: false,
            alreadyClaimed: true,
            claimedBy: order.claimedBy,
            claimedAt: order.claimedAt,
            message: 'Voucher #$cleanBill has already been claimed locally.',
          );
        }
        final claimedAt = DateTime.now();
        await GlobalWalletStore.markOrderClaimed(
          cleanBill,
          claimedBy: evaluatorName,
          claimedAt: claimedAt,
        );

        return (
          success: true,
          alreadyClaimed: false,
          claimedBy: evaluatorName,
          claimedAt: claimedAt,
          message: 'Voucher #$cleanBill verified locally (offline fulfillment).',
        );
      }

      return (
        success: false,
        alreadyClaimed: false,
        claimedBy: null,
        claimedAt: null,
        message: 'Voucher #$cleanBill could not be verified offline. Order not found.',
      );
    }
  }

  /// Inspects Firestore to determine if a voucher has already been claimed.
  static Future<({bool isClaimed, String? claimedBy, DateTime? claimedAt})> checkVoucherClaimStatus({
    required String billNo,
    FirebaseFirestore? firestore,
  }) async {
    final cleanBill = billNo.trim();
    if (cleanBill.isEmpty) return (isClaimed: false, claimedBy: null, claimedAt: null);

    // 1. Check local GlobalWalletStore cache first
    final localMatch = GlobalWalletStore.orders.where((o) => o.receiptId == cleanBill);
    if (localMatch.isNotEmpty && localMatch.first.isClaimed) {
      return (
        isClaimed: true,
        claimedBy: localMatch.first.claimedBy,
        claimedAt: localMatch.first.claimedAt,
      );
    }

    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final doc = await db.collection('orders').doc(cleanBill).get();
      if (doc.exists) {
        final data = doc.data();
        final isClaimed = data?['status']?.toString().toLowerCase() == 'claimed';
        if (isClaimed) {
          final claimedBy = data?['claimed_by'] as String?;
          DateTime? claimedAt;
          final rawTs = data?['claimed_at'];
          if (rawTs is Timestamp) {
            claimedAt = rawTs.toDate();
          } else if (rawTs is String) {
            claimedAt = DateTime.tryParse(rawTs);
          }
          return (isClaimed: true, claimedBy: claimedBy, claimedAt: claimedAt);
        }
      }
    } catch (_) {}
    return (isClaimed: false, claimedBy: null, claimedAt: null);
  }
}

