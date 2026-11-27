import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import 'auth_service.dart';

/// Outcome of a notification fan-out.
///
/// The result is deliberately explicit so UI callers can tell the difference
/// between "not attempted" (offline), "fully delivered", and a partial failure.
class NotificationFanOutResult {
  final int total;
  final int sent;
  final int failed;
  final bool skipped;
  final List<String> failedUids;
  final String error;

  const NotificationFanOutResult({
    required this.total,
    required this.sent,
    required this.failed,
    this.skipped = false,
    this.failedUids = const [],
    this.error = '',
  });

  static NotificationFanOutResult skippedResult(int total) =>
      NotificationFanOutResult(
        total: total,
        sent: 0,
        failed: 0,
        skipped: true,
      );

  static NotificationFanOutResult failureResult(int total, Object error) =>
      NotificationFanOutResult(
        total: total,
        sent: 0,
        failed: total,
        failedUids: const [],
        error: error.toString(),
      );

  bool get isComplete => !skipped && failed == 0 && !hasError;
  bool get isPartial => !skipped && failed > 0 && sent > 0;
  bool get hasError => error.trim().isNotEmpty;

  String? get warning {
    if (failed == 0 && !hasError) return null;
    if (sent == 0) {
      return 'Update posted, but notifications could not be delivered.';
    }
    return 'Update posted, but notifications reached only $sent of $total members.';
  }
}

/// Spark-compatible notification engine (M6).
///
/// Notifications live in the existing `users/{uid}/notifications` subcollection.
/// There is no server fan-out on Spark, so the publishing client resolves the
/// target roster from the profile directory and writes one deduplicated document
/// per recipient. Writes are chunked into atomic batches and the returned result
/// is truthful about partial failure.
class NotificationService {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  NotificationService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _customAuth = auth,
        _customFirestore = firestore;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  static const int batchLimit = 400;
  static const int rosterLimit = 500;
  static const int streamLimit = 100;

  /// Set when the roster/profile query itself fails. This is distinct from a
  /// genuine empty roster: an event helper must not report a lookup failure as
  /// a complete zero-recipient fan-out.
  String _recipientLookupError = '';

  /// Test hook: simulate a denied Firestore write. Mirrors the other services.
  @visibleForTesting
  static Exception? firestoreFailureSimulated;

  /// Test hook: replace the Firestore roster query with an in-memory profile
  /// list. The scope is `house` or `class`, and the id is the house/class key.
  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function(
    String scope,
    String scopeId,
  )? recipientsLoader;

  /// Test hook: replace the signed-in user's notification stream so dashboard
  /// widget tests can exercise unread chips without Firebase.
  @visibleForTesting
  static Stream<List<AppNotification>>? notificationsStreamOverride;

