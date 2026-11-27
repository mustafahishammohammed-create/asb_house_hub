import 'package:flutter/material.dart';

import '../models/house_group.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../services/house_group_service.dart';
import '../theme/app_theme.dart';
import '../widgets/academic_image.dart';

/// Per-house group channel.
///
/// Opening this screen *is* joining: membership is resolved from the verified
/// house on the profile, so there is no join button and no self-asserted
/// membership document. Regular students are read-only; house leaders, council
/// officers, and staff can post. The same restrictions are enforced in
/// `firestore.rules`, not just here.
class HouseGroupScreen extends StatefulWidget {
  /// Test hook / administrative deep link. Defaults to the signed-in profile's
  /// verified house.
  final String? initialHouseId;

  /// Test hook so widget tests can render messages without Firebase.
  final Stream<List<HouseGroupMessage>>? messagesStream;

  const HouseGroupScreen({
    super.key,
    this.initialHouseId,
    this.messagesStream,
  });

  @override
  State<HouseGroupScreen> createState() => _HouseGroupScreenState();
}

class _HouseGroupScreenState extends State<HouseGroupScreen> {
  final _service = HouseGroupService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _profile;
  late String _houseId;
  late HouseGroup _group;
  late bool _canView;
  late bool _canPost;
  late bool _canModerate;
  late Stream<List<HouseGroupMessage>> _messagesStream;

