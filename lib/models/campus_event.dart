import 'package:cloud_firestore/cloud_firestore.dart';

enum EventCategory { all, cultural, sports, academic, arts, tech }

/// Lifecycle of a campus event. Drafts are staff-only until published.
enum CampusEventStatus { draft, published, cancelled }

extension CampusEventStatusExt on CampusEventStatus {
  String get label {
    switch (this) {
      case CampusEventStatus.draft:
        return 'Draft';
      case CampusEventStatus.published:
        return 'Published';
      case CampusEventStatus.cancelled:
        return 'Cancelled';
    }
  }

  static CampusEventStatus fromString(String? val) {
    final clean = (val ?? '').trim().toLowerCase();
    for (final s in CampusEventStatus.values) {
      if (s.name == clean) return s;
    }
    return CampusEventStatus.published;
  }
}

extension EventCategoryExt on EventCategory {
  String get displayName {
    switch (this) {
      case EventCategory.all:
        return 'All Events';
      case EventCategory.cultural:
        return 'Cultural';
      case EventCategory.sports:
        return 'Sports';
      case EventCategory.academic:
        return 'Academic';
      case EventCategory.arts:
        return 'Arts';
      case EventCategory.tech:
        return 'Technology';
    }
  }

  static EventCategory fromString(String? val) {
    final clean = (val ?? '').trim().toLowerCase();
    for (final c in EventCategory.values) {
      if (c.name.toLowerCase() == clean) return c;
    }
    return EventCategory.all;
  }
}

class CampusEvent implements Comparable<CampusEvent> {
  final String id;
  final String title;
  final String description;
  final EventCategory category;
  final String houseScope; // 'All' or specific house: 'ruby', 'sapphire', etc.
  final DateTime startTime;
  final DateTime endTime;
  final String venue;
  final int pointsAwarded;
  final double pointsMultiplier;
  final String bannerUrl; // Supports Base64 data URIs and HTTPS URLs
  final bool isLive;
  final CampusEventStatus status;
  final DateTime? createdAt;
  final String authorUid;
  final String authorName;
  final String cancelledReason;

  /// Lowest and highest targeted grade index. 0 covers LKG/UKG, 1–12 map to
  /// Grade 1–Grade 12. The default (0–12) means every grade.
  final int gradeMin;
  final int gradeMax;

  CampusEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.houseScope = 'All',
    required this.startTime,
    required this.endTime,
    required this.venue,
    this.pointsAwarded = 0,
    this.pointsMultiplier = 1.0,
    this.bannerUrl = '',
    this.isLive = false,
    this.status = CampusEventStatus.published,
    this.createdAt,
    this.authorUid = '',
    this.authorName = '',
    this.cancelledReason = '',
    this.gradeMin = 0,
    this.gradeMax = 12,
  });

  bool get targetsAllGrades => gradeMin <= 0 && gradeMax >= 12;

  String get gradeRangeLabel {
    if (targetsAllGrades) return 'All grades';
    String label(int grade) => grade <= 0 ? 'LKG/UKG' : 'Grade $grade';
    if (gradeMin == gradeMax) return label(gradeMin);
    return '${label(gradeMin)}–${label(gradeMax)}';
  }

  bool get isDraft => status == CampusEventStatus.draft;

  bool get isCancelled => status == CampusEventStatus.cancelled;

  bool get isPublished => status == CampusEventStatus.published;

  /// Cancelled events never run, regardless of the stored live flag.
  bool isOngoingAt(DateTime now) =>
      isPublished && now.isAfter(startTime) && now.isBefore(endTime);

  bool isConcludedAt(DateTime now) => !now.isBefore(endTime);

  /// The manual live flag is only honoured while the event is actually on.
  bool isLiveAt(DateTime now) => isLive && isOngoingAt(now);

  bool get isOngoing => isOngoingAt(DateTime.now());

  bool get isUpcoming => isPublished && DateTime.now().isBefore(startTime);

  Duration get timeRemaining => endTime.difference(DateTime.now());

  String get formattedRemaining {
    if (isCancelled) return 'Cancelled';
    if (isDraft) return 'Draft';
    final now = DateTime.now();
    if (isConcludedAt(now)) return 'Concluded';
    if (now.isBefore(startTime)) {
      final until = startTime.difference(now);
      if (until.inDays > 0) return 'Starts in ${until.inDays}d';
      if (until.inHours > 0) return 'Starts in ${until.inHours}h';
      return 'Starts in ${until.inMinutes}m';
    }
    final rem = timeRemaining;
    if (rem.inHours > 0) {
      return '${rem.inHours}h ${rem.inMinutes % 60}m remaining';
    }
    return '${rem.inMinutes}m remaining';
  }

  /// Local cache / SharedPreferences representation (JSON-safe).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'house_scope': houseScope,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'venue': venue,
      'points_awarded': pointsAwarded,
      'points_multiplier': pointsMultiplier,
      'banner_url': bannerUrl,
      'is_live': isLive,
      'status': status.name,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'author_uid': authorUid,
      'author_name': authorName,
      'cancelled_reason': cancelledReason,
      'grade_min': gradeMin,
      'grade_max': gradeMax,
    };
  }

  /// Firestore representation: timestamps are real Timestamps so rules and
  /// ordering work, and `created_at` can use a server timestamp.
  Map<String, dynamic> toFirestoreMap({bool serverTimestampCreatedAt = false}) {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'house_scope': houseScope,
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'venue': venue,
      'points_awarded': pointsAwarded,
      'points_multiplier': pointsMultiplier,
      'banner_url': bannerUrl,
      'is_live': isLive,
      'status': status.name,
      if (serverTimestampCreatedAt)
        'created_at': FieldValue.serverTimestamp()
      else if (createdAt != null)
        'created_at': Timestamp.fromDate(createdAt!),
      'author_uid': authorUid,
      'author_name': authorName,
      // Always present so re-publishing an edited event clears a stale reason
      // instead of leaving it behind in the merged Firestore document.
      'cancelled_reason': cancelledReason,
      'grade_min': gradeMin,
      'grade_max': gradeMax,
    };
  }

  CampusEvent copyWith({
    String? id,
    String? title,
    String? description,
    EventCategory? category,
    String? houseScope,
    DateTime? startTime,
    DateTime? endTime,
    String? venue,
    int? pointsAwarded,
    double? pointsMultiplier,
    String? bannerUrl,
    bool? isLive,
    CampusEventStatus? status,
    DateTime? createdAt,
    String? authorUid,
    String? authorName,
    String? cancelledReason,
    int? gradeMin,
    int? gradeMax,
  }) {
    return CampusEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      houseScope: houseScope ?? this.houseScope,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      venue: venue ?? this.venue,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      pointsMultiplier: pointsMultiplier ?? this.pointsMultiplier,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      isLive: isLive ?? this.isLive,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      cancelledReason: cancelledReason ?? this.cancelledReason,
      gradeMin: gradeMin ?? this.gradeMin,
      gradeMax: gradeMax ?? this.gradeMax,
    );
  }

  factory CampusEvent.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseOptionalDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    final rawStatus = map['status']?.toString();
    final status = rawStatus != null && rawStatus.isNotEmpty
        ? CampusEventStatusExt.fromString(rawStatus)
        : (map['is_published'] == false
              ? CampusEventStatus.draft
              : CampusEventStatus.published);

    return CampusEvent(
      id: docId ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Event',
      description: map['description']?.toString() ?? '',
      category: EventCategoryExt.fromString(map['category']?.toString()),
      houseScope: map['house_scope']?.toString() ?? 'All',
      startTime: parseDate(map['start_time']),
      endTime: parseDate(map['end_time']),
      venue: map['venue']?.toString() ?? 'Campus Grounds',
      pointsAwarded: (map['points_awarded'] as num?)?.toInt() ?? 0,
      pointsMultiplier: (map['points_multiplier'] as num?)?.toDouble() ?? 1.0,
      bannerUrl: map['banner_url']?.toString() ?? '',
      isLive: map['is_live'] == true,
      status: status,
      createdAt: parseOptionalDate(map['created_at']),
      authorUid: map['author_uid']?.toString() ?? '',
      authorName: map['author_name']?.toString() ?? '',
      cancelledReason: map['cancelled_reason']?.toString() ?? '',
      gradeMin: ((map['grade_min'] as num?)?.toInt() ?? 0).clamp(0, 12),
      gradeMax: ((map['grade_max'] as num?)?.toInt() ?? 12).clamp(0, 12),
    );
  }

  @override
  int compareTo(CampusEvent other) => startTime.compareTo(other.startTime);
}

/// One student's RSVP for a campus event, stored at
/// `events/{eventId}/registrations/{uid}`.
class EventRegistration {
  final String uid;
  final String eventId;
  final String studentName;
  final String scholarNo;
  final DateTime? createdAt;

  const EventRegistration({
    required this.uid,
    required this.eventId,
    this.studentName = '',
    this.scholarNo = '',
    this.createdAt,
  });

  factory EventRegistration.fromMap(
    Map<String, dynamic> map, {
    required String docId,
    required String eventId,
  }) {
    DateTime? created;
    final raw = map['created_at'];
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is String) {
      created = DateTime.tryParse(raw);
    }
    return EventRegistration(
      uid: docId,
      eventId: eventId,
      studentName: map['student_name']?.toString() ?? '',
      scholarNo: map['scholar_no']?.toString() ?? '',
      createdAt: created,
    );
  }
}
