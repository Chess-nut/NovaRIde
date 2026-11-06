/// How a real alert (`alerts/{id}`) reads on the rider screens.
///
/// Alerts, Analytics and the notification feed all list the same alerts;
/// they used to list three different invented ones. One place for the
/// wording means "dispatched" cannot read as "Help on the way" on one
/// screen and "Dispatched" on another.
library;

import 'package:flutter/material.dart';

import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';
import 'package:novaride/shared/theme.dart';

import '../../domain/entities/rider_alert.dart';
import 'nova_classic.dart';

/// What kind of alert, in words, with an icon.
(String, IconData) alertTypeLabel(String type) => switch (type) {
  'crash' => ('Crash detected', Icons.car_crash),
  'sos' => ('SOS sent', Icons.sos),
  'alcoholWarning' => ('Alcohol warning', Icons.water_drop_outlined),
  'lowBattery' => ('Low battery', Icons.battery_alert),
  _ => ('Alert', Icons.notifications_none),
};

/// Where the alert is in the response workflow, and how urgent that is.
(String, NovaTone) alertStatusLabel(RiderAlert alert) {
  final live = alert.isLive;
  final urgent = live && alert.isCritical;
  return switch (alert.status) {
    RiderAlertStatus.pending => (
      'Countdown running',
      urgent ? NovaTone.critical : NovaTone.warning,
    ),
    RiderAlertStatus.open => (
      'Waiting for responders',
      urgent ? NovaTone.critical : NovaTone.warning,
    ),
    RiderAlertStatus.acknowledged => (
      'Seen by responders',
      urgent ? NovaTone.critical : NovaTone.warning,
    ),
    RiderAlertStatus.dispatched => ('Help on the way', NovaTone.warning),
    RiderAlertStatus.resolved => ('Resolved', NovaTone.safe),
    RiderAlertStatus.cancelled => ('Cancelled', NovaTone.offline),
    RiderAlertStatus.unknown => ('Status unknown', NovaTone.neutral),
  };
}

/// One alert as a list row: what happened, when, and where it stands.
class RiderAlertRow extends StatelessWidget {
  const RiderAlertRow({super.key, required this.alert});

  final RiderAlert alert;

  @override
  Widget build(BuildContext context) {
    final (title, icon) = alertTypeLabel(alert.type);
    final (status, tone) = alertStatusLabel(alert);
    final time = alert.timestamp;

    return NovaListRow(
      icon: icon,
      title: title,
      subtitle: time == null ? null : novaTimeAgo(time),
      trailing: NovaPill(label: status, tone: tone),
    );
  }
}

/// The old palette's colour for a kind of alert.
Color classicAlertColor(String type) => switch (type) {
  'crash' || 'sos' => NovaColors.red,
  'alcoholWarning' || 'lowBattery' => NovaColors.amber,
  _ => NovaColors.cyan,
};

/// One alert as a line inside a card, in the original look: a coloured
/// dot, what happened, where it stands, and when.
class ClassicAlertLine extends StatelessWidget {
  const ClassicAlertLine({super.key, required this.alert});

  final RiderAlert alert;

  @override
  Widget build(BuildContext context) {
    final (title, _) = alertTypeLabel(alert.type);
    final (status, tone) = alertStatusLabel(alert);
    final time = alert.timestamp;
    final color = classicAlertColor(alert.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, color: color, size: 9),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time == null ? 'Time not recorded yet' : classicDateTime(time),
                  style: const TextStyle(
                    color: NovaColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ClassicPill(label: status, color: classicToneColor(tone), dot: false),
        ],
      ),
    );
  }
}

/// One alert as its own card, the way the notification feed drew them.
class ClassicAlertCard extends StatelessWidget {
  const ClassicAlertCard({super.key, required this.alert});

  final RiderAlert alert;

  @override
  Widget build(BuildContext context) {
    final (title, icon) = alertTypeLabel(alert.type);
    final (status, tone) = alertStatusLabel(alert);
    final time = alert.timestamp;
    final color = classicAlertColor(alert.type);

    return ClassicCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClassicIconCircle(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: NovaColors.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (time != null)
                      Text(
                        novaTimeAgo(time),
                        style: const TextStyle(
                          color: NovaColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: classicToneColor(tone),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
