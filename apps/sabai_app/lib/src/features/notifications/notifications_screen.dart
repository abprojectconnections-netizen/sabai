import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../state/notifications_controller.dart';

/// Bell icon with the unread count; opens [NotificationsScreen]. Loads the list once per sign-in.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsController>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationsController>().unreadCount;
    return IconButton(
      key: const Key('notificationBell'),
      tooltip: 'การแจ้งเตือน',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NotificationsController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        actions: [
          TextButton(
            key: const Key('markAllReadButton'),
            onPressed: c.unreadCount == 0 ? null : c.markAllRead,
            child: const Text('อ่านทั้งหมด'),
          ),
        ],
      ),
      body: c.loading && c.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : c.items.isEmpty
              ? Center(child: Text(c.error ?? 'ยังไม่มีการแจ้งเตือน'))
              : RefreshIndicator(
                  onRefresh: c.load,
                  child: ListView.separated(
                    itemCount: c.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = c.items[i];
                      return ListTile(
                        key: Key('notification-${n.id}'),
                        leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active,
                            color: n.read ? null : Theme.of(context).colorScheme.primary),
                        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text([if (n.body.isNotEmpty) n.body, formatDate(n.date)].join('\n')),
                        isThreeLine: n.body.isNotEmpty,
                        onTap: () => c.markRead(n),
                      );
                    },
                  ),
                ),
    );
  }
}
