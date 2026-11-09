import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/school_notice.dart';

typedef CircularPublishCallback = Future<SchoolNoticePublishResult> Function({
  required String title,
  required String content,
  required String category,
  required String targetAudience,
  PickedCircularPdf? pdf,
});

typedef CircularPdfPicker = Future<PickedCircularPdf?> Function();

/// Admin composer for an official school circular/notice.
///
/// The sheet only closes after [onPublish] returns a successful result. A
/// Storage upload failure or a Firestore rules denial keeps the sheet open and
/// shows the real error instead of claiming a phantom success.
class SchoolCircularComposer extends StatefulWidget {
  final bool isDark;
  final CircularPublishCallback onPublish;
  final CircularPdfPicker? pickPdf;

  const SchoolCircularComposer({
    super.key,
    required this.isDark,
    required this.onPublish,
    this.pickPdf,
  });

  @override
  State<SchoolCircularComposer> createState() => _SchoolCircularComposerState();
}

class _SchoolCircularComposerState extends State<SchoolCircularComposer> {
  static const List<String> _categories = [
    'Academic',
    'Sports',
    'Examination',
    'Holiday & Closure',
    'General',
  ];
  static const List<String> _audiences = [
    'All Students',
    'Middle School (6-8)',
    'Secondary (9-10)',
    'Senior Secondary (11-12)',
  ];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _category = 'Academic';
  String _audience = 'All Students';
  PickedCircularPdf? _pdf;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<PickedCircularPdf?> _defaultPickPdf() async {
    const typeGroup = XTypeGroup(
      label: 'PDF circular',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return PickedCircularPdf(bytes: bytes, fileName: file.name);
  }

  Future<void> _pickPdf() async {
    if (_busy) return;
    setState(() => _error = null);
    try {
      final picked = await (widget.pickPdf ?? _defaultPickPdf)();
      if (picked == null) return;
      if (picked.bytes.isEmpty) {
        setState(() => _error = 'The selected PDF is empty.');
        return;
      }
      if (picked.bytes.length > kMaxSchoolCircularPdfBytes) {
        setState(
          () => _error =
              'The PDF is larger than 15 MB. Please compress it and try again.',
        );
        return;
      }
      setState(() => _pdf = picked);
    } catch (_) {
      setState(() => _error = 'Could not read the selected PDF.');
    }
  }

  Future<void> _publish() async {
    if (_busy) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a circular title.');
      return;
    }
    if (content.isEmpty && _pdf == null) {
      setState(() => _error = 'Enter circular details or attach a PDF.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    SchoolNoticePublishResult result;
    try {
      result = await widget.onPublish(
        title: title,
        content: content,
        category: _category,
        targetAudience: _audience,
        pdf: _pdf,
      );
    } catch (_) {
      result = SchoolNoticePublishResult.failure(
        'Could not publish the circular. Please try again.',
      );
    }

    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.error ?? 'Could not publish the circular.';
    });
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  InputDecoration _fieldDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: widget.isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildPdfPicker() {
    final pdf = _pdf;
    if (pdf == null) {
      return OutlinedButton.icon(
        key: const Key('circular_pdf_picker'),
        onPressed: _busy ? null : _pickPdf,
        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: const Text(
          'Attach PDF Circular (max 15 MB)',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return Container(
      key: const Key('circular_pdf_preview'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pdf.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatSize(pdf.sizeBytes),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('circular_remove_pdf'),
            onPressed: _busy ? null : () => setState(() => _pdf = null),
            tooltip: 'Remove PDF',
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📢 Post School Circular & Notice',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Publish official circular details and an optional PDF to all students and faculty.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('circular_title_field'),
              controller: _titleController,
              enabled: !_busy,
              maxLength: 200,
              decoration: _fieldDecoration(
                'Circular Title',
                hint: 'e.g. Mid-Term Examination Conduct & Guidelines',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const Key('circular_category_field'),
                    initialValue: _category,
                    decoration: _fieldDecoration('Category'),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _category = value);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: const Key('circular_audience_field'),
                    initialValue: _audience,
                    decoration: _fieldDecoration('Audience'),
                    items: _audiences
                        .map(
                          (a) => DropdownMenuItem(
                            value: a,
                            child: Text(a, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _audience = value);
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('circular_content_field'),
              controller: _contentController,
              enabled: !_busy,
              maxLines: 4,
              maxLength: 5000,
              decoration: _fieldDecoration(
                'Circular Details',
                hint: 'Enter the full circular text. A PDF is optional.',
              ),
            ),
            const SizedBox(height: 8),
            _buildPdfPicker(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('circular_error_banner'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('publish_circular_button'),
                onPressed: _busy ? null : _publish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4338CA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Broadcast Circular',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
