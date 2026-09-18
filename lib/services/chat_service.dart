import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  static bool isCouncilOrAdminRole(String? role, String? name) {
    final roleStr = (role ?? '').toString().toLowerCase();
    final nameStr = (name ?? '').toString().toLowerCase();
    final isAuthorizedName =
        nameStr.contains('mustafa') ||
        nameStr.contains('noaman') ||
        nameStr.contains('nayla') ||
        nameStr.contains('saakshat') ||
        nameStr.contains('galwin') ||
        nameStr.contains('sarah') ||
        nameStr.contains('tanish') ||
        nameStr.contains('ann binu');
    return roleStr == 'super_admin' ||
        roleStr == 'admin' ||
        roleStr == 'captain' ||
        roleStr == 'head_of_activities' ||
        roleStr == 'council' ||
        roleStr == 'prefect' ||
        roleStr == 'teacher' ||
        isAuthorizedName;
  }

  /// Stream of all chat rooms where the logged-in user is a participant.
  /// Because we filter by `participants arrayContains currentUserId`,
  /// Council Member A will NEVER see Council Member B's chats!
  Stream<QuerySnapshot> getMyChatsStream() {
    if (currentUserId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .snapshots();
  }

  /// Stream of all registered users in the app so Council can pick anyone to start chatting.
  Stream<QuerySnapshot> getAllUsersStream() {
    return _firestore.collection('users').snapshots();
  }

  /// Generates a deterministic private room ID between two users and creates the room if needed.
  Future<String> getOrCreateChatRoom({
    required String otherUserId,
    required String otherUserName,
    required String otherUserRole,
  }) async {
    final myUid = currentUserId;
    if (myUid.isEmpty) throw Exception('User not logged in');

    // Fetch my profile name and role
    String myName = 'Council / Admin';
    String myRole = 'admin';
    try {
      final myDoc = await _firestore.collection('users').doc(myUid).get();
      if (myDoc.exists) {
        myName = myDoc.data()?['full_name'] ?? 'Council / Admin';
        myRole = myDoc.data()?['role'] ?? 'admin';
      }
    } catch (_) {}

    // Security Rule: Students cannot chat with other students! At least one participant must be council/admin.
    final amICouncil = isCouncilOrAdminRole(myRole, myName);
    final isOtherCouncil = isCouncilOrAdminRole(otherUserRole, otherUserName);
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
        'participant_names': {myUid: myName, otherUserId: otherUserName},
        'participant_roles': {
          myUid: amICouncil ? 'Council/Admin' : 'Student',
          otherUserId: otherUserRole,
        },
        'unread_$myUid': 0,
        'unread_$otherUserId': 0,
        'last_message': 'Chat started',
        'last_updated': FieldValue.serverTimestamp(),
      });
    }

    return roomId;
  }

  /// Stream of messages in a specific chat room.
  Stream<QuerySnapshot> getMessagesStream(String roomId) {
    return _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
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

      final batch = _firestore.batch();
      for (var doc in unreadQuery.docs) {
        if (doc.data()['sender_id'] != myUid) {
          batch.update(doc.reference, {
            'is_read': true,
            'read_at': FieldValue.serverTimestamp(),
          });
        }
      }
      if (unreadQuery.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (_) {}
  }

  /// Send a message in a private chat room with push alert hooks and unread counter increment.
  Future<void> sendMessage(
    String roomId,
    String text, {
    String? receiverId,
  }) async {
    final myUid = currentUserId;
    if (myUid.isEmpty || text.trim().isEmpty) return;

    String senderName = 'Me';
    try {
      final myDoc = await _firestore.collection('users').doc(myUid).get();
      if (myDoc.exists) {
        senderName = myDoc.data()?['full_name'] ?? 'Me';
      }
    } catch (_) {}

    final timestamp = FieldValue.serverTimestamp();

    // Add message with read receipt tracking
    await _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .add({
          'sender_id': myUid,
          'sender_name': senderName,
          'text': text.trim(),
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
      'last_message': text.trim(),
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
              'body': text.trim(),
              'timestamp': timestamp,
              'is_read': false,
              'type': 'chat_message',
              'room_id': roomId,
            });
      } catch (_) {}
    }
  }
}
