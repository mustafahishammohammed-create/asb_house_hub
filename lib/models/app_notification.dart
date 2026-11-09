import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories supported by the in-app notification engine (M6).
const List<String> kNotificationCategories = [
  'timetable',
  'house',
  'class',
  'chat',
  'points',
  'system',
];

const List<String> kNotificationPriorities = ['normal', 'high', 'urgent'];

String normalizeNotificationCategory(String? value) {
  final clean = (value ?? '').trim().toLowerCase();
  return kNotificationCategories.contains(clean) ? clean : 'system';
}

String normalizeNotificationPriority(String? value) {
  final clean = (value ?? '').trim().toLowerCase();
  return kNotificationPriorities.contains(clean) ? clean : 'normal';
}

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}

/// A single in-app notification stored at
/// `users/{uid}/notifications/{notificationId}`.
///
/// `is_read` is intentionally optional on the wire: the Spark fan-out writes
/// deduplicated notifications without touching read state, so a re-fan-out
/// never marks an already-read notification unread. A missing field therefore
/// means "unread".
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String category;
  final String priority;
  final String roomId;
  final String dedupeKey;
  final String sourceId;
  final bool isRead;
  final DateTime? timestamp;

  AppNotification({
    this.id = '',
    required this.title,
    required this.body,
    this.type = '',
    String category = 'system',
    String priority = 'normal',
    this.roomId = '',
    this.dedupeKey = '',
    this.sourceId = '',
    this.isRead = false,
    this.timestamp,
  })  : category = normalizeNotificationCategory(category),
        priority = normalizeNotificationPriority(priority);

  bool get isUnread => !isRead;
  bool get isHighPriority => priority == 'high' || priority == 'urgent';
  bool get hasSource => sourceId.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'body': body.trim(),
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp!)
          : FieldValue.serverTimestamp(),
      'is_read': isRead,
      'type': type.trim(),
      'category': normalizeNotificationCategory(category),
      'priority': normalizeNotificationPriority(priority),
      if (roomId.trim().isNotEmpty) 'room_id': roomId.trim(),
      if (dedupeKey.trim().isNotEmpty) 'dedupe_key': dedupeKey.trim(),
      if (sourceId.trim().isNotEmpty) 'source_id': sourceId.trim(),
    };
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      category: normalizeNotificationCategory(data['category']?.toString()),
      priority: normalizeNotificationPriority(data['priority']?.toString()),
      roomId: (data['room_id'] ?? '').toString(),
      dedupeKey: (data['dedupe_key'] ?? '').toString(),
      sourceId: (data['source_id'] ?? '').toString(),
      isRead: data['is_read'] == true,
      timestamp: _parseDateTime(data['timestamp']),
    );
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    return AppNotification.fromMap(
      doc.id,
      data is Map<String, dynamic> ? data : <String, dynamic>{},
    );
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? category,
    String? priority,
    String? roomId,
    String? dedupeKey,
    String? sourceId,
    bool? isRead,
    DateTime? timestamp,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      roomId: roomId ?? this.roomId,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      sourceId: sourceId ?? this.sourceId,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  static int unreadCount(Iterable<AppNotification> notifications) =>
      notifications.where((n) => n.isUnread).length;
}

/// Per-category unread totals used by the dashboard (M8). Only the categories
/// needed by the dashboard are counted; [total] still includes every unread
/// notification so the bell badge and the chips cannot disagree.
class NotificationUnreadBreakdown {
  final int total;
  final int classCount;
  final int houseCount;
  final int timetableCount;

  const NotificationUnreadBreakdown({
    this.total = 0,
    this.classCount = 0,
    this.houseCount = 0,
    this.timetableCount = 0,
  });

  static const empty = NotificationUnreadBreakdown();

  bool get hasAny => total > 0;

  factory NotificationUnreadBreakdown.from(
    Iterable<AppNotification> notifications,
  ) {
    var total = 0;
    var classCount = 0;
    var houseCount = 0;
    var timetableCount = 0;
    for (final notification in notifications) {
      if (!notification.isUnread) continue;
      total++;
      switch (notification.category) {
        case 'class':
          classCount++;
          break;
        case 'house':
          houseCount++;
          break;
        case 'timetable':
          timetableCount++;
          break;
      }
    }
    return NotificationUnreadBreakdown(
      total: total,
      classCount: classCount,
      houseCount: houseCount,
      timetableCount: timetableCount,
    );
  }
}
