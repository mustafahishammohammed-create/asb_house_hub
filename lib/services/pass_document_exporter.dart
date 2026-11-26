import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io' as io;

/// Institutional PDF pass generation and disk export engine with embedded vector QR codes.
class PassDocumentExporter {
  /// Pure Dart standard PDF 1.4 byte builder with scannable vector QR rendering
  static Uint8List buildPassPdf({
    required String title,
    required String subtitle,
    required String details,
    required String totalInfo,
    required String qrData,
  }) {
    String sanitize(String s) {
      final ascii = StringBuffer();
      for (final unit in s.codeUnits) {
        ascii.writeCharCode((unit >= 32 && unit <= 126) ? unit : 32);
      }
      return ascii
          .toString()
          .replaceAll('\\', '\\\\')
          .replaceAll('(', '\\(')
          .replaceAll(')', '\\)');
    }

    final content = StringBuffer();

    // Render scannable vector QR code in upper-right quadrant (x=420..560, y=612..752)
    if (qrData.trim().isNotEmpty) {
      try {
        final qrCode = QrCode.fromData(
          data: qrData.trim(),
          errorCorrectLevel: QrErrorCorrectLevel.M,
        );
        final qrImage = QrImage(qrCode);
        final modules = qrImage.moduleCount;
        const qrSize = 140.0;
        const originX = 420.0;
        const originY = 612.0;
        final cell = qrSize / modules;

        content.writeln('q');
        // White quiet zone
        content.writeln('1 1 1 rg');
        content.writeln(
          '${(originX - 8).toStringAsFixed(2)} ${(originY - 8).toStringAsFixed(2)} '
          '${(qrSize + 16).toStringAsFixed(2)} ${(qrSize + 16).toStringAsFixed(2)} re f',
        );
        // Dark QR modules
        content.writeln('0 0 0 rg');
        for (var r = 0; r < modules; r++) {
          for (var c = 0; c < modules; c++) {
            if (qrImage.isDark(r, c)) {
              final x = originX + c * cell;
              final y = originY + (modules - 1 - r) * cell;
              content.writeln(
                '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} '
                '${cell.toStringAsFixed(2)} ${cell.toStringAsFixed(2)} re f',
              );
            }
          }
        }
        content.writeln('Q');
      } catch (e) {
        debugPrint('PassDocumentExporter QR vector warning: $e');
      }
    }

    content.writeln('BT');
    content.writeln('0 0 0 rg');
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
    content.writeln('(Verification Payload: ${sanitize(qrData)}) Tj');
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
          success: false,
          filePath: '',
          error: 'PDF download is not available in the web app yet.',
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
