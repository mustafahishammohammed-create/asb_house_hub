import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/academic_class.dart';
import '../models/class_group.dart';
import 'auth_service.dart';
import 'hierarchy_service.dart';
import 'notification_service.dart';

/// Spark-compatible class group service.
///
/// Membership is never written to Firestore: it is derived from the verified
/// `class_id` on the profile. Staff access is derived from the
/// `academic_classes` registry (class teacher UID and subject teacher UIDs), so
/// a class transfer or reassignment revokes the old group and grants the new
/// one without a migration.
class ClassGroupService {
  @visibleForTesting
  static Exception? firestoreFailureSimulated;

  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;
  final NotificationService? _customNotifications;

  ClassGroupService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationService? notifications,
  })  : _customAuth = auth,
        _customFirestore = firestore,
        _customNotifications = notifications;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  NotificationService get _notifications =>
      _customNotifications ?? NotificationService();

  /// Result of the M6 fan-out for the most recent announcement message.
  NotificationFanOutResult? lastNotificationResult;

  String get currentUserId {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isNotEmpty) return uid;
    } catch (_) {}
    final cachedUid = AuthService.getCachedUid() ?? '';
    if (cachedUid.isNotEmpty) return cachedUid;
    return (AuthService.getCachedProfile()?['uid'] ?? '').toString().trim();
  }

  Map<String, dynamic>? get currentProfile => AuthService.getCachedProfile();

  String get myClassId => ClassGroupAccess.resolveClassId(currentProfile);

  AcademicClass? get currentAcademicClass => _cachedClass(myClassId);

  bool canViewIn(String classId) => ClassGroupAccess.canView(
        currentProfile,
        classId,
        _cachedClass(classId),
      );

  bool canPostIn(String classId) => ClassGroupAccess.canSend(
        currentProfile,
        classId,
        _cachedClass(classId),
      );

  bool canModerateIn(String classId) => ClassGroupAccess.canModerate(
        currentProfile,
        classId,
        _cachedClass(classId),
      );

  AcademicClass? _cachedClass(String classId) {
    final target = classId.trim().toUpperCase();
    if (target.isEmpty) return null;
    for (final cls in AuthService.getCachedAcademicClasses()) {
      if (cls.classId.trim().toUpperCase() == target) return cls;
    }
    return null;
  }

  /// Stream of the group header. Returns an empty stream when Firebase is not
  /// configured (widget tests) or the caller cannot view the class.
  Stream<DocumentSnapshot> getClassGroupStream(String classId) {
    try {
      if (!AuthService.isFirebaseLive || currentUserId.isEmpty) {
        return const Stream.empty();
      }
      if (!canViewIn(classId)) return const Stream.empty();
      return _firestore
          .collection('class_groups')
          .doc(classId.trim().toUpperCase())
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Live registry document for the class. Used by the screen to keep
  /// student-posting and teacher-assignment permissions current.
  Stream<AcademicClass> getAcademicClassStream(String classId) {
    try {
      if (!AuthService.isFirebaseLive || currentUserId.isEmpty) {
        return const Stream.empty();
      }
      return _firestore
          .collection('academic_classes')
          .doc(classId.trim().toUpperCase())
          .snapshots()
          .where((snap) => snap.exists)
          .map((snap) => AcademicClass.fromFirestore(snap));
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Newest-first message stream, capped to keep Spark reads bounded.
  Stream<List<ClassGroupMessage>> getClassMessagesStream(String classId) {
    final id = classId.trim().toUpperCase();
    if (!AuthService.isFirebaseLive || currentUserId.isEmpty) {
      return const Stream.empty();
    }
    return Stream.fromFuture(_resolveAcademicClass(id)).asyncExpand((cls) {
      if (!ClassGroupAccess.canView(currentProfile, id, cls)) {
        return const Stream.empty();
      }
      return _firestore
          .collection('class_groups')
          .doc(id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ClassGroupMessage.fromMap(doc.id, doc.data()))
              .toList());
    });
  }

  /// Creates the group header if missing. Only the class teacher or a senior
  /// admin may bootstrap it; subject teachers and students can still read/send
  /// without a header, just like house groups.
  Future<bool> ensureClassGroup(String classId) async {
    final id = classId.trim().toUpperCase();
    if (!AuthService.isFirebaseLive) return false;
    final cls = await _resolveAcademicClass(id);
    if (!ClassGroupAccess.canModerate(currentProfile, id, cls)) return false;
    if (firestoreFailureSimulated != null) return false;
    try {
      final ref = _firestore.collection('class_groups').doc(id);
      final snapshot = await ref.get();
      if (snapshot.exists) return true;
      final now = DateTime.now();
      await ref.set(
        ClassGroup.defaultsFor(id)
            .copyWith(createdAt: now, updatedAt: now)
            .toMap(),
      );
      return true;
    } catch (e) {
      if (!_isNoAppException(e)) {
        debugPrint('Class group header create failed: $e');
      }
      return false;
    }
  }

  /// Posts a message. Truthful: returns `false` for unauthorised senders,
  /// offline runtimes, simulated failures, and real Firestore denials.
  Future<bool> sendClassMessage({
    required String classId,
    required String text,
    String category = 'general',
    String attachmentUrl = '',
  }) async {
    final id = classId.trim().toUpperCase();
    final cleanText = text.trim();
    final attachment = attachmentUrl.trim();
    if (cleanText.isEmpty && attachment.isEmpty) return false;
    lastNotificationResult = null;
    if (!AuthService.isFirebaseLive) return false;
    if (firestoreFailureSimulated != null) return false;

    final uid = currentUserId;
    if (uid.isEmpty) return false;

    var profile = currentProfile;
    if (profile == null) return false;

    try {
      // Prefer the live profile for the sender name/role, falling back to the
      // verified cache when the read is unavailable.
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 4));
        if (userDoc.exists) {
          profile = {...profile, ...?userDoc.data()};
        }
      } catch (_) {}

      final cls = await _resolveAcademicClass(id);
      if (!ClassGroupAccess.canSend(profile, id, cls)) return false;

      final senderName = ClassGroupAccess.nameOf(profile);
      final senderRole = HierarchyService.getRoleDisplayTitle(
        scholarNo: ClassGroupAccess.scholarOf(profile),
        role: ClassGroupAccess.roleOf(profile),
        fullName: senderName,
      );
      final timestamp = FieldValue.serverTimestamp();

      final messageRef = await _firestore
          .collection('class_groups')
          .doc(id)
          .collection('messages')
          .add({
        'sender_id': uid,
        'sender_name': senderName,
        'sender_role': senderRole,
        'sender_class': id,
        'text': cleanText,
        'category': normalizeClassGroupCategory(category),
        'attachment_url': attachment,
        'is_pinned': false,
        'is_hidden': false,
        'moderated_by': '',
        'timestamp': timestamp,
      });

      // Keep the group summary fresh without making the message dependent on
      // it. Creating the header is restricted to the class teacher/senior admin.
      try {
        final groupRef = _firestore.collection('class_groups').doc(id);
        final groupSnap = await groupRef.get();
        if (!groupSnap.exists) {
          if (ClassGroupAccess.canModerate(profile, id, cls)) {
            final now = DateTime.now();
            await groupRef.set(
              ClassGroup.defaultsFor(id)
                  .copyWith(createdAt: now, updatedAt: now)
                  .toMap(),
            );
          }
        }
        if (groupSnap.exists ||
            ClassGroupAccess.canModerate(profile, id, cls)) {
          await groupRef.update({
            'last_message':
                cleanText.isEmpty ? 'Photo attachment' : cleanText,
            'last_message_at': timestamp,
            'updated_at': timestamp,
          });
        }
      } catch (_) {}

      // M6/test 62: only announcement-category messages fan out. The message is
      // already committed, so a notification failure never reverses the send.
      if (normalizeClassGroupCategory(category) == 'announcement') {
        try {
          lastNotificationResult = await _notifications.notifyClassAnnouncement(
            classId: id,
            messageId: messageRef.id,
            senderUid: uid,
            senderName: senderName,
            preview: cleanText.isEmpty ? 'Photo attachment' : cleanText,
          );
        } catch (e) {
          debugPrint('Class announcement notification fan-out failed: $e');
        }
      }

      return true;
    } catch (e) {
      if (!_isNoAppException(e)) {
        debugPrint('Class group send failed: $e');
      }
      return false;
    }
  }

  Future<bool> setMessagePinned({
    required String classId,
    required String messageId,
    required bool pinned,
  }) {
    return _moderateMessage(
      classId: classId,
      messageId: messageId,
      updates: {'is_pinned': pinned},
    );
  }

  Future<bool> setMessageHidden({
    required String classId,
    required String messageId,
    required bool hidden,
  }) {
    return _moderateMessage(
      classId: classId,
      messageId: messageId,
      updates: {'is_hidden': hidden},
    );
  }

  Future<bool> _moderateMessage({
    required String classId,
    required String messageId,
    required Map<String, dynamic> updates,
  }) async {
    final id = classId.trim().toUpperCase();
    if (messageId.trim().isEmpty) return false;
    if (!AuthService.isFirebaseLive) return false;
    if (firestoreFailureSimulated != null) return false;

    final uid = currentUserId;
    if (uid.isEmpty) return false;

    try {
      final cls = await _resolveAcademicClass(id);
      if (!ClassGroupAccess.canModerate(currentProfile, id, cls)) {
        return false;
      }
      await _firestore
          .collection('class_groups')
          .doc(id)
          .collection('messages')
          .doc(messageId)
          .update({
        ...updates,
        'moderated_by': uid,
        'moderated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (!_isNoAppException(e)) {
        debugPrint('Class group moderation failed: $e');
      }
      return false;
    }
  }

  Future<bool> deleteClassMessage({
    required String classId,
    required String messageId,
  }) async {
    final id = classId.trim().toUpperCase();
    if (messageId.trim().isEmpty) return false;
    if (!AuthService.isFirebaseLive) return false;
    if (firestoreFailureSimulated != null) return false;

    try {
      final cls = await _resolveAcademicClass(id);
      if (!ClassGroupAccess.canModerate(currentProfile, id, cls)) {
        return false;
      }
      await _firestore
          .collection('class_groups')
          .doc(id)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (e) {
      if (!_isNoAppException(e)) {
        debugPrint('Class group delete failed: $e');
      }
      return false;
    }
  }

  Future<AcademicClass?> _resolveAcademicClass(String classId) async {
    final id = classId.trim().toUpperCase();
    final cached = _cachedClass(id);
    if (!AuthService.isFirebaseLive) return cached;
    try {
      final snap = await _firestore
          .collection('academic_classes')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 4));
      if (snap.exists) {
        final cls = AcademicClass.fromFirestore(snap);
        final list = AuthService.getCachedAcademicClasses();
        final idx = list.indexWhere(
          (c) => c.classId.trim().toUpperCase() == id,
        );
        if (idx != -1) {
          list[idx] = cls;
        } else {
          list.add(cls);
        }
        await AuthService.cacheAcademicClasses(list);
        return cls;
      }
    } catch (_) {}
    return cached;
  }

  static bool _isNoAppException(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('no-app') || s.contains('no firebase app');
  }
}
