import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';
import 'profile/notifications_page.dart';

/// "Notifications" feed — a chronologically-sorted log of every system
/// message the user has received (SOS confirmations, crash detection,
/// alcohol warnings, battery alerts, system broadcasts), per the
/// Capstone scope's Notifications module.
///
/// This is distinct from `profile/notifications_page.dart`, which is the
/// *preferences* screen (toggles for what you want to be notified about).
/// This screen is the actual inbox of what you've already been sent —
/// opened from the bell icon on the Home screen.
class NotificationFeedPage extends StatefulWidget {
  const NotificationFeedPage({super.key});

  @override
  State<NotificationFeedPage> createState() => _NotificationFeedPageState();
}

enum _NotifType { sosCritical, sosResolved, crash, alcohol, battery, system }

class _NotificationItem {
  final _NotifType type;
  final String title;
  final String message;
  final String timestamp;
  bool isRead;

  _NotificationItem({
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}

class _NotificationFeedPageState extends State<NotificationFeedPage> {
  // Mock log — hardcoded for now. Per the Capstone scope this is stored
  // server-side and retrievable even when the app is closed; Phase 2
  // swaps this for a Firestore query ordered by timestamp.
  final Map<String, List<_NotificationItem>> _groups = {
    'TODAY': [
      _NotificationItem(
        type: _NotifType.system,
        title: 'Weekly Safety Report Ready',
        message: 'Your safety score is 92, up 5 points from last week.',
        timestamp: '8:15 AM',
      ),
      _NotificationItem(
        type: _NotifType.battery,
        title: 'Helmet Battery Low',
        message: 'Helmet battery at 15%. Charge soon to keep detection active.',
        timestamp: '7:02 AM',
      ),
    ],
    'YESTERDAY': [
      _NotificationItem(
        type: _NotifType.sosResolved,
        title: 'SOS Alert Resolved',
        message: 'Your emergency alert from 6:12 PM has been marked resolved.',
        timestamp: '6:45 PM',
        isRead: true,
      ),
      _NotificationItem(
        type: _NotifType.sosCritical,
        title: 'Emergency SOS Triggered',
        message: 'Crash detected on EDSA, Quezon City. Contacts and TNVS notified.',
        timestamp: '6:12 PM',
        isRead: true,
      ),
    ],
    'EARLIER THIS WEEK': [
      _NotificationItem(
        type: _NotifType.alcohol,
        title: 'Alcohol Warning',
        message: 'Breath alcohol reading exceeded safe threshold near Makati Avenue.',
        timestamp: 'May 20, 9:20 AM',
        isRead: true,
      ),
      _NotificationItem(
        type: _NotifType.system,
        title: 'GPS Signal Lost',
        message: 'Helmet lost GPS fix for 45 seconds near C5 Road, Taguig.',
        timestamp: 'May 15, 6:30 PM',
        isRead: true,
      ),
    ],
    'EARLIER': [
      _NotificationItem(
        type: _NotifType.system,
        title: 'Firmware Updated',
        message: 'Helmet firmware updated to v4.2 with improved crash detection.',
        timestamp: 'May 10',
        isRead: true,
      ),
      _NotificationItem(
        type: _NotifType.system,
        title: 'Welcome to NovaRide',
        message: 'Your helmet NV-08567 is now paired and active.',
        timestamp: 'May 1',
        isRead: true,
      ),
    ],
  };

  int get _unreadCount =>
      _groups.values.expand((items) => items).where((n) => !n.isRead).length;

  void _markAllRead() {
    setState(() {
      for (final items in _groups.values) {
        for (final item in items) {
          item.isRead = true;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in _groups.entries) ...[
                      _buildGroupLabel(entry.key),
                      const SizedBox(height: 10),
                      ...entry.value.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NotificationCard(
                            item: item,
                            onTap: () => setState(() => item.isRead = true),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back, color: NovaColors.primaryText, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _unreadCount > 0 ? '$_unreadCount unread' : 'All caught up',
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: _markAllRead,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    color: NovaColors.cyan,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.tune, color: NovaColors.secondaryText, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final _NotificationItem item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  ({IconData icon, Color color}) get _style => switch (item.type) {
        _NotifType.sosCritical => (icon: Icons.sos_rounded, color: NovaColors.red),
        _NotifType.sosResolved => (icon: Icons.check_circle_outline, color: NovaColors.green),
        _NotifType.crash => (icon: Icons.warning_amber_rounded, color: NovaColors.red),
        _NotifType.alcohol => (icon: Icons.local_bar_outlined, color: NovaColors.amber),
        _NotifType.battery => (icon: Icons.battery_alert_outlined, color: NovaColors.amber),
        _NotifType.system => (icon: Icons.info_outline, color: NovaColors.cyan),
      };

  @override
  Widget build(BuildContext context) {
    final style = _style;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? NovaColors.card : NovaColors.cyan.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? NovaColors.cardBorder : NovaColors.cyan.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: style.color, size: 18),
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
                          item.title,
                          style: TextStyle(
                            color: NovaColors.primaryText,
                            fontSize: 14,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        item.timestamp,
                        style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NovaColors.secondaryText,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: NovaColors.cyan, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}