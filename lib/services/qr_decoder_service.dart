import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Pure Dart cross-platform QR code decoder service.
/// Operates without platform channels or native camera dependencies,
/// enabling reliable QR decoding on Windows desktop, macOS, Linux, Web, and mobile.
class QrDecoderService {
  /// Decodes a QR code from raw image bytes using pure Dart ZXing.
  static Future<String?> decodeQrFromBytes(Uint8List bytes) async {
    try {
      // Decode image using pure Dart 'image' package
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final width = image.width;
      final height = image.height;
      final Int32List pixels = Int32List(width * height);

      int index = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final p = image.getPixel(x, y);
          final r = p.r.toInt();
          final g = p.g.toInt();
          final b = p.b.toInt();
          // Pack into ARGB format expected by RGBLuminanceSource
          pixels[index++] = (0xFF << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | (b & 0xFF);
        }
      }

      final source = RGBLuminanceSource(width, height, pixels);
      final reader = QRCodeReader();

      // Attempt 1: HybridBinarizer (adaptive thresholding)
      try {
        final bitmap = BinaryBitmap(HybridBinarizer(source));
        final result = reader.decode(bitmap);
        if (result.text.isNotEmpty) {
          return result.text;
        }
      } catch (_) {}

      // Attempt 2: GlobalHistogramBinarizer fallback (for lower-contrast images)
      try {
        final bitmap = BinaryBitmap(GlobalHistogramBinarizer(source));
        final result = reader.decode(bitmap);
        if (result.text.isNotEmpty) {
          return result.text;
        }
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('Pure Dart QR decode error: $e');
      return null;
    }
  }
}
