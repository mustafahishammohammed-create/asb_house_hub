import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
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
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  Map<String, Map<String, dynamic>> _userProfiles = {};
  final Set<String> _fetchingUids = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _usersSubscription = _chatService.getAllUsersStream().listen((snapshot) {
      if (mounted) {
        setState(() {
          _userProfiles = {
            for (final doc in snapshot.docs)
              doc.id: _safeData(doc),
          };
        });
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchUserIfNeeded(String uid) {
    if (uid.isEmpty || uid == 'unknown' || _userProfiles.containsKey(uid) || _fetchingUids.contains(uid)) {
      return;
    }
    _fetchingUids.add(uid);
    try {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _userProfiles[uid] = _safeData(doc);
          });
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  String _getMyHouse() {
    final myUid = _chatService.currentUserId;
    if (_userProfiles.containsKey(myUid)) {
      final h = AuthService.extractHouse(_userProfiles[myUid]);
      if (h != null && h.isNotEmpty) return h;
    }
    final cached = AuthService.getCachedHouse();
    if (cached != null && cached.isNotEmpty) return cached;
    final profile = AuthService.getCachedProfile();
    final profileHouse = AuthService.extractHouse(profile);
    if (profileHouse != null && profileHouse.isNotEmpty) return profileHouse;
    return 'ruby';
  }

  String _resolveUserHouse({
    required String uid,
    Map<String, dynamic>? userDoc,
    Map<String, dynamic>? housesMap,
    Map<String, dynamic>? rolesMap,
    Map<String, dynamic>? namesMap,
  }) {
    // 1. From Firestore users doc
    if (userDoc != null) {
      final h = AuthService.extractHouse(userDoc);
      if (h != null && h.isNotEmpty) return h;
      final scholarNo = userDoc['scholar_no']?.toString();
      if (scholarNo != null && scholarNo.isNotEmpty) {
        final inferred = AuthService.inferHouseFromScholarNo(scholarNo);
        if (inferred != null && inferred.isNotEmpty) return inferred;
      }
    }

    // 2. From participant_houses map in chat doc
    if (housesMap != null && housesMap.containsKey(uid)) {
      final h = AuthService.extractHouse({'house_name': housesMap[uid]});
      if (h != null && h.isNotEmpty) return h;
    }

    // 3. From saved accounts on this device (sibling / family switch)
    for (final acc in AuthService.getSavedAccounts()) {
      if (acc.uid == uid || acc.scholarNo == uid) {
        return acc.houseName.toLowerCase();
      }
    }

    // 4. From participant_roles or participant_names text
    if (rolesMap != null && rolesMap.containsKey(uid)) {
      final h = AuthService.extractHouse({'house_name': rolesMap[uid]});
      if (h != null && h.isNotEmpty) return h;
    }
    if (namesMap != null && namesMap.containsKey(uid)) {
      final h = AuthService.extractHouse({'house_name': namesMap[uid]});
      if (h != null && h.isNotEmpty) return h;
    }

    // 5. From known officer / student roster names
    final nameStr = (namesMap?[uid] ?? userDoc?['full_name'] ?? '').toString().toLowerCase();
    if (nameStr.contains('noaman') || nameStr.contains('saakshat') || nameStr.contains('ann binu')) {
      return 'emerald';
    }
    if (nameStr.contains('vance') || nameStr.contains('elizabeth') || nameStr.contains('tanish')) {
      return 'sapphire';
    }
    if (nameStr.contains('nayla') || nameStr.contains('galwin') || nameStr.contains('topaz')) {
      return 'topaz';
    }
    if (nameStr.contains('mustafa') || nameStr.contains('hisham') || nameStr.contains('sarah paul')) {
      return 'ruby';
    }

    // 6. Infer from UID if UID matches a scholar number
    final inferred = AuthService.inferHouseFromScholarNo(uid);
    if (inferred != null && inferred.isNotEmpty) return inferred;

    return 'ruby';
  }

  String _resolveUserRole({
    required String uid,
    Map<String, dynamic>? userDoc,
    Map<String, dynamic>? rolesMap,
    required String name,
    required String house,
  }) {
    if (userDoc != null) {
      final scholarNo = userDoc['scholar_no']?.toString();
      final rawRole = userDoc['role']?.toString();
      return HierarchyService.getRoleDisplayTitle(
        scholarNo: scholarNo,
        role: rawRole,
        fullName: name,
      );
    }
    final rawRole = rolesMap?[uid]?.toString() ?? '';
    final rawLower = rawRole.toLowerCase();
    if (rawLower.contains('captain')) return 'House Captain';
    if (rawLower.contains('council') || rawLower.contains('admin')) {
      return HierarchyService.getRoleDisplayTitle(
        fullName: name,
        role: 'council',
      );
    }
    if (rawLower.contains('prefect')) return 'Grade Prefect';
    if (rawLower.contains('teacher') || rawLower.contains('faculty')) return 'Faculty Lead';
    return HierarchyService.getRoleDisplayTitle(fullName: name);
  }

  Color _getRoleOrHouseColor(String role, [String house = '']) {
    final h = house.toLowerCase().trim();
    if (h == 'sapphire' || h.contains('sapphire')) return HouseColors.sapphire;
    if (h == 'emerald' || h.contains('emerald')) return HouseColors.emerald;
    if (h == 'topaz' || h.contains('topaz')) return HouseColors.topaz;
    if (h == 'ruby' || h.contains('ruby')) return HouseColors.ruby;
    final r = role.toLowerCase().trim();
    if (r.contains('sapphire')) return HouseColors.sapphire;
    if (r.contains('emerald')) return HouseColors.emerald;
    if (r.contains('topaz')) return HouseColors.topaz;
    if (r.contains('ruby')) return HouseColors.ruby;
    if (r.contains('teacher') || r.contains('faculty') || r.contains('advisor')) {
      return Colors.indigoAccent;
    }
    return HouseColors.ruby;
  }

  String _formatRoleBadge(String house, String role) {
    final h = house.trim().toUpperCase();
    var r = role.trim();
    if (r.contains('(')) {
      r = r.split('(').first.trim();
    }
    final rLower = r.toLowerCase();
    if (rLower == 'council/admin' || rLower == 'admin') {
      r = 'Student Council';
    }
    final rUpper = r.toUpperCase();
    if (rUpper == 'STUDENT MEMBER' || rUpper == 'STUDENT') {
      return h.isNotEmpty ? '$h • STUDENT' : 'STUDENT';
    }
    if (h.isNotEmpty) {
      if (rUpper.contains(h)) {
        return rUpper;
      }
      return '$h • $rUpper';
    }
    return rUpper;
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
    String otherUserHouse = 'ruby',
    String? myUserHouse,
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
        otherUserHouse: otherUserHouse,
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
            otherUserId: otherUserId,
            otherUserHouse: otherUserHouse,
            myUserHouse: myUserHouse ?? _getMyHouse(),
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
                  final housesMap = Map<String, dynamic>.from(
                    data['participant_houses'] ?? {},
                  );

                  // Find the other user's ID
                  final otherUid = participants.firstWhere(
                    (id) => id != myUid && id.isNotEmpty,
                    orElse: () => 'unknown',
                  );

                  if (otherUid != 'unknown') {
                    _fetchUserIfNeeded(otherUid);
                  }

                  final otherUserDoc = _userProfiles[otherUid];
                  final myUserDoc = _userProfiles[myUid];

                  // Dynamically resolve other user's actual name
                  final otherName = otherUserDoc?['full_name']?.toString() ??
                      namesMap[otherUid]?.toString() ??
                      'Student';

                  // Dynamically resolve other user's actual house (Emerald, Sapphire, Ruby, Topaz)
                  final otherHouse = _resolveUserHouse(
                    uid: otherUid,
                    userDoc: otherUserDoc,
                    housesMap: housesMap,
                    rolesMap: rolesMap,
                    namesMap: namesMap,
                  );

                  // Dynamically resolve my own house
                  final myHouse = AuthService.extractHouse(myUserDoc) ??
                      AuthService.extractHouse({'house_name': housesMap[myUid]}) ??
                      _getMyHouse();

                  // Dynamically resolve other user's actual role title
                  final otherRole = _resolveUserRole(
                    uid: otherUid,
                    userDoc: otherUserDoc,
                    rolesMap: rolesMap,
                    name: otherName,
                    house: otherHouse,
                  );

                  // Self-heal participant_houses if missing in Firestore chat room doc
                  if (!housesMap.containsKey(otherUid) || !housesMap.containsKey(myUid)) {
                    try {
                      docs[index].reference.update({
                        'participant_houses.$myUid': myHouse,
                        'participant_houses.$otherUid': otherHouse,
                      }).catchError((_) {});
                    } catch (_) {}
                  }

                  final lastMsg =
                      data['last_message']?.toString() ?? 'Chat started';
                  final unreadCount =
                      (data['unread_$myUid'] as num?)?.toInt() ?? 0;

                  // Dynamic house colors for avatar, badge, border, and glow
                  final partnerColor = _getRoleOrHouseColor(otherRole, otherHouse);
                  final partnerDarkColor = HouseColors.getHouseDarkColor(otherHouse);
                  final badgeText = _formatRoleBadge(otherHouse, otherRole);

                  return InkWell(
                    onTap: () => _openChatRoom(
                      otherUserId: otherUid,
                      otherUserName: otherName,
                      otherUserRole: otherRole,
                      otherUserHouse: otherHouse,
                      myUserHouse: myHouse,
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
                                      partnerDarkColor,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
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
                                        border: Border.all(
                                          color: partnerColor.withValues(alpha: 0.3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        badgeText,
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
                  myData['scholar_no']?.toString(),
                );
              } catch (_) {}
              if (!amICouncil) {
                final cachedProfile = AuthService.getCachedProfile();
                if (cachedProfile != null) {
                  amICouncil = ChatService.isCouncilOrAdminRole(
                    cachedProfile['role']?.toString(),
                    cachedProfile['full_name']?.toString(),
                    cachedProfile['scholar_no']?.toString(),
                  );
                }
              }

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
                        suffixIcon: _searchQuery.isNotEmpty
                            ? Semantics(
                                button: true,
                                label: 'Clear search',
                                child: IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 20),
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                              )
                            : null,
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
                              final name = data['full_name']?.toString() ?? 'Student';
                              final rawRole = data['role']?.toString() ?? 'student';
                              final scholarNo = data['scholar_no']?.toString() ?? '';
                              final house = AuthService.extractHouse(data) ??
                                  AuthService.inferHouseFromScholarNo(scholarNo) ??
                                  'ruby';
                              final roleTitle = HierarchyService.getRoleDisplayTitle(
                                scholarNo: scholarNo,
                                role: rawRole,
                                fullName: name,
                              );
                              final houseColor = HouseColors.getHouseColor(house);

                              return InkWell(
                                onTap: () => _openChatRoom(
                                  otherUserId: doc.id,
                                  otherUserName: name,
                                  otherUserRole: roleTitle,
                                  otherUserHouse: house,
                                  myUserHouse: _getMyHouse(),
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
                                            houseColor.withValues(alpha: 0.2),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: houseColor,
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
                                              'Scholar ID: $scholarNo • House: ${house.toUpperCase()} • $roleTitle',
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
                                            otherUserRole: roleTitle,
                                            otherUserHouse: house,
                                            myUserHouse: _getMyHouse(),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(84, 38),
                                          backgroundColor: houseColor,
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
