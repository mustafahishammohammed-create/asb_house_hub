import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'academics_screen.dart';
import 'class_group_screen.dart';
import 'house_group_screen.dart';

/// In-app notification center (M6).
///
/// Renders the signed-in user's notification stream, supports per-item and
/// bulk read marking, tap navigation/deep-linking, dismiss/clear controls,
/// and surfaces priority/category without requiring FCM.
class NotificationCenterScreen extends StatefulWidget {
  /// Test hook so widget tests can render without Firebase.
  final Stream<List<AppNotification>>? notificationsStream;

  /// Test hooks for actions; default to [NotificationService].
  final Future<bool> Function(AppNotification notification)? onMarkRead;
  final Future<bool> Function(List<AppNotification> notifications)? onMarkAllRead;
  final Future<void> Function(AppNotification notification)? onNotificationTap;
  final Future<bool> Function(AppNotification notification)? onDeleteNotification;
  final Future<bool> Function(List<AppNotification> notifications)? onClearAll;

  const NotificationCenterScreen({
    super.key,
    this.notificationsStream,
    this.onMarkRead,
    this.onMarkAllRead,
    this.onNotificationTap,
    this.onDeleteNotification,
    this.onClearAll,
  });

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _service = NotificationService();
  late final Stream<List<AppNotification>> _stream =
      widget.notificationsStream ?? _service.getNotificationsStream();
  final Set<String> _processing = {};

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead || _processing.contains(notification.id)) return;
    setState(() => _processing.add(notification.id));
    final ok = widget.onMarkRead != null
        ? await widget.onMarkRead!(notification)
        : await _service.markRead(notification.id);
    if (!mounted) return;
    setState(() => _processing.remove(notification.id));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark the notification as read. Try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _handleTap(AppNotification notification) async {
    if (notification.isUnread) {
      await _markRead(notification);
    }
    if (!mounted) return;

    if (widget.onNotificationTap != null) {
      await widget.onNotificationTap!(notification);
      return;
    }

    final cat = notification.category;
    final type = notification.type;
    final room = notification.roomId.trim();

    if (cat == 'timetable' || type.startsWith('timetable')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AcademicsScreen(
            initialTab: 'timetable',
            classLevel: room.isNotEmpty ? room : null,
          ),
        ),
      );
    } else if (cat == 'house' || type.startsWith('house')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HouseGroupScreen(
            initialHouseId: room.isNotEmpty ? room : null,
          ),
        ),
      );
    } else if (cat == 'class' || type.startsWith('class')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClassGroupScreen(
            initialClassId: room.isNotEmpty ? room : null,
          ),
        ),
      );
    }
  }

  Future<bool> _deleteNotification(AppNotification notification) async {
    final ok = widget.onDeleteNotification != null
        ? await widget.onDeleteNotification!(notification)
        : await _service.deleteNotification(notification.id);
    if (!mounted) return ok;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the notification.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return ok;
  }

  Future<void> _clearAll(List<AppNotification> notifications) async {
    final ok = widget.onClearAll != null
        ? await widget.onClearAll!(notifications)
        : await _service.clearAll(notifications);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not clear all notifications.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _markAllRead(List<AppNotification> notifications) async {
    final unread = notifications.where((n) => n.isUnread).toList();
    if (unread.isEmpty) return;
    final ok = widget.onMarkAllRead != null
        ? await widget.onMarkAllRead!(notifications)
        : await _service.markAllRead(notifications);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark all notifications as read.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? const <AppNotification>[];
          final unread = AppNotification.unreadCount(notifications);
          if (notifications.isEmpty) {
            return _buildEmpty(isDark);
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    if (unread > 0)
                      TextButton.icon(
                        key: const Key('notification_mark_all'),
                        onPressed: () => _markAllRead(notifications),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: Text('Mark all read ($unread)'),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      key: const Key('notification_clear_all'),
                      onPressed: () => _clearAll(notifications),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear all'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    return Dismissible(
                      key: Key('notification_dismiss_${item.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      confirmDismiss: (_) => _deleteNotification(item),
                      child: _buildTile(item, isDark),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('notification_center_empty'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 60,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Timetable changes, house announcements, and class announcements will appear here.',
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

  Widget _buildTile(AppNotification notification, bool isDark) {
    final accent = _categoryColor(notification.category);
    final unread = notification.isUnread;
    return Material(
      color: unread
          ? accent.withValues(alpha: isDark ? 0.16 : 0.07)
          : (isDark ? const Color(0xFF1A2338) : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('notification_tile_${notification.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleTap(notification),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.35)
                  : accent.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _categoryIcon(notification.category),
                  color: accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight:
                                  unread ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            key: Key('notification_unread_${notification.id}'),
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8, top: 2),
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 4),
                        InkWell(
                          key: Key('notification_delete_${notification.id}'),
                          onTap: () => _deleteNotification(notification),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (notification.isHighPriority) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          notification.priority.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_timeLabel(notification.timestamp)} · ${_categoryLabel(notification.category)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _categoryIcon(String category) {
    switch (normalizeNotificationCategory(category)) {
      case 'timetable':
        return Icons.calendar_month_rounded;
      case 'house':
        return Icons.home_rounded;
      case 'class':
        return Icons.school_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'points':
        return Icons.emoji_events_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static Color _categoryColor(String category) {
    switch (normalizeNotificationCategory(category)) {
      case 'timetable':
        return Colors.indigo;
      case 'house':
        return Colors.deepOrange;
      case 'class':
        return Colors.teal;
      case 'chat':
        return Colors.blue;
      case 'points':
        return Colors.amber.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  static String _categoryLabel(String category) {
    switch (normalizeNotificationCategory(category)) {
      case 'timetable':
        return 'Timetable';
      case 'house':
        return 'House';
      case 'class':
        return 'Class';
      case 'chat':
        return 'Messages';
      case 'points':
        return 'Points';
      default:
        return 'Campus';
    }
  }

  static String _timeLabel(DateTime? value) {
    if (value == null) return 'Just now';
    final local = value.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month} $hh:$mm';
  }
}
