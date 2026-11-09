import 'dart:async';

import 'package:flutter/material.dart';

import '../models/academic_class.dart';
import '../models/class_group.dart';
import '../services/auth_service.dart';
import '../services/class_group_service.dart';
import '../services/hierarchy_service.dart';
import '../widgets/academic_image.dart';

/// Per-class group channel.
///
/// Opening this screen *is* joining: membership is resolved from the verified
/// class placement on the profile, so there is no join button and no
/// self-asserted membership document. Class teachers, assigned subject
/// teachers, and class representatives can post; ordinary students are
/// read-only unless the school enables student posting for the class. The same
/// restrictions are enforced in `firestore.rules`, not just here.
class ClassGroupScreen extends StatefulWidget {
  /// Test hook / administrative deep link. Defaults to the signed-in profile's
  /// verified class.
  final String? initialClassId;

  /// Test hook so widget tests can render messages without Firebase.
  final Stream<List<ClassGroupMessage>>? messagesStream;

  /// Test hook so widget tests can supply the registry document directly.
  final AcademicClass? initialAcademicClass;

  const ClassGroupScreen({
    super.key,
    this.initialClassId,
    this.messagesStream,
    this.initialAcademicClass,
  });

  @override
  State<ClassGroupScreen> createState() => _ClassGroupScreenState();
}

class _ClassGroupScreenState extends State<ClassGroupScreen> {
  final _service = ClassGroupService();
  final _authService = AuthService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _profile;
  late String _classId;
  AcademicClass? _academicClass;
  late ClassGroup _group;
  bool _canView = false;
  bool _canPost = false;
  bool _canModerate = false;
  late Stream<List<ClassGroupMessage>> _messagesStream;
  StreamSubscription<AcademicClass>? _classSubscription;

