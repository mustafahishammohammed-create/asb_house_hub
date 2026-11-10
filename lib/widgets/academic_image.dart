import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Renders a base64 data-URL or network image with a broken-image fallback.
Widget buildAcademicImage(String imageUrl, {BoxFit fit = BoxFit.cover}) {
  if (imageUrl.startsWith('data:image')) {
    try {
      return Image.memory(
        base64Decode(imageUrl.split(',').last),
        fit: fit,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.grey),
        ),
      );
    } catch (_) {
      return const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey));
    }
  }
  return Image.network(
    imageUrl,
    fit: fit,
    errorBuilder: (_, _, _) => const Center(
      child: Icon(Icons.broken_image_rounded, color: Colors.grey),
    ),
  );
}

/// Full-screen zoomable preview for an attached academic photo.
void showAcademicImagePreview(BuildContext context, String imageUrl, String title) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Semantics(
                button: true,
                label: 'Save image to device',
                child: IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  tooltip: 'Save image to device',
                  onPressed: () async {
                    try {
                      Uint8List? bytes;
                      if (imageUrl.startsWith('data:image')) {
                        bytes = base64Decode(imageUrl.split(',').last);
                      } else {
                        final res = await http.get(Uri.parse(imageUrl));
                        if (res.statusCode == 200) {
                          bytes = res.bodyBytes;
                        }
                      }
                      if (bytes != null) {
                        final fileName = 'ASB_Image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                        final targetDir = io.Directory.systemTemp.path;
                        final file = io.File('$targetDir${io.Platform.pathSeparator}$fileName');
                        await file.writeAsBytes(bytes, flush: true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✓ Image saved: ${file.path}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to save image: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              Semantics(
                button: true,
                label: 'Close dialog',
                child: IconButton(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: buildAcademicImage(imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pinch or drag to zoom',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

/// Camera/gallery photo picker with compression, preview and remove.
/// [onChanged] receives a base64 data URL, or null when the photo is removed.
class AcademicImageUploadField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const AcademicImageUploadField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final xfile = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        onChanged('data:image/jpeg;base64,${base64Encode(bytes)}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('${source == ImageSource.camera ? 'Camera' : 'Gallery'} unavailable: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (hasPhoto)
              TextButton(
                onPressed: () => onChanged(null),
                child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (hasPhoto)
          InkWell(
            onTap: () => showAcademicImagePreview(context, value!, label),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: buildAcademicImage(value!),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                  label: const Text('Take Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                  label: const Text('Upload Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Tappable thumbnail shown on cards that carry an attached photo.
class AcademicImageThumbnail extends StatelessWidget {
  final String imageUrl;
  final String title;
  final double height;

  const AcademicImageThumbnail({
    super.key,
    required this.imageUrl,
    required this.title,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showAcademicImagePreview(context, imageUrl, title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4), width: 1.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: buildAcademicImage(imageUrl),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('View Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}