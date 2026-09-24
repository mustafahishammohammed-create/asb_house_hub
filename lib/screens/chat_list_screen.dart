import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _chatService = ChatService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getRoleOrHouseColor(String role, [String house = '']) {
    final r = role.toLowerCase();
    final h = house.toLowerCase();
    if (r.contains('admin') || r.contains('principal') || r.contains('super')) {
      return Colors.amber;
    }
    if (r.contains('teacher') || r.contains('faculty') || r.contains('advisor')) {
      return Colors.indigoAccent;
    }
    if (h.contains('sapphire') || r.contains('sapphire')) return HouseColors.sapphire;
    if (h.contains('emerald') || r.contains('emerald')) return HouseColors.emerald;
    if (h.contains('topaz') || r.contains('topaz')) return HouseColors.topaz;
    return HouseColors.ruby;
  }

  Map<String, dynamic> _safeData(DocumentSnapshot doc) {
    try {
      final d = doc.data();
      if (d is Map<String, dynamic>) return d;
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return {};
  }

  void _openChatRoom({
    required String otherUserId,
    required String otherUserName,
    required String otherUserRole,
  }) async {
    AppHaptics.light();
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final roomId = await _chatService.getOrCreateChatRoom(
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserRole: otherUserRole,
      );
      if (!mounted) return;
      Navigator.pop(context); // close loader
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            roomId: roomId,
            otherUserName: otherUserName,
            otherUserRole: otherUserRole,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _chatService.currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(
              Icons.mark_chat_unread_rounded,
              color: HouseColors.ruby,
              size: 26,
            ),
            SizedBox(width: 10),
            Text(
              '1-on-1 Student Chats',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: HouseColors.ruby,
          unselectedLabelColor: Colors.grey,
          indicatorColor: HouseColors.ruby,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: '💬 Active Conversations'),
            Tab(text: '➕ Start New Chat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: ACTIVE CHATS (Strictly private to this specific logged-in admin)
          StreamBuilder<QuerySnapshot>(
            stream: _chatService.getMyChatsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_person_rounded,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Active Chats',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You have no private 1-on-1 conversations yet.\nSwitch to the "Start New Chat" tab to message anyone registered in the app.\n\nNote: Conversations do not sync with other admins.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = _safeData(docs[index]);
                  final participants = List<String>.from(
                    data['participants'] ?? [],
                  );
                  final namesMap = Map<String, dynamic>.from(
                    data['participant_names'] ?? {},
                  );
                  final rolesMap = Map<String, dynamic>.from(
                    data['participant_roles'] ?? {},
                  );

                  // Find the other user's ID
                  final otherUid = participants.firstWhere(
                    (id) => id != myUid,
                    orElse: () => 'unknown',
                  );
                  final otherName = namesMap[otherUid]?.toString() ?? 'Student';
                  final otherRole = rolesMap[otherUid]?.toString() ?? 'Student';
                  final lastMsg =
                      data['last_message']?.toString() ?? 'Chat started';
                  final unreadCount =
                      (data['unread_$myUid'] as num?)?.toInt() ?? 0;
                  final partnerColor = _getRoleOrHouseColor(otherRole);

                  return InkWell(
                    onTap: () => _openChatRoom(
                      otherUserId: otherUid,
                      otherUserName: otherName,
                      otherUserRole: otherRole,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: unreadCount > 0
                              ? partnerColor
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0)),
                          width: unreadCount > 0 ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: unreadCount > 0
                                ? partnerColor.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      partnerColor,
                                      partnerColor.withValues(alpha: 0.7),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: partnerColor.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  otherName.isNotEmpty
                                      ? otherName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                  ),
                                ),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: partnerColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF131B2E) : Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        otherName,
                                        style: TextStyle(
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w900
                                              : FontWeight.w800,
                                          fontSize: 15.5,
                                          letterSpacing: -0.3,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: partnerColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        otherRole.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: partnerColor,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMsg,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: unreadCount > 0
                                              ? (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                              : Colors.grey[600],
                                          fontSize: 13,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (unreadCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: partnerColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'NEW',
                                          style: TextStyle(
                                            color: partnerColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // TAB 2: REGISTERED USERS DIRECTORY (Filtered for Students vs Council)
          StreamBuilder<QuerySnapshot>(
            stream: _chatService.getAllUsersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No registered users found.'));
              }

              // Check logged-in user role
              bool amICouncil = false;
              try {
                final myDoc = snapshot.data!.docs.firstWhere(
                  (doc) => doc.id == myUid,
                );
                final myData = _safeData(myDoc);
                amICouncil = ChatService.isCouncilOrAdminRole(
                  myData['role'],
                  myData['full_name'],
                );
              } catch (_) {}

              final allUsers = snapshot.data!.docs.where((doc) {
                if (doc.id == myUid) return false; // don't show self
                final data = _safeData(doc);

                // If I am a student, ONLY show council members or teachers! Never show other students.
                if (!amICouncil) {
                  final isDocCouncil = ChatService.isCouncilOrAdminRole(
                    data['role'],
                    data['full_name'],
                  );
                  if (!isDocCouncil) return false;
                }

                final name = (data['full_name'] ?? '').toString().toLowerCase();
                final scholar = (data['scholar_no'] ?? '')
                    .toString()
                    .toLowerCase();
                if (_searchQuery.isEmpty) return true;
                return name.contains(_searchQuery) ||
                    scholar.contains(_searchQuery);
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(
                        () => _searchQuery = val.trim().toLowerCase(),
                      ),
                      decoration: InputDecoration(
                        hintText: amICouncil
                            ? 'Search student by name or scholar number...'
                            : 'Search Council Member or Teacher...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1A2338)
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: allUsers.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                amICouncil
                                    ? 'No matching students found.'
                                    : 'No matching Council Members or Teachers found.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: allUsers.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final doc = allUsers[index];
                              final data = _safeData(doc);
                              final name = data['full_name'] ?? 'Student';
                              final role = data['role'] ?? 'student';
                              final house = data['house'] ?? 'Ruby';
                              final scholarNo = data['scholar_no'] ?? '';

                              return InkWell(
                                onTap: () => _openChatRoom(
                                  otherUserId: doc.id,
                                  otherUserName: name,
                                  otherUserRole: '$role ($house)',
                                ),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1A2338)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            HouseColors.getHouseColor(
                                              house,
                                            ).withValues(alpha: 0.2),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: HouseColors.getHouseColor(
                                              house,
                                            ),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Scholar ID: $scholarNo • House: $house',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          AppHaptics.light();
                                          _openChatRoom(
                                            otherUserId: doc.id,
                                            otherUserName: name,
                                            otherUserRole: '$role ($house)',
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(84, 38),
                                          backgroundColor: _getRoleOrHouseColor(role, house),
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'Chat',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
