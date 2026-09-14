import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

/// "Notifications" screen — preferences for which alerts and reports the
/// rider receives. Opened from the Profile screen's ACCOUNT card.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Safety alerts — on by default and generally shouldn't be muted, but the
  // rider can still opt out per-channel.
  bool _pushNotifications = true;
  bool _smsAlerts = true;
  bool _impactAlerts = true;
  bool _alcoholWarnings = true;
  bool _gpsSignalLost = true;

  // Reports & marketing — off by default.
  bool _weeklySafetyReport = true;
  bool _tripSummaries = false;
  bool _promotions = false;

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
                    _buildSectionTitle('DELIVERY'),
                    const SizedBox(height: 12),
                    _buildCard([
                      _ToggleRow(
                        icon: Icons.notifications_none,
                        iconColor: NovaColors.amber,
                        title: 'Push Notifications',
                        subtitle: 'Alerts sent directly to this device',
                        value: _pushNotifications,
                        onChanged: (v) => setState(() => _pushNotifications = v),
                      ),
                      const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
                      _ToggleRow(
                        icon: Icons.sms_outlined,
                        iconColor: NovaColors.cyan,
                        title: 'SMS Alerts',
                        subtitle: 'Backup alerts sent via text message',
                        value: _smsAlerts,
                        onChanged: (v) => setState(() => _smsAlerts = v),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('SAFETY ALERTS'),
                    const SizedBox(height: 12),
                    _buildCard([
                      _ToggleRow(
                        icon: Icons.warning_amber_rounded,
                        iconColor: NovaColors.pink,
                        title: 'Impact Alerts',
                        subtitle: 'Notify me when a crash or impact is detected',
                        value: _impactAlerts,
                        onChanged: (v) => setState(() => _impactAlerts = v),
                      ),
                      const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
                      _ToggleRow(
                        icon: Icons.local_bar_outlined,
                        iconColor: NovaColors.amber,
                        title: 'Alcohol Warnings',
                        subtitle: 'Notify me on elevated breath alcohol readings',
                        value: _alcoholWarnings,
                        onChanged: (v) => setState(() => _alcoholWarnings = v),
                      ),
                      const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
                      _ToggleRow(
                        icon: Icons.gps_off,
                        iconColor: NovaColors.purple,
                        title: 'GPS Signal Lost',
                        subtitle: 'Notify me if helmet location tracking drops',
                        value: _gpsSignalLost,
                        onChanged: (v) => setState(() => _gpsSignalLost = v),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionTitle('REPORTS & UPDATES'),
                    const SizedBox(height: 12),
                    _buildCard([
                      _ToggleRow(
                        icon: Icons.insert_chart_outlined_rounded,
                        iconColor: NovaColors.green,
                        title: 'Weekly Safety Report',
                        subtitle: 'A summary of your riding safety score',
                        value: _weeklySafetyReport,
                        onChanged: (v) => setState(() => _weeklySafetyReport = v),
                      ),
                      const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
                      _ToggleRow(
                        icon: Icons.route_outlined,
                        iconColor: NovaColors.cyan,
                        title: 'Trip Summaries',
                        subtitle: 'Get a recap after each completed trip',
                        value: _tripSummaries,
                        onChanged: (v) => setState(() => _tripSummaries = v),
                      ),
                      const Divider(height: 1, color: NovaColors.cardBorder, indent: 56),
                      _ToggleRow(
                        icon: Icons.local_offer_outlined,
                        iconColor: NovaColors.secondaryText,
                        title: 'Promotions & News',
                        subtitle: 'Occasional product updates and offers',
                        value: _promotions,
                        onChanged: (v) => setState(() => _promotions = v),
                      ),
                    ]),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: TextStyle(
                  color: NovaColors.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Choose what you want to be notified about',
                style: TextStyle(color: NovaColors.secondaryText, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: NovaColors.secondaryText,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: NovaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NovaColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: NovaColors.secondaryText, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: NovaColors.cyan,
            activeTrackColor: NovaColors.cyan.withValues(alpha: 0.3),
            inactiveThumbColor: NovaColors.secondaryText,
            inactiveTrackColor: NovaColors.cardBorder,
          ),
        ],
      ),
    );
  }
}