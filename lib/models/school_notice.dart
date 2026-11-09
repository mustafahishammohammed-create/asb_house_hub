import 'dart:typed_data';

/// Hard ceiling for a circular PDF. Firebase Storage allows 15 MB on the
/// existing academic-resource path, so the circular path uses the same limit.
const int kMaxSchoolCircularPdfBytes = 15 * 1024 * 1024;

/// A PDF selected by an administrator and not yet uploaded.
class PickedCircularPdf {
  final Uint8List bytes;
  final String fileName;

  const PickedCircularPdf({required this.bytes, required this.fileName});

  int get sizeBytes => bytes.length;
}

/// Truthful outcome of publishing a school notice/circular.
///
/// A failed upload or a denied Firestore write must never be reported as a
/// success. The composer keeps its sheet open and shows [error] instead.
class SchoolNoticePublishResult {
  final bool success;
  final String? noticeId;
  final String? attachmentUrl;
  final String? error;

  const SchoolNoticePublishResult._({
    required this.success,
    this.noticeId,
    this.attachmentUrl,
    this.error,
  });

  factory SchoolNoticePublishResult.success({
    required String noticeId,
    String? attachmentUrl,
  }) {
    return SchoolNoticePublishResult._(
      success: true,
      noticeId: noticeId,
      attachmentUrl: attachmentUrl,
    );
  }

  factory SchoolNoticePublishResult.failure(String error) {
    return SchoolNoticePublishResult._(success: false, error: error);
  }
}

/// Parsed `notices/{id}` document used by the dashboard circular feed.
class SchoolNotice {
  final String id;
  final String title;
  final String content;
  final String category;
  final String targetAudience;
  final String date;
  final String attachmentUrl;
  final String attachmentName;
  final int attachmentSize;
  final String house;

  const SchoolNotice({
    required this.id,
    required this.title,
    required this.content,
    this.category = '',
    this.targetAudience = '',
    this.date = '',
    this.attachmentUrl = '',
    this.attachmentName = '',
    this.attachmentSize = 0,
    this.house = '',
  });

  bool get hasAttachment => attachmentUrl.trim().isNotEmpty;

  bool get isPdfAttachment {
    final url = attachmentUrl.toLowerCase();
    final name = attachmentName.toLowerCase();
    return url.contains('application/pdf') ||
        url.contains('.pdf') ||
        name.endsWith('.pdf');
  }

  String get categoryLabel =>
      category.trim().isEmpty ? 'Circular' : category.trim();

  String get attachmentLabel {
    final name = attachmentName.trim();
    if (name.isNotEmpty) return name;
    return 'Circular PDF';
  }

  factory SchoolNotice.fromMap(String id, Map<String, dynamic> data) {
    int parseSize(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return SchoolNotice(
      id: id,
      title: (data['title'] ?? 'School Circular').toString(),
      content: (data['content'] ?? data['body'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      targetAudience: (data['target_audience'] ?? '').toString(),
      date: (data['date'] ?? '').toString(),
      attachmentUrl: (data['attachment_url'] ?? '').toString(),
      attachmentName: (data['attachment_name'] ?? '').toString(),
      attachmentSize: parseSize(data['attachment_size']),
      house: (data['house'] ?? '').toString(),
    );
  }
}
