import 'dart:typed_data';

/// Hard ceiling for a circular PDF. Firebase Storage allows 15 MB on the
/// existing academic-resource path, so the circular path uses the same limit.
const int kMaxSchoolCircularPdfBytes = 15 * 1024 * 1024;

/// Inline Base64 fallback ceiling for Firestore.
///
/// A Firestore document is capped at 1,048,576 bytes. Base64 expands bytes by
/// roughly 4/3, so 700 KB of PDF becomes ~933 KB of text plus the notice
/// fields. Larger PDFs must be uploaded to Storage; they cannot be embedded.
const int kMaxInlineCircularPdfBytes = 700 * 1024;

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

  /// True when the notice was saved only to this device because Firebase is
  /// running in local/offline mode. It has NOT reached other users.
  final bool localOnly;

  const SchoolNoticePublishResult._({
    required this.success,
    this.noticeId,
    this.attachmentUrl,
    this.error,
    this.localOnly = false,
  });

  factory SchoolNoticePublishResult.success({
    required String noticeId,
    String? attachmentUrl,
    bool localOnly = false,
  }) {
    return SchoolNoticePublishResult._(
      success: true,
      noticeId: noticeId,
      attachmentUrl: attachmentUrl,
      localOnly: localOnly,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'target_audience': targetAudience,
      'date': date,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'attachment_size': attachmentSize,
      'house': house,
    };
  }

  static List<SchoolNotice> getFoundationalNotices() {
    return const [
      SchoolNotice(
        id: 'notice_term2_launch',
        title: 'Commencement of Term 2 & House Championship League',
        content:
            'Welcome back to Term 2! House points and academic merit tracking have officially begun. Please review the updated schedule for inter-house sports fixtures, mid-term examinations, and cultural decathlons.',
        category: 'Academic',
        targetAudience: 'All Students & Faculty',
        date: '10/11/2026',
      ),
      SchoolNotice(
        id: 'notice_sports_derby',
        title: 'Inter-House Athletic Championship & Golden Boot Fixtures',
        content:
            'The Asian School Inter-House Football League kicks off this week on the main stadium pitch. Houses are reminded that vocal spirit cheers and exemplary sportsmanship earn bonus points.',
        category: 'Sports',
        targetAudience: 'All Students',
        date: '08/11/2026',
      ),
      SchoolNotice(
        id: 'notice_stem_olympiad',
        title: 'Brain Blitz 2026: STEM Olympiad & Algorithmic Hackathon',
        content:
            'Registrations are now open for the annual Brain Blitz Olympiad. Top performers in mathematics, physics, and programming will be awarded collegiate honours merit badges.',
        category: 'Academic',
        targetAudience: 'Grades 9-12',
        date: '05/11/2026',
      ),
    ];
  }
}
