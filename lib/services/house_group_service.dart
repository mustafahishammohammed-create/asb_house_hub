import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/house_group.dart';
import 'auth_service.dart';
import 'hierarchy_service.dart';
import 'notification_service.dart';

/// Spark-compatible house group service.
///
/// Membership is never written to Firestore: it is derived from the user's
/// verified `house_name`. The rules enforce the same derivation, so a house
/// transfer revokes the old group and grants the new one without a migration.
class HouseGroupService {
  @visibleForTesting
  static Exception? firestoreFailureSimulated;

  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;
  final NotificationService? _customNotifications;

  HouseGroupService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationService? notifications,
  })  : _customAuth = auth,
        _customFirestore = firestore,
        _customNotifications = notifications;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
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

  String get myHouse => HouseGroupAccess.resolveHouse(currentProfile);

  bool canPostIn(String houseId) =>
      HouseGroupAccess.canSend(currentProfile, houseId);

  bool canModerateIn(String houseId) =>
      HouseGroupAccess.canModerate(currentProfile, houseId);

  /// Stream of the group header. Returns an empty stream when Firebase is not
  /// configured (widget tests) rather than throwing.
  Stream<DocumentSnapshot> getHouseGroupStream(String houseId) {
    try {
      if (!AuthService.isFirebaseLive || currentUserId.isEmpty) {
        return const Stream.empty();
      }
      return _firestore.collection('house_groups').doc(houseId).snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Newest-first message stream, capped to keep Spark reads bounded.
  Stream<List<HouseGroupMessage>> getHouseMessagesStream(String houseId) {
    try {
      if (!AuthService.isFirebaseLive || currentUserId.isEmpty) {
        return const Stream.empty();
      }
      if (!HouseGroupAccess.canView(currentProfile, houseId)) {
        return const Stream.empty();
      }
      return _firestore
          .collection('house_groups')
          .doc(houseId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => HouseGroupMessage.fromMap(doc.id, doc.data()))
              .toList());
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Creates the group header if missing. Only authorised senders may create
  /// it; ordinary students still auto-join without a header write.
  Future<bool> ensureHouseGroup(String houseId) async {
    final id = houseId.trim().toLowerCase();
    if (!AuthService.isFirebaseLive) return false;
    if (!HouseGroupAccess.canSend(currentProfile, id)) return false;
    if (firestoreFailureSimulated != null) return false;
    try {
      final ref = _firestore.collection('house_groups').doc(id);
      final snapshot = await ref.get();
      if (snapshot.exists) return true;
      final now = DateTime.now();
      await ref.set(
        HouseGroup.defaultsFor(id)
            .copyWith(createdAt: now, updatedAt: now)
            .toMap(),
      );
      return true;
    } catch (e) {
      if (!_isNoAppException(e)) {
        debugPrint('House group header create failed: $e');
      }
      return false;
    }
  }

  /// Posts a message. Truthful: returns `false` for unauthorised senders,
  /// offline runtimes, simulated failures, and real Firestore denials.
  Future<bool> sendHouseMessage({
    required String houseId,
    required String text,
    String category = 'general',
    String attachmentUrl = '',
  }) async {
    final id = houseId.trim().toLowerCase();
    final cleanText = text.trim();
    final attachment = attachmentUrl.trim();
    if (cleanText.isEmpty && attachment.isEmpty) return false;
    lastNotificationResult = null;

    var profile = currentProfile;
    if (!HouseGroupAccess.canSend(profile, id)) return false;
    if (!AuthService.isFirebaseLive) return false;

    final uid = currentUserId;
    if (uid.isEmpty) return false;

    try {
      if (firestoreFailureSimulated != null) {
        throw firestoreFailureSimulated!;
      }

      // Prefer the live profile for the sender name/role, falling back to the
      // verified cache when the read is unavailable.
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 4));
        if (userDoc.exists) {
          profile = {...?profile, ...?userDoc.data()};
        }
      } catch (_) {}

      if (!HouseGroupAccess.canSend(profile, id)) return false;

      final senderName = HouseGroupAccess.nameOf(profile);
      final senderRole = HierarchyService.getRoleDisplayTitle(
        scholarNo: HouseGroupAccess.scholarOf(profile),
        role: HouseGroupAccess.roleOf(profile),
        fullName: senderName,
      );
      final timestamp = FieldValue.serverTimestamp();

      final messageRef = await _firestore
          .collection('house_groups')
          .doc(id)
          .collection('messages')
          .add({
        'sender_id': uid,
        'sender_name': senderName,
        'sender_role': senderRole,
        'sender_house': id,
        'text': cleanText,
        'category': normalizeHouseGroupCategory(category),
        'attachment_url': attachment,
        'is_pinned': false,
        'is_hidden': false,
        'moderated_by': '',
        'timestamp': timestamp,
      });

      // Keep the group summary fresh without making the message dependent on
      // it. Parent create/update is allowed for the same sender roles.
      try {
        final groupRef = _firestore.collection('house_groups').doc(id);
        final groupSnap = await groupRef.get();
        if (!groupSnap.exists) {
          final now = DateTime.now();
          await groupRef.set(
            HouseGroup.defaultsFor(id)
                .copyWith(createdAt: now, updatedAt: now)
                .toMap(),
          );
        }
        await groupRef.update({
          'last_message': cleanText.isEmpty ? 'Photo attachment' : cleanText,
          'last_message_at': timestamp,
          'updated_at': timestamp,
        });
      } catch (_) {}

      // M6/test 61: only announcement-category messages fan out. The message is
      // already committed, so a notification failure never reverses the send.
      if (normalizeHouseGroupCategory(category) == 'announcement') {
        try {
          lastNotificationResult = await _notifications.notifyHouseAnnouncement(
            houseId: id,
            messageId: messageRef.id,
            senderUid: uid,
            senderName: senderName,
            preview: cleanText.isEmpty ? 'Photo attachment' : cleanText,
          );
        } catch (e) {
          debugPrint('House announcement notification fan-out failed: $e');
        }
      }

      return true;
    } catch (e) {
      if (!_isNoAppException(e)) {
        debugPrint('House group send failed: $e');
      }
      return false;
    }
  }

  Future<bool> setMessagePinned({
    required String houseId,
    required String messageId,
    required bool pinned,
  }) {
    return _moderateMessage(
      houseId: houseId,
      messageId: messageId,
      updates: {'is_pinned': pinned},
    );
  }

  Future<bool> setMessageHidden({
    required String houseId,
    required String messageId,
    required bool hidden,
  }) {
    return _moderateMessage(
      houseId: houseId,
      messageId: messageId,
      updates: {'is_hidden': hidden},
    );
  }

  Future<bool> _moderateMessage({
    required String houseId,
    required String messageId,
    required Map<String, dynamic> updates,
  }) async {
    final id = houseId.trim().toLowerCase();
    if (messageId.trim().isEmpty) return false;
    if (!HouseGroupAccess.canModerate(currentProfile, id)) return false;
    if (!AuthService.isFirebaseLive) return false;
    final uid = currentUserId;
    if (uid.isEmpty) return false;

    try {
      if (firestoreFailureSimulated != null) {
        throw firestoreFailureSimulated!;
      }
      await _firestore
          .collection('house_groups')
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
        debugPrint('House group moderation failed: $e');
      }
      return false;
    }
  }

  Future<bool> deleteHouseMessage({
    required String houseId,
    required String messageId,
  }) async {
    final id = houseId.trim().toLowerCase();
    if (messageId.trim().isEmpty) return false;
    if (!HouseGroupAccess.canModerate(currentProfile, id)) return false;
    if (!AuthService.isFirebaseLive) return false;

    try {
      if (firestoreFailureSimulated != null) {
        throw firestoreFailureSimulated!;
      }
      await _firestore
          .collection('house_groups')
          .doc(id)
          .collection('messages')
          .doc(messageId)
          .delete();
      return true;
    } catch (e) {
      if (!_isNoAppException(e)) {
        debugPrint('House group delete failed: $e');
      }
      return false;
    }
  }

  static bool _isNoAppException(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('no-app') || s.contains('no firebase app');
  }
}
