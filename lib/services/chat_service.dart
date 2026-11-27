import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'hierarchy_service.dart';

class ChatService {
  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  ChatService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _customAuth = auth,
        _customFirestore = firestore;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  String get currentUserId {
    try {
      final uid = _auth.currentUser?.uid ?? '';
      if (uid.isNotEmpty) return uid;
    } catch (_) {}
    try {
      final cached = AuthService.getCachedProfile();
      final uid = cached?['uid']?.toString() ?? '';
      if (uid.isNotEmpty) return uid;
    } catch (_) {}
    return '';
  }

  static bool isCouncilOrAdminRole(String? role, String? name, [String? scholarNo]) {
    return HierarchyService.isCouncilOrTeacher(
      scholarNo: scholarNo,
      role: role,
      fullName: name,
    );
  }

  /// Stream of all chat rooms where the logged-in user is a participant.
  /// Because we filter by `participants arrayContains currentUserId`,
  /// Council Member A will NEVER see Council Member B's chats!
  Stream<QuerySnapshot> getMyChatsStream() {
    try {
      if (currentUserId.isEmpty) return const Stream.empty();
      return _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Stream of registered users so authorised members can pick a permitted peer.
  Stream<QuerySnapshot> getAllUsersStream({int limit = 200}) {
    try {
      return _firestore.collection('users').limit(limit).snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Generates a deterministic private room ID between two users and creates the room if needed.
  Future<String> getOrCreateChatRoom({
    required String otherUserId,
    required String otherUserName,
    required String otherUserRole,
    String? otherUserHouse,
  }) async {
    final myUid = currentUserId;
    if (myUid.isEmpty) throw Exception('User not logged in');

    // Fetch my profile name, role, and house (fail closed to student if absent)
    String myName = 'Student';
    String myRole = 'student';
    String myHouse = AuthService.getCachedHouse() ?? 'ruby';
    String? myScholar;
    try {
      final myDoc = await _firestore
          .collection('users')
          .doc(myUid)
          .get()
          .timeout(const Duration(seconds: 4));
      if (myDoc.exists) {
        final d = myDoc.data() ?? {};
        myName = d['full_name']?.toString() ?? 'Student';
        myRole = d['role']?.toString() ?? 'student';
        myScholar = d['scholar_no']?.toString();
        final extracted = AuthService.extractHouse(d);
        if (extracted != null && extracted.isNotEmpty) {
          myHouse = extracted;
        }
      }
    } catch (_) {}

    // Fetch other user profile if possible
    String resolvedOtherName = otherUserName;
    String rawOtherRole = otherUserRole;
    String resolvedOtherRole = otherUserRole;
    String resolvedOtherScholar = '';
    String resolvedOtherHouse = otherUserHouse ?? 'ruby';
    try {
      final otherDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .get()
          .timeout(const Duration(seconds: 4));
      if (otherDoc.exists) {
        final od = otherDoc.data() ?? {};
        resolvedOtherName = od['full_name']?.toString() ?? otherUserName;
        final extracted = AuthService.extractHouse(od);
        if (extracted != null && extracted.isNotEmpty) {
          resolvedOtherHouse = extracted;
        }
        final odScholar = od['scholar_no']?.toString();
        final odRole = od['role']?.toString();
        resolvedOtherScholar = odScholar ?? '';
        if (odRole != null && odRole.trim().isNotEmpty) {
          rawOtherRole = odRole;
        }
        resolvedOtherRole = HierarchyService.getRoleDisplayTitle(
          scholarNo: odScholar,
          role: odRole,
          fullName: resolvedOtherName,
        );
      }
    } catch (_) {}

    if (resolvedOtherHouse.isEmpty || resolvedOtherHouse == 'ruby') {
      final fromRole = AuthService.extractHouse({'house_name': otherUserRole});
      if (fromRole != null && fromRole.isNotEmpty) {
        resolvedOtherHouse = fromRole;
      }
    }

    final myRoleTitle = HierarchyService.getRoleDisplayTitle(
      scholarNo: myScholar,
      role: myRole,
      fullName: myName,
    );

    // Security Rule: Students cannot chat with other students! At least one participant must be council/admin.
    final amICouncil = isCouncilOrAdminRole(myRole, myName, myScholar);
    final isOtherCouncil =
        isCouncilOrAdminRole(rawOtherRole, resolvedOtherName, resolvedOtherScholar) ||
            isCouncilOrAdminRole(resolvedOtherRole, resolvedOtherName, resolvedOtherScholar);
    if (!amICouncil && !isOtherCouncil) {
      throw Exception(
        'Access Denied: Students are not allowed to chat with other students. You can only message Council Members or Teachers.',
      );
    }

    // Sort UIDs deterministically
    final uids = [myUid, otherUserId]..sort();
    final roomId = '${uids[0]}_${uids[1]}';

    final roomRef = _firestore.collection('chats').doc(roomId);
    final roomSnap = await roomRef.get();

    if (!roomSnap.exists) {
      await roomRef.set({
        'participants': [myUid, otherUserId],
        'participant_names': {myUid: myName, otherUserId: resolvedOtherName},
        'participant_roles': {
          myUid: myRoleTitle,
          otherUserId: resolvedOtherRole,
        },
        'participant_houses': {
          myUid: myHouse,
          otherUserId: resolvedOtherHouse,
        },
        'unread_$myUid': 0,
        'unread_$otherUserId': 0,
        'last_message': 'Chat started',
        'last_updated': FieldValue.serverTimestamp(),
      });
    } else {
      // Sync houses and participant metadata if missing or changed
      final existingData = roomSnap.data() ?? {};
      final existingHouses = Map<String, dynamic>.from(existingData['participant_houses'] ?? {});
      if (!existingHouses.containsKey(myUid) ||
          !existingHouses.containsKey(otherUserId) ||
          existingHouses[otherUserId] != resolvedOtherHouse) {
        existingHouses[myUid] = myHouse;
        existingHouses[otherUserId] = resolvedOtherHouse;
        await roomRef.update({
          'participant_houses': existingHouses,
          'participant_names.$myUid': myName,
          'participant_names.$otherUserId': resolvedOtherName,
          'participant_roles.$myUid': myRoleTitle,
          'participant_roles.$otherUserId': resolvedOtherRole,
        }).catchError((_) {});
      }
    }

    return roomId;
  }

  /// Stream of messages in a specific chat room (bounded).
  Stream<QuerySnapshot> getMessagesStream(String roomId, {int limit = 150}) {
    try {
      return _firestore
          .collection('chats')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Marks unread messages in a room as read for the logged-in user.
  Future<void> markRoomAsRead(String roomId) async {
    final myUid = currentUserId;
    if (myUid.isEmpty) return;
    try {
      await _firestore.collection('chats').doc(roomId).update({
        'unread_$myUid': 0,
      });

      // Mark unread incoming messages as read
      final unreadQuery = await _firestore
          .collection('chats')
          .doc(roomId)
          .collection('messages')
          .where('is_read', isEqualTo: false)
          .get();

      final incoming = unreadQuery.docs
          .where((doc) => doc.data()['sender_id'] != myUid)
          .toList();
      for (var i = 0; i < incoming.length; i += 450) {
        final batch = _firestore.batch();
        final chunk = incoming.sublist(
          i,
          i + 450 > incoming.length ? incoming.length : i + 450,
        );
        for (final doc in chunk) {
          batch.update(doc.reference, {
            'is_read': true,
            'read_at': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (_) {}
  }

  /// Send a message in a private chat room with push alert hooks and unread counter increment.
  Future<void> sendMessage(
    String roomId,
    String text, {
    String? receiverId,
    String? attachmentUrl,
  }) async {
    final myUid = currentUserId;
    if (myUid.isEmpty || (text.trim().isEmpty && (attachmentUrl == null || attachmentUrl.isEmpty))) return;

    String senderName = 'Me';
    try {
      final myDoc = await _firestore.collection('users').doc(myUid).get();
      if (myDoc.exists) {
        senderName = myDoc.data()?['full_name'] ?? 'Me';
      }
    } catch (_) {}

    final timestamp = FieldValue.serverTimestamp();
    final trimmedText = text.trim();
    final summaryText = trimmedText.isNotEmpty ? trimmedText : '📷 Photo';

    // Add message with read receipt tracking
    await _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .add({
          'sender_id': myUid,
          'sender_name': senderName,
          'text': trimmedText,
          if (attachmentUrl != null && attachmentUrl.isNotEmpty) 'attachment_url': attachmentUrl,
          'timestamp': timestamp,
          'is_read': false,
          'push_alert_triggered': true,
        });

    // Determine receiver ID from room ID if not supplied
    String targetId = receiverId ?? '';
    if (targetId.isEmpty) {
      final parts = roomId.split('_');
      if (parts.length == 2) {
        targetId = parts[0] == myUid ? parts[1] : parts[0];
      }
    }

    // Update room summary & unread counter
    final updateMap = <String, dynamic>{
      'last_message': summaryText,
      'last_updated': timestamp,
    };
    if (targetId.isNotEmpty) {
      updateMap['unread_$targetId'] = FieldValue.increment(1);
    }
    await _firestore.collection('chats').doc(roomId).update(updateMap);

    // Trigger Push Alert Hook (writes to user's notifications queue)
    if (targetId.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(targetId)
            .collection('notifications')
            .add({
              'title': 'New Message from $senderName',
              'body': summaryText,
              'timestamp': timestamp,
              'is_read': false,
              'type': 'chat_message',
              'category': 'chat',
              'room_id': roomId,
              'sender_id': myUid,
            });
      } catch (_) {}
    }
  }
}