  String _selectedCategory = 'general';
  String _filterCategory = 'all';
  String _pendingAttachment = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _profile = AuthService.getCachedProfile();
    _houseId = (widget.initialHouseId ??
            HouseGroupAccess.resolveHouse(_profile))
        .trim()
        .toLowerCase();
    _group = HouseGroup.defaultsFor(_houseId);
    _canView = _houseId.isNotEmpty &&
        HouseGroupAccess.canView(_profile, _houseId);
    _canPost =
        _houseId.isNotEmpty && HouseGroupAccess.canSend(_profile, _houseId);
    _canModerate = _houseId.isNotEmpty &&
        HouseGroupAccess.canModerate(_profile, _houseId);
    _messagesStream = widget.messagesStream ??
        _service.getHouseMessagesStream(_houseId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _roleTitle => HierarchyService.getRoleDisplayTitle(
        scholarNo: HouseGroupAccess.scholarOf(_profile),
        role: HouseGroupAccess.roleOf(_profile),
        fullName: HouseGroupAccess.nameOf(_profile),
      );

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
                    label: 'House group attachment',
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
    final ok = await _service.sendHouseMessage(
      houseId: _houseId,
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
            'Message not sent. Check your connection and house permissions.',
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
    HouseGroupMessage message,
    String action,
  ) async {
    bool ok = false;
    switch (action) {
      case 'pin':
        ok = await _service.setMessagePinned(
          houseId: _houseId,
          messageId: message.id,
          pinned: !message.isPinned,
        );
      case 'hide':
        ok = await _service.setMessageHidden(
          houseId: _houseId,
          messageId: message.id,
          hidden: !message.isHidden,
        );
      case 'delete':
        ok = await _service.deleteHouseMessage(
          houseId: _houseId,
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
    final houseColor = _houseId.isEmpty
        ? HouseColors.ruby
        : HouseColors.getHouseColor(_houseId);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Icon(Icons.groups_rounded, color: houseColor, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _group.displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
              ),
            ),
          ],
        ),
      ),
      body: !_canView
          ? _buildAccessDenied(houseColor)
          : Column(
              children: [
                _buildMembershipBanner(houseColor, isDark),
                _buildCategoryFilters(houseColor),
                Expanded(child: _buildMessages(houseColor, isDark)),
                if (_canPost)
                  _buildComposer(houseColor, isDark)
                else
                  _buildReadOnlyBanner(isDark),
              ],
            ),
    );
  }

  Widget _buildAccessDenied(Color houseColor) {
    final noHouse = _houseId.isEmpty;
    return Center(
      key: Key(noHouse
          ? 'house_group_no_house'
          : 'house_group_access_denied'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              noHouse ? Icons.home_work_rounded : Icons.lock_rounded,
              size: 60,
              color: houseColor.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 16),
            Text(
              noHouse
                  ? 'No verified house on this account'
                  : 'This house group is private',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              noHouse
                  ? 'Ask an administrator to assign your verified house before opening the house group.'
                  : 'House groups are visible only to members of that house.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDarkGrey(context) ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isDarkGrey(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Widget _buildMembershipBanner(Color houseColor, bool isDark) {
    return Container(
      key: const Key('house_group_membership_banner'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            houseColor.withValues(alpha: isDark ? 0.30 : 0.16),
            houseColor.withValues(alpha: isDark ? 0.12 : 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: houseColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: houseColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: houseColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-joined via verified house · ${_houseId.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _canPost
                      ? 'Posting as $_roleTitle.'
                      : 'Read-only: house captains, council leaders, and staff can post.',
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

  Widget _buildCategoryFilters(Color houseColor) {
    final filters = ['all', ...kHouseGroupCategories];
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
            key: Key('house_group_filter_$value'),
            selected: selected,
            onSelected: (_) => setState(() => _filterCategory = value),
            label: Text(
              value == 'all' ? 'All' : houseGroupCategoryLabel(value),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : null,
              ),
            ),
            selectedColor: houseColor,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildMessages(Color houseColor, bool isDark) {
    return StreamBuilder<List<HouseGroupMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all = snapshot.data ?? const <HouseGroupMessage>[];
        final visible = all.where((message) {
          if (message.isHidden && !_canModerate) return false;
          if (_filterCategory != 'all' &&
              normalizeHouseGroupCategory(message.category) !=
                  _filterCategory) {
            return false;
          }
          return true;
        }).toList();

        if (visible.isEmpty) {
          return Center(
            key: const Key('house_group_empty_state'),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 54,
                    color: houseColor.withValues(alpha: 0.45),
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
                        ? 'Share the first house update with your members.'
                        : 'House announcements from your leaders and staff will appear here.',
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
              _buildMessageCard(visible[index], houseColor, isDark),
        );
      },
    );
  }

  Widget _buildMessageCard(
    HouseGroupMessage message,
    Color houseColor,
    bool isDark,
  ) {
    final mine = message.senderId.isNotEmpty &&
        message.senderId == _service.currentUserId;
    final cardColor = mine
        ? houseColor.withValues(alpha: isDark ? 0.28 : 0.12)
        : (isDark ? const Color(0xFF1A2338) : Colors.white);

    return Opacity(
      opacity: message.isHidden ? 0.55 : 1,
      child: Container(
        key: Key('house_group_message_${message.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: message.isPinned
                ? houseColor.withValues(alpha: 0.55)
                : houseColor.withValues(alpha: 0.16),
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
                  backgroundColor: houseColor.withValues(alpha: 0.18),
                  child: Text(
                    message.senderName.isNotEmpty
                        ? message.senderName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: houseColor,
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
                        mine ? '${message.senderName} (you)' : message.senderName,
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
                    key: Key('house_group_pinned_${message.id}'),
                    size: 16,
                    color: houseColor,
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
                    key: Key('house_group_message_menu_${message.id}'),
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
                    color: houseColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    message.categoryLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                      color: houseColor,
                    ),
                  ),
                ),
                if (message.isAnnouncement) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.campaign_rounded, size: 14, color: houseColor),
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
              GestureDetector(
                onTap: () => showAcademicImagePreview(
                  context,
                  message.attachmentUrl,
                  '${message.senderName} Attachment',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 170,
                    width: double.infinity,
                    child: buildAcademicImage(message.attachmentUrl),
                  ),
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
      key: const Key('house_group_read_only_banner'),
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
                'Students are read-only in the house group. Ask a house captain, council leader, or staff member to post.',
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

  Widget _buildComposer(Color houseColor, bool isDark) {
    return Container(
      key: const Key('house_group_composer'),
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
                key: const Key('house_group_attachment_preview'),
                margin: const EdgeInsets.only(bottom: 8),
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: houseColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Icon(Icons.image_rounded, size: 18, color: houseColor),
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
                      key: const Key('house_group_remove_attachment'),
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
                  key: const Key('house_group_attach_button'),
                  tooltip: 'Attach image',
                  onPressed: _isSending ? null : _pickAttachment,
                  icon: Icon(Icons.attach_file_rounded, color: houseColor),
                ),
                Expanded(
                  child: TextField(
                    key: const Key('house_group_message_field'),
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Share a house update...',
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
                  key: const Key('house_group_send_button'),
                  tooltip: 'Send message',
                  onPressed: _isSending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: houseColor),
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
                  key: const Key('house_group_category_selector'),
                  value: _selectedCategory,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  items: kHouseGroupCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(houseGroupCategoryLabel(category)),
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