  String get currentUserId {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isNotEmpty) return uid;
    } catch (_) {}
    final cachedUid = AuthService.getCachedUid() ?? '';
    if (cachedUid.isNotEmpty) return cachedUid;
    return (AuthService.getCachedProfile()?['uid'] ?? '').toString().trim();
  }

  // ===============================================================
  // Read / unread streams
  // ===============================================================

  Stream<List<AppNotification>> getNotificationsStream({
    int limit = streamLimit,
  }) {
    final override = notificationsStreamOverride;
    if (override != null) return override;
    final uid = currentUserId;
    if (!AuthService.isFirebaseLive || uid.isEmpty) {
      return Stream.value(const <AppNotification>[]);
    }
    try {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList())
          .handleError((Object error) {
        debugPrint('Notification stream error: $error');
        return <AppNotification>[];
      });
    } catch (e) {
      debugPrint('Notification stream unavailable: $e');
      return Stream.value(const <AppNotification>[]);
    }
  }

  Stream<int> getUnreadCountStream({int limit = streamLimit}) =>
      getNotificationsStream(limit: limit).map(AppNotification.unreadCount);

  /// Dashboard breakdown of unread class/house/timetable announcements.
  Stream<NotificationUnreadBreakdown> getUnreadBreakdownStream({
    int limit = streamLimit,
  }) =>
      getNotificationsStream(limit: limit)
          .map(NotificationUnreadBreakdown.from);

  // ===============================================================
  // Read state
  // ===============================================================

  Future<bool> markRead(String notificationId, {bool read = true}) async {
    final id = notificationId.trim();
    final uid = currentUserId;
    if (id.isEmpty || uid.isEmpty || !AuthService.isFirebaseLive) return false;
    if (firestoreFailureSimulated != null) return false;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(id)
          .update({'is_read': read});
      return true;
    } catch (e) {
      debugPrint('Notification markRead failed: $e');
      return false;
    }
  }

  Future<bool> markAllRead(List<AppNotification> notifications) async {
    final unread = notifications
        .where((n) => n.isUnread && n.id.trim().isNotEmpty)
        .map((n) => n.id.trim())
        .toSet()
        .toList();
    if (unread.isEmpty) return true;

    final uid = currentUserId;
    if (uid.isEmpty || !AuthService.isFirebaseLive) return false;
    if (firestoreFailureSimulated != null) return false;

    try {
      for (var start = 0; start < unread.length; start += batchLimit) {
        final end = (start + batchLimit) > unread.length
            ? unread.length
            : start + batchLimit;
        final batch = _firestore.batch();
        final collection =
            _firestore.collection('users').doc(uid).collection('notifications');
        for (var i = start; i < end; i++) {
          batch.update(collection.doc(unread[i]), {'is_read': true});
        }
        await batch.commit();
      }
      return true;
    } catch (e) {
      debugPrint('Notification markAllRead failed: $e');
      return false;
    }
  }

  // ===============================================================
  // Deletion / Clear
  // ===============================================================

  /// Deletes a single notification document owned by the signed-in user.
  /// Server-enforced: rules allow delete if `isOwner(userId) || isAdmin()`.
  Future<bool> deleteNotification(String notificationId) async {
    final id = notificationId.trim();
    final uid = currentUserId;
    if (id.isEmpty || uid.isEmpty || !AuthService.isFirebaseLive) return false;
    if (firestoreFailureSimulated != null) return false;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(id)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Notification delete failed: $e');
      return false;
    }
  }

  /// Clears multiple notifications owned by the signed-in user in batched writes.
  Future<bool> clearAll(List<AppNotification> notifications) async {
    final ids = notifications
        .map((n) => n.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return true;

    final uid = currentUserId;
    if (uid.isEmpty || !AuthService.isFirebaseLive) return false;
    if (firestoreFailureSimulated != null) return false;

    try {
      for (var start = 0; start < ids.length; start += batchLimit) {
        final end = (start + batchLimit) > ids.length
            ? ids.length
            : start + batchLimit;
        final batch = _firestore.batch();
        final collection =
            _firestore.collection('users').doc(uid).collection('notifications');
        for (var i = start; i < end; i++) {
          batch.delete(collection.doc(ids[i]));
        }
        await batch.commit();
      }
      return true;
    } catch (e) {
      debugPrint('Notification clearAll failed: $e');
      return false;
    }
  }

  // ===============================================================
  // Recipient resolution
  // ===============================================================

  /// Resolves recipient UIDs for a `house` or `class` audience.
  ///
  /// House membership uses the profile `house_name`. Class membership requires
  /// the canonical `class_id` **and** `class_verified == true`, exactly like M5.
  Future<List<String>> resolveRecipients({
    required String scope,
    required String scopeId,
    String excludeUid = '',
  }) async {
    _recipientLookupError = '';
    final normalizedScope = scope.trim().toLowerCase();
    final id = scopeId.trim();
    if (id.isEmpty || (normalizedScope != 'house' && normalizedScope != 'class')) {
      return const [];
    }

    List<Map<String, dynamic>> profiles;
    try {
      final loader = recipientsLoader;
      profiles = loader != null
          ? await loader(normalizedScope, id)
          : await _loadProfiles(normalizedScope, id);
    } catch (e) {
      _recipientLookupError = e.toString();
      debugPrint('Notification recipient lookup failed: $e');
      return const [];
    }

    return recipientUidsFromProfiles(
      profiles,
      scope: normalizedScope,
      scopeId: id,
      excludeUid: excludeUid,
    );
  }

  /// Pure recipient filter so tests can verify targeting without Firebase.
  static List<String> recipientUidsFromProfiles(
    List<Map<String, dynamic>> profiles, {
    required String scope,
    required String scopeId,
    String excludeUid = '',
  }) {
    final normalizedScope = scope.trim().toLowerCase();
    final target = normalizedScope == 'house'
        ? scopeId.trim().toLowerCase()
        : scopeId.trim().toUpperCase();
    final excluded = excludeUid.trim();
    final seen = <String>{};

    for (final profile in profiles) {
      final uid =
          (profile['uid'] ?? profile['id'] ?? '').toString().trim();
      if (uid.isEmpty || uid == excluded || seen.contains(uid)) continue;

      if (normalizedScope == 'house') {
        final house =
            (profile['house_name'] ?? profile['house'] ?? '').toString().trim();
        if (house.toLowerCase() != target) continue;
      } else if (normalizedScope == 'class') {
        final classId =
            (profile['class_id'] ?? '').toString().trim().toUpperCase();
        if (classId != target || profile['class_verified'] != true) continue;
      } else {
        continue;
      }
      seen.add(uid);
    }

    final result = seen.toList()..sort();
    return result;
  }

  Future<List<Map<String, dynamic>>> _loadProfiles(
    String scope,
    String scopeId,
  ) async {
    final users = _firestore.collection('users');
    final query = scope == 'house'
        ? users.where('house_name', isEqualTo: scopeId.trim().toLowerCase())
        : users.where('class_id', isEqualTo: scopeId.trim().toUpperCase());
    final snapshot = await query.limit(rosterLimit).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return <String, dynamic>{...data, 'uid': doc.id};
    }).toList();
  }

  // ===============================================================
  // Fan-out
  // ===============================================================

  /// Writes one notification per recipient with a deterministic document ID.
  ///
  /// Deduplication is structural: re-running the same event reuses the same
  /// doc IDs, so no duplicate notification is created. The payload deliberately
  /// omits `is_read`, so a retry never clears an existing read state.
  Future<NotificationFanOutResult> fanOutToUsers({
    required Iterable<String> recipientUids,
    required String title,
    required String body,
    required String type,
    required String category,
    required String dedupeKey,
    String priority = 'normal',
    String sourceId = '',
    String roomId = '',
    DateTime? eventTime,
  }) async {
    final currentUid = currentUserId;
    final recipients = recipientUids
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty && uid != currentUid)
        .toSet()
        .toList()
      ..sort();
    final total = recipients.length;
    if (total == 0) {
      return const NotificationFanOutResult(total: 0, sent: 0, failed: 0);
    }
    if (!AuthService.isFirebaseLive) {
      return NotificationFanOutResult.skippedResult(total);
    }
    if (firestoreFailureSimulated != null) {
      return NotificationFanOutResult.failureResult(
        total,
        firestoreFailureSimulated!,
      );
    }

    final effectiveSourceId =
        sourceId.trim().isNotEmpty ? sourceId.trim() : dedupeKey.trim();
    final senderName = (AuthService.getCachedProfile()?['full_name'] ?? '')
        .toString()
        .trim();

    final payload = buildNotificationPayload(
      title: title,
      body: body,
      type: type,
      category: category,
      priority: priority,
      dedupeKey: dedupeKey,
      sourceId: effectiveSourceId,
      roomId: roomId,
      senderId: currentUid,
      senderName: senderName,
      eventTime: eventTime,
    );

    var sent = 0;
    var failed = 0;
    final failedUids = <String>[];
    var lastError = '';

    for (var start = 0; start < recipients.length; start += batchLimit) {
      final end = (start + batchLimit) > recipients.length
          ? recipients.length
          : start + batchLimit;
      final chunk = recipients.sublist(start, end);
      try {
        final batch = _firestore.batch();
        for (final uid in chunk) {
          final ref = _firestore
              .collection('users')
              .doc(uid)
              .collection('notifications')
              .doc(notificationDocId(dedupeKey, uid));
          batch.set(ref, payload, SetOptions(merge: true));
        }
        await batch.commit();
        sent += chunk.length;
      } catch (e) {
        failed += chunk.length;
        failedUids.addAll(chunk);
        lastError = e.toString();
        if (!_isNoAppException(e)) {
          debugPrint('Notification fan-out batch failed: $e');
        }
      }
    }

    return NotificationFanOutResult(
      total: total,
      sent: sent,
      failed: failed,
      failedUids: failedUids,
      error: lastError,
    );
  }

  /// Builds the wire payload written by the fan-out. No `is_read` field is
  /// included so deduplicated retries preserve the recipient's read state.
  static Map<String, dynamic> buildNotificationPayload({
    required String title,
    required String body,
    required String type,
    required String category,
    required String dedupeKey,
    String priority = 'normal',
    String sourceId = '',
    String roomId = '',
    String senderId = '',
    String senderName = '',
    DateTime? eventTime,
  }) {
    final cleanTitle = _clip(title.trim(), 100);
    final cleanBody = _clip(
      body.trim().isEmpty ? cleanTitle : body.trim(),
      500,
    );
    final cleanDedupe = _clip(dedupeKey.trim(), 200);
    final cleanSource = _clip(
      sourceId.trim().isNotEmpty ? sourceId.trim() : cleanDedupe,
      128,
    );
    final cleanRoom = _clip(roomId.trim(), 128);
    final cleanType = _clip(type.trim(), 50);
    final cleanSender = _clip(senderId.trim(), 128);
    final cleanSenderName = _clip(senderName.trim(), 100);

    return {
      'title': cleanTitle.isEmpty ? 'ASB Notification' : cleanTitle,
      'body': cleanBody.isEmpty ? 'You have a new campus update.' : cleanBody,
      'timestamp': Timestamp.fromDate(eventTime ?? DateTime.now()),
      'type': cleanType.isEmpty ? 'system' : cleanType,
      'category': normalizeNotificationCategory(category),
      'priority': normalizeNotificationPriority(priority),
      'sender_id': cleanSender,
      if (cleanSenderName.isNotEmpty) 'sender_name': cleanSenderName,
      if (cleanDedupe.isNotEmpty) 'dedupe_key': cleanDedupe,
      if (cleanSource.isNotEmpty) 'source_id': cleanSource,
      if (cleanRoom.isNotEmpty) 'room_id': cleanRoom,
    };
  }

  /// Deterministic document ID per event + recipient. Structural dedupe means
  /// two publishes of the same source event can never create two documents.
  static String notificationDocId(String dedupeKey, String recipientUid) {
    final raw = '${dedupeKey.trim()}_${recipientUid.trim()}';
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
    if (cleaned.isEmpty) return 'notification_${recipientUid.trim()}';
    if (cleaned.length <= 300) return cleaned;
    return '${cleaned.substring(0, 280)}_${cleaned.hashCode}';
  }

  static String _clip(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  static String _formatDateLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = (date.month >= 1 && date.month <= 12)
        ? months[date.month - 1]
        : '${date.month}';
    return '$m ${date.day}, ${date.year}';
  }

  /// A failed roster lookup is not a complete zero-recipient fan-out. The
  /// error is carried into [NotificationFanOutResult] so callers show the
  /// partial/failure warning instead of a phantom success.
  NotificationFanOutResult _recipientLookupFailureResult() =>
      NotificationFanOutResult(
        total: 0,
        sent: 0,
        failed: 0,
        error: _recipientLookupError,
      );

  // ===============================================================
  // Event conveniences
  // ===============================================================

  /// Test 60: a published timetable notifies the verified class roster.
  /// If [overrideDate] is non-null, creates a temporary override announcement.
  Future<NotificationFanOutResult> notifyTimetablePublished({
    required String classId,
    required String versionId,
    required String dayOfWeek,
    required int version,
    required String publisherUid,
    String publisherName = '',
    DateTime? overrideDate,
  }) async {
    final id = classId.trim().toUpperCase();
    final recipients = await resolveRecipients(
      scope: 'class',
      scopeId: id,
      excludeUid: publisherUid,
    );
    if (_recipientLookupError.isNotEmpty) {
      return _recipientLookupFailureResult();
    }
    final publisher = publisherName.trim();
    final bool isOverride = overrideDate != null;
    final dateStr = isOverride
        ? overrideDate.toIso8601String().split('T').first
        : '';
    final dateFormatted = isOverride ? _formatDateLabel(overrideDate) : '';

    final String title;
    final String body;
    final String type;
    final String dedupeKey;
    final String source;

    if (isOverride) {
      source = versionId.trim().isEmpty
          ? 'tt_override_${id}_${dateStr}_v$version'
          : versionId.trim();
      title = '📅 Timetable override — $id';
      body = publisher.isEmpty
          ? 'A temporary schedule for $dateFormatted (v$version) is now live.'
          : '$publisher published a temporary schedule for $dateFormatted (v$version).';
      type = 'timetable_override';
      dedupeKey = 'tt_override_${id}_${dateStr}_v$version';
    } else {
      source = versionId.trim().isEmpty
          ? 'tt_${id}_${dayOfWeek.trim()}_v$version'
          : versionId.trim();
      title = '📅 Timetable updated — $id';
      body = publisher.isEmpty
          ? 'A new ${dayOfWeek.trim()} timetable (v$version) is now live.'
          : '$publisher published a new ${dayOfWeek.trim()} timetable (v$version).';
      type = 'timetable_published';
      dedupeKey = 'timetable_$source';
    }

    return fanOutToUsers(
      recipientUids: recipients,
      title: title,
      body: body,
      type: type,
      category: 'timetable',
      priority: 'high',
      dedupeKey: dedupeKey,
      sourceId: source,
      roomId: id,
    );
  }

  /// Teacher substitution notification (M3 / test 60):
  /// Notifies the verified class roster AND the assigned substitute teacher.
  Future<NotificationFanOutResult> notifyTimetableSubstitution({
    required String classId,
    required String dayOfWeek,
    required DateTime date,
    required int periodNumber,
    required String subject,
    required String originalTeacherName,
    required String substituteTeacherName,
    required String substituteTeacherUid,
    required String actorUid,
    String actorName = '',
  }) async {
    final id = classId.trim().toUpperCase();
    final recipients = await resolveRecipients(
      scope: 'class',
      scopeId: id,
      excludeUid: actorUid,
    );
    if (_recipientLookupError.isNotEmpty) {
      return _recipientLookupFailureResult();
    }
    final allRecipients = Set<String>.from(recipients);
    final subUid = substituteTeacherUid.trim();
    if (subUid.isNotEmpty && subUid != actorUid) {
      allRecipients.add(subUid);
    }

    final dateStr = date.toIso8601String().split('T').first;
    final dateFormatted = _formatDateLabel(date);
    final orig = originalTeacherName.trim().isEmpty
        ? 'regular teacher'
        : originalTeacherName.trim();
    final sub = substituteTeacherName.trim().isEmpty
        ? 'A substitute teacher'
        : substituteTeacherName.trim();
    final subj = subject.trim().isEmpty ? 'Class' : subject.trim();

    return fanOutToUsers(
      recipientUids: allRecipients,
      title: '🔄 Substitution: $subj (Period $periodNumber)',
      body:
          '$sub will be substituting for $orig in $subj ($id) on $dateFormatted.',
      type: 'timetable_substitution',
      category: 'timetable',
      priority: 'high',
      dedupeKey: 'tt_sub_${id}_${dateStr}_p$periodNumber',
      sourceId: '${id}_${dateStr}_p$periodNumber',
      roomId: id,
    );
  }

  /// Test 61: a house announcement notifies verified members of that house.
  Future<NotificationFanOutResult> notifyHouseAnnouncement({
    required String houseId,
    required String messageId,
    required String senderUid,
    required String senderName,
    required String preview,
  }) async {
    final id = houseId.trim().toLowerCase();
    final source = messageId.trim();
    final recipients = await resolveRecipients(
      scope: 'house',
      scopeId: id,
      excludeUid: senderUid,
    );
    if (_recipientLookupError.isNotEmpty) {
      return _recipientLookupFailureResult();
    }
    final name = senderName.trim();
    final text = preview.trim().isEmpty ? 'New house announcement.' : preview.trim();
    return fanOutToUsers(
      recipientUids: recipients,
      title: '📢 ${id.toUpperCase()} House announcement',
      body: name.isEmpty ? text : '$name: $text',
      type: 'house_announcement',
      category: 'house',
      priority: 'high',
      dedupeKey: 'house_${id}_$source',
      sourceId: source,
      roomId: id,
    );
  }

  /// Test 62: a class announcement notifies verified members of that class.
  Future<NotificationFanOutResult> notifyClassAnnouncement({
    required String classId,
    required String messageId,
    required String senderUid,
    required String senderName,
    required String preview,
  }) async {
    final id = classId.trim().toUpperCase();
    final source = messageId.trim();
    final recipients = await resolveRecipients(
      scope: 'class',
      scopeId: id,
      excludeUid: senderUid,
    );
    if (_recipientLookupError.isNotEmpty) {
      return _recipientLookupFailureResult();
    }
    final name = senderName.trim();
    final text =
        preview.trim().isEmpty ? 'New class announcement.' : preview.trim();
    return fanOutToUsers(
      recipientUids: recipients,
      title: '📢 $id class announcement',
      body: name.isEmpty ? text : '$name: $text',
      type: 'class_announcement',
      category: 'class',
      priority: 'high',
      dedupeKey: 'class_${id}_$source',
      sourceId: source,
      roomId: id,
    );
  }

  static bool _isNoAppException(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('no-app') || s.contains('no firebase app');
  }
}
