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

import '../../domain/entities/rider_alert.dart';

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