  String _selectedCategory = 'general';
  String _filterCategory = 'all';
  String _pendingAttachment = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _profile = AuthService.getCachedProfile();
    _classId = (widget.initialClassId ??
            ClassGroupAccess.resolveClassId(_profile))
        .trim()
        .toUpperCase();
    _academicClass = widget.initialAcademicClass ?? _cachedClass(_classId);
    _group = ClassGroup.defaultsFor(_classId);
    _recomputeAccess();
    _messagesStream =
        widget.messagesStream ?? _service.getClassMessagesStream(_classId);
    if (_classId.isNotEmpty) {
      _classSubscription = _service
          .getAcademicClassStream(_classId)
          .listen(_onAcademicClassUpdate, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _classSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  AcademicClass? _cachedClass(String classId) {
    final target = classId.trim().toUpperCase();
    if (target.isEmpty) return null;
    for (final cls in AuthService.getCachedAcademicClasses()) {
      if (cls.classId.trim().toUpperCase() == target) return cls;
    }
    return null;
  }

  void _recomputeAccess() {
    _canView = _classId.isNotEmpty &&
        ClassGroupAccess.canView(_profile, _classId, _academicClass);
    _canPost = _classId.isNotEmpty &&
        ClassGroupAccess.canSend(_profile, _classId, _academicClass);
    _canModerate = _classId.isNotEmpty &&
        ClassGroupAccess.canModerate(_profile, _classId, _academicClass);
  }

  void _onAcademicClassUpdate(AcademicClass cls) {
    if (!mounted) return;
    setState(() {
      _academicClass = cls;
      _recomputeAccess();
    });
  }

  void _selectClass(AcademicClass cls) {
    setState(() {
      _classId = cls.classId.trim().toUpperCase();
      _academicClass = cls;
      _group = ClassGroup.defaultsFor(_classId);
      _recomputeAccess();
      _messagesStream = widget.messagesStream ??
          _service.getClassMessagesStream(_classId);
    });
    _classSubscription?.cancel();
    _classSubscription = _service
        .getAcademicClassStream(_classId)
        .listen(_onAcademicClassUpdate, onError: (_) {});
  }

  String get _roleTitle => HierarchyService.getRoleDisplayTitle(
        scholarNo: ClassGroupAccess.scholarOf(_profile),
        role: ClassGroupAccess.roleOf(_profile),
        fullName: ClassGroupAccess.nameOf(_profile),
      );

  bool get _isStaff =>
      HierarchyService.isTeacherOrFaculty(
        scholarNo: ClassGroupAccess.scholarOf(_profile),
        role: ClassGroupAccess.roleOf(_profile),
        fullName: ClassGroupAccess.nameOf(_profile),
      ) ||
      ClassGroupAccess.isSeniorAdmin(_profile);

  Future<void> _pickAttachment() async {
    if (!_canPost) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: 18 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attach an image',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  AcademicImageUploadField(
                    label: 'Class group attachment',
                    value: _pendingAttachment.isEmpty
                        ? null
                        : _pendingAttachment,
                    onChanged: (value) {
                      setSheetState(() {});
                      setState(() => _pendingAttachment = value ?? '');
                    },
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _send() async {
    if (!_canPost || _isSending) return;
    final text = _messageController.text.trim();
    final attachment = _pendingAttachment.trim();
    if (text.isEmpty && attachment.isEmpty) return;

    setState(() => _isSending = true);
    final ok = await _service.sendClassMessage(
      classId: _classId,
      text: text,
      category: _selectedCategory,
      attachmentUrl: attachment,
    );
    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (ok) {
        _messageController.clear();
        _pendingAttachment = '';
      }
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message not sent. Check your connection and class permissions.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final fanOut = _service.lastNotificationResult;
    if (fanOut != null && fanOut.warning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fanOut.warning!),
          backgroundColor: Colors.orange,
        ),
      );
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuad,
      );
    }
  }

  Future<void> _handleModeration(
    ClassGroupMessage message,
    String action,
  ) async {
    bool ok = false;
    if (action == 'pin') {
      ok = await _service.setMessagePinned(
        classId: _classId,
        messageId: message.id,
        pinned: !message.isPinned,
      );
    } else if (action == 'hide') {
      ok = await _service.setMessageHidden(
        classId: _classId,
        messageId: message.id,
        hidden: !message.isHidden,
      );
    } else if (action == 'delete') {
      ok = await _service.deleteClassMessage(
        classId: _classId,
        messageId: message.id,
      );
    }
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Moderation action failed. Check permissions.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Icon(Icons.school_rounded, color: accent, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _classId.isEmpty ? 'Class Group' : _group.displayName,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
            ),
          ],
        ),
      ),
      body: _classId.isEmpty
          ? _buildNoClass(accent, isDark)
          : !_canView
              ? _buildAccessDenied(accent)
              : Column(
                  children: [
                    _buildMembershipBanner(accent, isDark),
                    _buildCategoryFilters(accent),
                    Expanded(child: _buildMessages(accent, isDark)),
                    if (_canPost)
                      _buildComposer(accent, isDark)
                    else
                      _buildReadOnlyBanner(isDark),
                  ],
                ),
    );
  }

  Widget _buildNoClass(Color accent, bool isDark) {
    if (_isStaff) {
      return _buildClassPicker(accent, isDark);
    }
    return Center(
      key: const Key('class_group_no_class'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 60,
              color: accent.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            const Text(
              'No verified class on this account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask an administrator to verify your class placement before opening the class group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassPicker(Color accent, bool isDark) {
    return StreamBuilder<List<AcademicClass>>(
      stream: _authService.getAcademicClassesStream(activeOnly: true),
      builder: (context, snapshot) {
        final classes = snapshot.data ?? const <AcademicClass>[];
        if (classes.isEmpty) {
          return Center(
            key: const Key('class_group_no_classes'),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'No active classes are available. Create a class and assign a class teacher in the Admin Portal first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text(
              'Choose a class to manage',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            for (final cls in classes)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  key: Key('class_group_picker_${cls.classId}'),
                  leading: CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.16),
                    child: Text(
                      cls.classId,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                  title: Text(
                    cls.displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    cls.classTeacher.isEmpty
                        ? 'No class teacher assigned'
                        : 'Class teacher: ${cls.classTeacher}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 15),
                  onTap: () => _selectClass(cls),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAccessDenied(Color accent) {
    return Center(
      key: const Key('class_group_access_denied'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_rounded,
              size: 60,
              color: accent.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            const Text(
              'This class group is private',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Class groups are visible only to verified members of that class and assigned staff.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white60
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipBanner(Color accent, bool isDark) {
    final verifiedMember =
        ClassGroupAccess.isVerifiedMember(_profile, _classId);
    return Container(
      key: const Key('class_group_membership_banner'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.30 : 0.16),
            accent.withValues(alpha: isDark ? 0.12 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              verifiedMember
                  ? Icons.verified_user_rounded
                  : Icons.badge_rounded,
              color: accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verifiedMember
                      ? 'Auto-joined via verified class · $_classId'
                      : 'Staff access via class assignment · $_classId',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _canPost
                      ? 'Posting as $_roleTitle.'
                      : 'Read-only: your class teacher, subject teachers, and class representatives can post.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(Color accent) {
    final filters = ['all', ...kClassGroupCategories];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = filters[index];
          final selected = _filterCategory == value;
          return ChoiceChip(
            key: Key('class_group_filter_$value'),
            selected: selected,
            onSelected: (_) => setState(() => _filterCategory = value),
            label: Text(
              value == 'all' ? 'All' : classGroupCategoryLabel(value),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : null,
              ),
            ),
            selectedColor: accent,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildMessages(Color accent, bool isDark) {
    return StreamBuilder<List<ClassGroupMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? const <ClassGroupMessage>[];
        final visible = all.where((message) {
          if (message.isHidden && !_canModerate) return false;
          if (_filterCategory != 'all' &&
              normalizeClassGroupCategory(message.category) !=
                  _filterCategory) {
            return false;
          }
          return true;
        }).toList();

        if (visible.isEmpty) {
          return Center(
            key: const Key('class_group_empty_state'),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 54,
                    color: accent.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No messages in this category yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _canPost
                        ? 'Share the first class update with your members.'
                        : 'Class announcements from your teacher and representatives will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: visible.length,
          itemBuilder: (context, index) =>
              _buildMessageCard(visible[index], accent, isDark),
        );
      },
    );
  }

  Widget _buildMessageCard(
    ClassGroupMessage message,
    Color accent,
    bool isDark,
  ) {
    final mine = message.senderId.isNotEmpty &&
        message.senderId == _service.currentUserId;
    final cardColor = mine
        ? accent.withValues(alpha: isDark ? 0.28 : 0.12)
        : (isDark ? const Color(0xFF1A2338) : Colors.white);

    return Opacity(
      opacity: message.isHidden ? 0.55 : 1,
      child: Container(
        key: Key('class_group_message_${message.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: message.isPinned
                ? accent.withValues(alpha: 0.55)
                : accent.withValues(alpha: 0.16),
            width: message.isPinned ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  child: Text(
                    message.senderName.isNotEmpty
                        ? message.senderName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine
                            ? '${message.senderName} (you)'
                            : message.senderName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${message.senderRole} · ${_timeLabel(message.timestamp)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.isPinned)
                  Icon(
                    Icons.push_pin_rounded,
                    key: Key('class_group_pinned_${message.id}'),
                    size: 16,
                    color: accent,
                  ),
                if (message.isHidden)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HIDDEN',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                if (_canModerate)
                  PopupMenuButton<String>(
                    key: Key('class_group_message_menu_${message.id}'),
                    tooltip: 'Moderate message',
                    onSelected: (value) => _handleModeration(message, value),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text(message.isPinned ? 'Unpin' : 'Pin'),
                      ),
                      PopupMenuItem(
                        value: 'hide',
                        child: Text(message.isHidden ? 'Unhide' : 'Hide'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    message.categoryLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: accent,
                    ),
                  ),
                ),
                if (message.isAnnouncement) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.campaign_rounded, size: 14, color: accent),
                ],
              ],
            ),
            if (message.hasText) ...[
              const SizedBox(height: 8),
              Text(
                message.text.trim(),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (message.hasAttachment) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: buildAcademicImage(message.attachmentUrl),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyBanner(bool isDark) {
    return Container(
      key: const Key('class_group_read_only_banner'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 18, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Students are read-only unless the school enables student posting for this class.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(Color accent, bool isDark) {
    return Container(
      key: const Key('class_group_composer'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingAttachment.isNotEmpty)
              Container(
                key: const Key('class_group_attachment_preview'),
                margin: const EdgeInsets.only(bottom: 8),
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.image_rounded, size: 18, color: accent),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Image attached',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('class_group_remove_attachment'),
                      tooltip: 'Remove attachment',
                      onPressed: () => setState(() => _pendingAttachment = ''),
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  key: const Key('class_group_attach_button'),
                  tooltip: 'Attach image',
                  onPressed: _isSending ? null : _pickAttachment,
                  icon: Icon(Icons.attach_file_rounded, color: accent),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('class_group_message_field'),
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Share a class update...',
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('class_group_send_button'),
                  tooltip: 'Send message',
                  onPressed: _isSending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: accent),
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  key: const Key('class_group_category_selector'),
                  value: _selectedCategory,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  items: kClassGroupCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(classGroupCategoryLabel(category)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
