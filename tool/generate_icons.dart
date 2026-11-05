import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('Crystal_gemstone_app_icon_design_2K_20261004203115.jpg');
  if (!file.existsSync()) {
    print('Error: 2K source image not found!');
    return;
  }

  print('Reading 2K high-definition source: ${file.path} (${file.lengthSync()} bytes)...');
  final src = img.decodeImage(file.readAsBytesSync())!;
  print('Source dimensions: ${src.width}x${src.height}');

  // In the 2048x2048 2K image, the squircle app icon frame is centered at (1024, 1024).
  // The outer squircle bounding box spans from x=180, y=180 to x=1868, y=1868 (size 1688x1688).
  // This gives the perfect squircle edge alignment without clipping the 3D crystal gemstone shield or text.
  const cropSize = 1688;
  const cropX = 180;
  const cropY = 180;

  final croppedSquircle = img.copyCrop(
    src,
    x: cropX,
    y: cropY,
    width: cropSize,
    height: cropSize,
  );

  // 1. Generate master in-app assets:
  // - assets/images/app_logo_modern.png (1024x1024 master HD PNG)
  final logo1024 = img.copyResize(
    croppedSquircle,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );
  
  final logoFile = File('assets/images/app_logo_modern.png');
  logoFile.parent.createSync(recursive: true);
  logoFile.writeAsBytesSync(img.encodePng(logo1024));
  print('Generated ultra-sharp ${logoFile.path} (1024x1024 HD PNG)');

  // 2. Generate Android launcher mipmap icons across all DPI buckets
  final mipmaps = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in mipmaps.entries) {
    final resized = img.copyResize(
      croppedSquircle,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    final target = File(entry.key);
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(img.encodePng(resized));
    print('Generated ${entry.key} (${entry.value}x${entry.value})');
  }

  print('All 2K crystal gemstone app icons generated successfully!');
}
