import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../widgets/academic_image.dart';
import '../theme/app_theme.dart';

/// Atmospheric wallpaper that blends both participants' house colors
/// with smooth fade and ambient glowing gradients.
class DualHouseWallpaper extends StatelessWidget {
  final String senderHouse;
  final String recipientHouse;
  final bool isDark;
  final double pulseValue;

  const DualHouseWallpaper({
    super.key,
    required this.senderHouse,
    required this.recipientHouse,
    required this.isDark,
    this.pulseValue = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final senderColor = HouseColors.getHouseColor(senderHouse);
    final recipientColor = HouseColors.getHouseColor(recipientHouse);
    final baseBg = isDark ? const Color(0xFF090D18) : const Color(0xFFF6F8FC);

    final topAlpha = (isDark ? 0.30 : 0.18) * pulseValue;
    final bottomAlpha = (isDark ? 0.32 : 0.20) * pulseValue;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Solid theme base
        Container(color: baseBg),

        // Atmospheric diagonal wash connecting both houses
        AnimatedContainer(
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                recipientColor.withValues(alpha: topAlpha),
                baseBg.withValues(alpha: 0.0),
                senderColor.withValues(alpha: bottomAlpha),
              ],
              stops: const [0.0, 0.52, 1.0],
            ),
          ),
        ),

        // Top ambient orb: Recipient's House Glow (e.g. Emerald Council)
        Positioned(
          top: -120,
          left: -40,
          right: -40,
          height: 380,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 0.95,
                colors: [
                  recipientColor.withValues(alpha: topAlpha * 1.35),
                  recipientColor.withValues(alpha: topAlpha * 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Bottom ambient orb: Sender's House Glow (e.g. Ruby Student)
        Positioned(
          bottom: -100,
          left: -40,
          right: -40,
          height: 380,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomCenter,
                radius: 0.95,
                colors: [
                  senderColor.withValues(alpha: bottomAlpha * 1.35),
                  senderColor.withValues(alpha: bottomAlpha * 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Subtle ambient center convergence light
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  recipientColor.withValues(alpha: topAlpha * 0.5),
                  Colors.transparent,
                  senderColor.withValues(alpha: bottomAlpha * 0.5),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserId;
  final String otherUserHouse;
  final String myUserHouse;

  const ChatRoomScreen({
    super.key,
    required this.roomId,
    required this.otherUserName,
    required this.otherUserRole,
    this.otherUserId,
    this.otherUserHouse = 'ruby',
    this.myUserHouse = 'ruby',
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with TickerProviderStateMixin {
  final _chatService = ChatService();
  final _msgController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  late String _otherName;
  late String _otherRole;
  late String _otherHouse;
  late String _myHouse;
  late String _otherUid;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  String? _lastReadMessageId;
  String? _pendingAttachment;

  @override
  void initState() {
    super.initState();
    _otherName = widget.otherUserName;
    _otherRole = widget.otherUserRole;
    _otherHouse = widget.otherUserHouse;
    _myHouse = widget.myUserHouse;
    _otherUid = widget.otherUserId ?? '';

    // If otherUid is empty, resolve deterministically from roomId
    if (_otherUid.isEmpty) {
      final myUid = _chatService.currentUserId;
      final parts = widget.roomId.split('_');
      if (parts.length == 2) {
        _otherUid = parts[0] == myUid ? parts[1] : parts[0];
      }
    }

    // Refine _myHouse from local cache only if empty
    if (_myHouse.isEmpty) {
      final cached = AuthService.getCachedHouse();
      if (cached != null && cached.isNotEmpty) {
        _myHouse = cached;
      }
    }

    // Refine _otherHouse only if empty
    if (_otherHouse.isEmpty) {
      final fromRole = AuthService.extractHouse({'house_name': _otherRole});
      if (fromRole != null && fromRole.isNotEmpty) {
        _otherHouse = fromRole;
      } else {
        final fromName = AuthService.extractHouse({'house_name': _otherName});
        if (fromName != null && fromName.isNotEmpty) {
          _otherHouse = fromName;
        } else {
          final fromScholar = AuthService.inferHouseFromScholarNo(_otherUid);
          if (fromScholar != null && fromScholar.isNotEmpty) {
            _otherHouse = fromScholar;
          }
        }
      }
    }

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();

    try {
      _chatService.markRoomAsRead(widget.roomId);
    } catch (_) {}
    _listenToRoomDoc();
    _fetchUsersFallback();
  }

  void _listenToRoomDoc() {
    try {
      _roomSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.roomId)
          .snapshots()
          .listen((docSnap) {
        if (!docSnap.exists || !mounted) return;
        final d = docSnap.data();
        if (d == null) return;
        final houses = Map<String, dynamic>.from(d['participant_houses'] ?? {});
        final names = Map<String, dynamic>.from(d['participant_names'] ?? {});
        final roles = Map<String, dynamic>.from(d['participant_roles'] ?? {});
        final myUid = _chatService.currentUserId;

        setState(() {
          if (houses.containsKey(myUid)) {
            final h = AuthService.extractHouse({'house_name': houses[myUid]});
            if (h != null && h.isNotEmpty) _myHouse = h;
          }
          if (_otherUid.isNotEmpty && houses.containsKey(_otherUid)) {
            final h = AuthService.extractHouse({'house_name': houses[_otherUid]});
            if (h != null && h.isNotEmpty) _otherHouse = h;
          }
          if (_otherUid.isNotEmpty && names.containsKey(_otherUid)) {
            final n = names[_otherUid]?.toString();
            if (n != null && n.isNotEmpty) _otherName = n;
          }
          if (_otherUid.isNotEmpty && roles.containsKey(_otherUid)) {
            final r = roles[_otherUid]?.toString();
            if (r != null && r.isNotEmpty) _otherRole = r;
          }
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  void _fetchUsersFallback() async {
    final myUid = _chatService.currentUserId;
    bool needsRoomUpdate = false;
    String resolvedOtherHouse = _otherHouse;
    String resolvedMyHouse = _myHouse;

    if (_otherUid.isNotEmpty) {
      try {
        final otherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_otherUid)
            .get();
        if (otherDoc.exists && mounted) {
          final od = otherDoc.data() ?? {};
          final h = AuthService.extractHouse(od) ??
              AuthService.inferHouseFromScholarNo(od['scholar_no']?.toString() ?? '');
          final n = od['full_name']?.toString();
          final r = HierarchyService.getRoleDisplayTitle(
            scholarNo: od['scholar_no']?.toString(),
            role: od['role']?.toString(),
            fullName: n ?? _otherName,
          );
          if (h != null && h.isNotEmpty && h != _otherHouse) {
            resolvedOtherHouse = h;
            needsRoomUpdate = true;
          }
          setState(() {
            if (h != null && h.isNotEmpty) _otherHouse = h;
            if (n != null && n.isNotEmpty) _otherName = n;
            _otherRole = r;
          });
        }
      } catch (_) {}
    }
    if (myUid.isNotEmpty) {
      try {
        final myDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .get();
        if (myDoc.exists && mounted) {
          final md = myDoc.data() ?? {};
          final h = AuthService.extractHouse(md);
          if (h != null && h.isNotEmpty) {
            if (h != _myHouse) {
              resolvedMyHouse = h;
              needsRoomUpdate = true;
            }
            setState(() => _myHouse = h);
          }
        }
      } catch (_) {}
    }

    if (needsRoomUpdate && widget.roomId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.roomId)
            .update({
          'participant_houses.$myUid': resolvedMyHouse,
          'participant_houses.$_otherUid': resolvedOtherHouse,
        });
      } catch (_) {}
    }
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

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    try {
      final picked = await picker.pickImage(source: source, maxWidth: 800, imageQuality: 70);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final encoded = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (!mounted) return;
        if (encoded.length > 900000) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image is too large for Firestore (max ~650 KB). Please pick a smaller image.'),
            ),
          );
          return;
        }
        setState(() {
          _pendingAttachment = encoded;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not attach image: $e')));
      }
    }
  }

  void _send() async {
    final text = _msgController.text.trim();
    final attachment = _pendingAttachment;
    if ((text.isEmpty && (attachment == null || attachment.isEmpty)) || _isSending) return;
    _isSending = true;
    AppHaptics.light();
    _msgController.clear();
    setState(() => _pendingAttachment = null);
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
    var sent = false;
    try {
      await _chatService.sendMessage(
        widget.roomId,
        text.isNotEmpty ? text : '📷 Photo Attachment',
        attachmentUrl: attachment,
      );
      sent = true;
    } catch (_) {
      if (mounted) {
        _msgController.text = text;
        _pendingAttachment = attachment;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send message. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      } else {
        _isSending = false;
      }
    }
    if (!sent || !mounted) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuad,
      );
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _fadeController.dispose();
    _focusNode.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _chatService.currentUserId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final myColor = HouseColors.getHouseColor(_myHouse);
    final myDarkColor = HouseColors.getHouseDarkColor(_myHouse);
    final otherColor = HouseColors.getHouseColor(_otherHouse);
    final otherDarkColor = HouseColors.getHouseDarkColor(_otherHouse);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D18) : const Color(0xFFF6F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: (isDark ? const Color(0xFF111827) : Colors.white).withValues(alpha: 0.95),
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        otherColor,
                        otherDarkColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: otherColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _otherName.isNotEmpty
                        ? _otherName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF111827) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherName,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: otherColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: otherColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _formatRoleBadge(_otherHouse, _otherRole),
                          style: TextStyle(
                            fontSize: 9.5,
                            color: otherColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• Private',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 13, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Direct',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // DUAL-HOUSE ATMOSPHERIC WALLPAPER WITH SMOOTH FADE
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: DualHouseWallpaper(
                senderHouse: _myHouse,
                recipientHouse: _otherHouse,
                isDark: isDark,
                pulseValue: 1.0,
              ),
            ),
          ),

          // Main Conversation Column
          Column(
            children: [
              // Dual-House Atmospheric Alliance Header Chip
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF131B2E) : Colors.white)
                        .withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        HouseColors.getHouseEmoji(_myHouse),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _myHouse.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: myColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          size: 15,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                      Text(
                        _otherHouse.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: otherColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        HouseColors.getHouseEmoji(_otherHouse),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Messages List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMessagesStream(widget.roomId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: otherColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mark_chat_unread_rounded,
                                size: 44,
                                color: otherColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Direct confidential chat between ${_myHouse.toUpperCase()} and ${_otherHouse.toUpperCase()}.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isNotEmpty) {
                      final latestDoc = docs.first;
                      final latestData = _safeData(latestDoc);
                      if (latestData['sender_id'] != myUid &&
                          latestData['is_read'] != true &&
                          _lastReadMessageId != latestDoc.id) {
                        _lastReadMessageId = latestDoc.id;
                        Future.microtask(
                          () => _chatService.markRoomAsRead(widget.roomId),
                        );
                      }
                    }

                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = _safeData(docs[index]);
                        final isMe = data['sender_id'] == myUid;
                        final text = data['text'] ?? '';
                        final isRead = data['is_read'] == true;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.76,
                            ),
                            decoration: BoxDecoration(
                              gradient: isMe
                                  ? LinearGradient(
                                      colors: [
                                        myColor,
                                        myDarkColor,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isMe
                                  ? null
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isMe ? 20 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 20),
                              ),
                              border: isMe
                                  ? null
                                  : Border.all(
                                      color: isDark
                                          ? otherColor.withValues(alpha: 0.25)
                                          : otherColor.withValues(alpha: 0.25),
                                      width: 1,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: isMe
                                      ? myColor.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  Text(
                                    data['sender_name'] ?? _otherName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: otherColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (data['attachment_url'] != null && data['attachment_url'].toString().isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: GestureDetector(
                                      onTap: () => showAcademicImagePreview(
                                        context,
                                        data['attachment_url'].toString(),
                                        data['sender_name'] ?? 'Attachment',
                                      ),
                                      child: Container(
                                        constraints: const BoxConstraints(maxHeight: 180, maxWidth: 220),
                                        child: buildAcademicImage(data['attachment_url'].toString(), fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.35,
                                    color: isMe
                                        ? Colors.white
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isMe) ...[
                                      Text(
                                        isRead ? 'Read' : 'Sent',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        isRead
                                            ? Icons.done_all_rounded
                                            : Icons.done_rounded,
                                        size: 13,
                                        color: isRead
                                            ? Colors.cyanAccent
                                            : Colors.white70,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Message Input Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_pendingAttachment != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: myColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: buildAcademicImage(_pendingAttachment!, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Image attachment ready to send', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () => setState(() => _pendingAttachment = null),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.attach_file_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                            tooltip: 'Attach Image / Photo',
                            onPressed: _pickAttachment,
                          ),
                          Expanded(
                            child: TextField(
                          controller: _msgController,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.send,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.grey[400],
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: myColor.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _send,
                          borderRadius: BorderRadius.circular(24),
                          child: Ink(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  myColor,
                                  myDarkColor,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: myColor.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
