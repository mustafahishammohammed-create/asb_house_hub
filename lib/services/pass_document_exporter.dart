import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io' as io;

/// Zero-dependency institutional PDF pass generation and disk export engine.
class PassDocumentExporter {
  /// Pure Dart standard PDF 1.4 byte builder for voucher & electronic passes
  static Uint8List buildPassPdf({
    required String title,
    required String subtitle,
    required String details,
    required String totalInfo,
    required String qrData,
  }) {
    String sanitize(String s) =>
        s.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)');

    final content = StringBuffer();
    content.writeln('BT');
    content.writeln('/F1 18 Tf');
    content.writeln('50 740 Td');
    content.writeln('(${sanitize("ASB HOUSE HUB - OFFICIAL ELECTRONIC PASS")}) Tj');
    content.writeln('/F1 13 Tf');
    content.writeln('0 -30 Td');
    content.writeln('(${sanitize(title)}) Tj');
    content.writeln('/F1 11 Tf');
    content.writeln('0 -22 Td');
    content.writeln('(${sanitize(subtitle)}) Tj');
    content.writeln('0 -22 Td');
    for (final line in details.split('\n')) {
      content.writeln('(${sanitize(line)}) Tj');
      content.writeln('0 -16 Td');
    }
    content.writeln('0 -12 Td');
    content.writeln('/F1 12 Tf');
    content.writeln('(${sanitize(totalInfo)}) Tj');
    content.writeln('/F1 9 Tf');
    content.writeln('0 -24 Td');
    content.writeln('(Verification Hash: ${sanitize(qrData)}) Tj');
    content.writeln('0 -14 Td');
    content.writeln('(Timestamp: ${DateTime.now().toUtc().toIso8601String()}) Tj');
    content.writeln('ET');

    final streamBytes = utf8.encode(content.toString());

    final body = StringBuffer();
    body.writeln('%PDF-1.4');

    final offsets = <int>[];

    // 1 0 obj: Catalog
    offsets.add(utf8.encode(body.toString()).length);
    body.writeln('1 0 obj');
    body.writeln('<< /Type /Catalog /Pages 2 0 R >>');
    body.writeln('endobj');

    // 2 0 obj: Pages
    offsets.add(utf8.encode(body.toString()).length);
    body.writeln('2 0 obj');
    body.writeln('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    body.writeln('endobj');

    // 3 0 obj: Page
    offsets.add(utf8.encode(body.toString()).length);
    body.writeln('3 0 obj');
    body.writeln(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>');
    body.writeln('endobj');

    // 4 0 obj: Stream
    offsets.add(utf8.encode(body.toString()).length);
    body.writeln('4 0 obj');
    body.writeln('<< /Length ${streamBytes.length} >>');
    body.writeln('stream');
    body.write(content.toString());
    body.writeln('endstream');
    body.writeln('endobj');

    // 5 0 obj: Font
    offsets.add(utf8.encode(body.toString()).length);
    body.writeln('5 0 obj');
    body.writeln('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    body.writeln('endobj');

    // XRef
    final startXref = utf8.encode(body.toString()).length;
    body.writeln('xref');
    body.writeln('0 6');
    body.writeln('0000000000 65535 f ');
    for (final offset in offsets) {
      body.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
    }
    body.writeln('trailer');
    body.writeln('<< /Size 6 /Root 1 0 R >>');
    body.writeln('startxref');
    body.writeln('$startXref');
    body.writeln('%%EOF');

    return Uint8List.fromList(utf8.encode(body.toString()));
  }

  /// Writes generated PDF bytes to the downloads directory or application documents,
  /// returning the resolved output file path.
  static Future<({bool success, String filePath, String? error})> exportPass({
    required String title,
    required String subtitle,
    required String details,
    required String totalInfo,
    required String qrData,
    String? customPath,
  }) =>
      exportPassToDisk(
        title: title,
        subtitle: subtitle,
        details: details,
        totalInfo: totalInfo,
        qrData: qrData,
        customPath: customPath,
      );

  static Future<({bool success, String filePath, String? error})> exportPassToDisk({
    required String title,
    required String subtitle,
    required String details,
    required String totalInfo,
    required String qrData,
    String? customPath,
  }) async {
    try {
      final bytes = buildPassPdf(
        title: title,
        subtitle: subtitle,
        details: details,
        totalInfo: totalInfo,
        qrData: qrData,
      );

      if (kIsWeb) {
        return (
          success: true,
          filePath: 'browser_download:ASB_Pass_${DateTime.now().millisecondsSinceEpoch}.pdf',
          error: null,
        );
      }

      String targetDir;
      if (customPath != null && customPath.isNotEmpty) {
        targetDir = customPath;
      } else if (io.Platform.isWindows) {
        final profile = io.Platform.environment['USERPROFILE'];
        final dl = profile != null ? io.Directory('$profile\\Downloads') : null;
        targetDir = (dl != null && dl.existsSync()) ? dl.path : io.Directory.systemTemp.path;
      } else if (io.Platform.isMacOS || io.Platform.isLinux) {
        final home = io.Platform.environment['HOME'];
        final dl = home != null ? io.Directory('$home/Downloads') : null;
        targetDir = (dl != null && dl.existsSync()) ? dl.path : io.Directory.systemTemp.path;
      } else if (io.Platform.isAndroid) {
        // Safe against Android 10+ (API 29+) Scoped Storage restrictions
        targetDir = io.Directory.systemTemp.path;
      } else {
        targetDir = io.Directory.systemTemp.path;
      }

      final fileName = 'ASB_Pass_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = io.File('$targetDir${io.Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (await file.exists()) {
        return (success: true, filePath: file.path, error: null);
      } else {
        return (success: false, filePath: '', error: 'File verification failed on disk.');
      }
    } catch (e) {
      return (success: false, filePath: '', error: e.toString());
    }
  }
}
