import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/coordinates.dart';
import '../../../../core/widgets/nova_grid_map.dart';
import '../../../../core/widgets/nova_lists.dart';
import '../../../../core/widgets/nova_surfaces.dart';
import '../../../rider/domain/entities/rider_alert.dart';
import '../../../rider/presentation/providers/helmet_telemetry_provider.dart';
import '../../../rider/presentation/widgets/rider_alert_tile.dart';
import '../../domain/entities/guardian_link.dart';
import '../providers/guardian_providers.dart';
import '../widgets/guardian_common.dart';
import 'guardian_connect_view.dart';

/// The guardian's Home.
///
/// Not linked yet: "Connect to a rider" ([GuardianConnectView]).
///
/// Linked: the rider's name, then one status card that says the most
/// important true thing —
///
/// * a crash or SOS still being worked takes over the whole screen: what
///   happened, Call, Open map, Copy link, where, and how far it has got;
/// * otherwise riding / not moving / offline / no data, from the helmet;
///
/// then where they are, the helmet's state, a safety summary from their
/// alerts, and the latest alert.
///
/// Nothing here is invented. Speed shows only while the helmet is live;
/// there is no trip duration or battery, because nothing records either.
class GuardianHomePage extends ConsumerWidget {
  const GuardianHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final linkAsync = ref.watch(myGuardianLinkProvider);
    final link = linkAsync.value;

    Widget body;
    if (linkAsync.isLoading && !linkAsync.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (linkAsync.hasError && link == null) {
      body = Padding(
        padding: const EdgeInsets.all(kRiderGutter),
        child: NovaEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Couldn\'t load your rider',
          message: 'Check your connection and try again.',
          action: TextButton(
            onPressed: () => ref.invalidate(myGuardianLinkProvider),
            child: const Text('Retry'),
          ),
        ),
      );
    } else if (link == null) {
      body = const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NovaScreenHeader(
            title: 'Connect to a rider',
            subtitle: 'Enter the code the rider shows you',
            showBack: false,
          ),
          Expanded(child: GuardianConnectView()),
        ],
      );
    } else {
      body = _Dashboard(link: link);
    }

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(child: body),
      bottomNavigationBar:
          link == null ? null : const GuardianBottomNavBar(selectedIndex: 0),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.link});

  final GuardianLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(followedRiderAccountProvider).value;
    final rosterAsync = ref.watch(followedRosterProvider);
    final alertsAsync = ref.watch(followedAlertsProvider);
    final alerts = alertsAsync.value ?? const <RiderAlert>[];
    final now = ref.watch(helmetClockProvider).value ?? DateTime.now();
    final helmet = GuardianHelmetView.from(ref.watch(helmetTelemetryProvider), now);
    final emergency = activeEmergencyIn(alerts);

    final name = account?.displayName ?? 'Your rider';
    final firstName = account?.firstName ?? 'your rider';
    final relationship =
        link.relationship.isEmpty ? 'Guardian' : link.relationship;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NovaScreenHeader(
            title: name,
            subtitle: '$relationship · you\'re their guardian',
            showBack: false,
            trailing: IconButton(
              tooltip: 'Alerts',
              onPressed: () => context.go(AppRoutes.guardianAlertsPath),
              style: IconButton.styleFrom(
                backgroundColor: context.colors.surfaceRaised,
                minimumSize: const Size.square(AppSizes.minTouchTarget),
              ),
              icon: Icon(Icons.notifications_none,
                  color: context.colors.textPrimary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kRiderGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                if (emergency != null) ...[
                  _EmergencyCard(alert: emergency, firstName: firstName, now: now),
                  const SizedBox(height: AppSpacing.md),
                  _EmergencyActions(
                    phone: account?.phoneNumber,
                    firstName: firstName,
                    helmet: helmet,
                  ),
                ] else
                  _StatusCard(helmet: helmet, now: now),
                if (rosterAsync.hasValue && rosterAsync.value == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  NovaNote(
                    text: 'Operations hasn\'t linked $firstName\'s account to '
                        'a helmet yet, so alerts won\'t show here until '
                        'they do.',
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                NovaSectionLabel(emergency != null
                    ? 'Location'
                    : helmet.live
                        ? 'Where they are'
                        : 'Where they were'),
                const SizedBox(height: AppSpacing.md),
                _LocationCard(
                  helmet: helmet,
                  now: now,
                  firstName: firstName,
                  emergency: emergency != null,
                ),
                if (emergency != null) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  const NovaSectionLabel('What has happened'),
                  const SizedBox(height: AppSpacing.md),
                  _Timeline(alert: emergency, firstName: firstName),
                ] else ...[
                  const SizedBox(height: AppSpacing.xxl),
                  const NovaSectionLabel('Helmet'),
                  const SizedBox(height: AppSpacing.md),
                  _HelmetCard(helmet: helmet),
                  const SizedBox(height: AppSpacing.xxl),
                  const NovaSectionLabel('Safety summary'),
                  const SizedBox(height: AppSpacing.md),
                  if (alertsAsync.hasError)
                    const NovaNote(
                      tone: NovaTone.critical,
                      icon: Icons.error_outline,
                      text: 'Couldn\'t load alerts. They\'ll appear once the '
                          'connection is back.',
                    )
                  else
                    _SafetySummaryView(summary: SafetySummary.of(alerts), now: now),
                  if (alerts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    const NovaSectionLabel('Latest alert'),
                    const SizedBox(height: AppSpacing.md),
                    NovaListGroup(children: [RiderAlertRow(alert: alerts.first)]),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ status

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.helmet, required this.now});

  final GuardianHelmetView helmet;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = helmet.telemetry;
    final speed = helmet.speedKmph;
    final lastSeen = t?.lastSeen;

    final (String title, NovaTone tone, String? pill, String detail) =
        switch (helmet.phase) {
      GuardianHelmetPhase.connecting => (
          'Connecting to the helmet…',
          NovaTone.offline,
          null,
          'This takes a moment.',
        ),
      GuardianHelmetPhase.error => (
          'Can\'t reach helmet data',
          NovaTone.critical,
          null,
          helmet.errorMessage ?? 'Check your connection.',
        ),
      GuardianHelmetPhase.missing => (
          'No helmet data yet',
          NovaTone.offline,
          null,
          'The helmet hasn\'t reported since it was set up.',
        ),
      GuardianHelmetPhase.reporting when helmet.live => (
          speed != null && speed >= 3 ? 'Riding now' : 'Helmet on, not moving',
          NovaTone.safe,
          'Live',
          'Helmet reported ${lastSeen == null ? 'just now' : novaTimeAgo(lastSeen, now)}',
        ),
      GuardianHelmetPhase.reporting => (
          'Helmet offline',
          NovaTone.offline,
          'Offline',
          '${lastSeen == null ? 'No report yet' : 'Last report ${novaTimeAgo(lastSeen, now)}'}. '
              'It\'s usually off between rides. Alerts it raises will still '
              'reach you when it\'s back online.',
        ),
    };

    return NovaCard(
      semanticLabel: '$title. $detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tone.colorIn(colors),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: context.text.h2)),
              if (pill != null) NovaPill(label: pill, tone: tone),
            ],
          ),
          if (speed != null && helmet.live) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(speed.toStringAsFixed(0), style: context.text.display),
                const SizedBox(width: AppSpacing.xs),
                Text('km/h', style: context.text.bodyMuted),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(detail, style: context.text.bodyMuted),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- emergency

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({
    required this.alert,
    required this.firstName,
    required this.now,
  });

  final RiderAlert alert;
  final String firstName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, icon) = alertTypeLabel(alert.type);
    final (status, _) = alertStatusLabel(alert);
    final when = alert.timestamp;
    final ago = when == null ? '' : ' ${novaTimeAgo(when, now)}';
    final sentence = alert.type == 'sos'
        ? '$firstName sent an SOS$ago.'
        : '$firstName\'s helmet detected a hard impact$ago.';

    return NovaCard(
      tone: NovaTone.critical,
      semanticLabel: '$label. $status. $sentence',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.critical, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(label, style: context.text.h1)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          NovaPill(label: status, tone: NovaTone.critical),
          const SizedBox(height: AppSpacing.md),
          Text(sentence, style: context.text.body),
        ],
      ),
    );
  }
}

class _EmergencyActions extends StatelessWidget {
  const _EmergencyActions({
    required this.phone,
    required this.firstName,
    required this.helmet,
  });

  final String? phone;
  final String firstName;
  final GuardianHelmetView helmet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final link = mapLinkFor(helmet.telemetry);
    final number = phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (number != null)
          SizedBox(
            height: AppSizes.buttonHeight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.sos,
                foregroundColor: colors.onAction,
                shape: const StadiumBorder(),
                textStyle: AppTypography.title,
              ),
              onPressed: () => callNumber(context, number),
              icon: const Icon(Icons.call, size: 20),
              label: Text('Call $firstName'),
            ),
          )
        else
          NovaNote(
            text: '$firstName hasn\'t added a phone number to NovaRide, so '
                'there\'s no number to call from here.',
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: NovaSecondaryButton(
                label: 'Open map',
                icon: Icons.map_outlined,
                onPressed: () => context.go(AppRoutes.guardianMapPath),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: NovaSecondaryButton(
                label: 'Copy link',
                icon: Icons.copy,
                onPressed: link == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(
                              content: Text('Map link copied. Paste it to share.')));
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// How far the incident has got, from the alert's status. Only steps the
/// data can show.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.alert, required this.firstName});

  final RiderAlert alert;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final s = alert.status;
    final isCrash = alert.type == 'crash';
    final steps = <(String, String, bool)>[
      (
        isCrash ? 'Crash detected' : 'SOS sent',
        isCrash ? 'By the helmet\'s impact sensor' : 'By $firstName',
        true,
      ),
      if (isCrash)
        (
          s == RiderAlertStatus.pending ? 'Countdown running' : 'Countdown ended',
          s == RiderAlertStatus.pending
              ? '$firstName can still cancel a false alarm'
              : '$firstName didn\'t cancel',
          s != RiderAlertStatus.pending,
        ),
      (
        'Seen by operations',
        'The NovaRide console has the alert',
        s == RiderAlertStatus.acknowledged || s == RiderAlertStatus.dispatched,
      ),
      (
        'Help on the way',
        'Operations sent responders',
        s == RiderAlertStatus.dispatched,
      ),
    ];

    return NovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            _Step(title: steps[i].$1, detail: steps[i].$2, done: steps[i].$3),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.detail, required this.done});

  final String title;
  final String detail;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? colors.critical : null,
                border: done ? null : Border.all(color: colors.critical, width: 2),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.text.title.copyWith(
                        color: done ? colors.textPrimary : colors.textSecondary)),
                Text(done ? detail : 'Not yet', style: context.text.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- location

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.helmet,
    required this.now,
    required this.firstName,
    required this.emergency,
  });

  final GuardianHelmetView helmet;
  final DateTime now;
  final String firstName;
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = helmet.telemetry;
    final taken = fixTakenAt(t?.lastSeen, t?.gpsAgeMs) ?? t?.lastSeen;
    final has = helmet.hasPosition;

    final String title;
    final String detail;
    if (!has) {
      title = 'No location yet';
      detail = 'The helmet needs a GPS fix. Its antenna has to see the sky.';
    } else {
      title = helmet.live ? 'Location' : 'Last known location';
      final when = taken == null ? 'Fix time unknown' : 'Fix taken ${novaTimeAgo(taken, now)}';
      final sats = t?.satellites;
      detail = emergency
          ? '${formatLatitude(t!.lat!)}, ${formatLongitude(t.lng!)} · $when'
          : sats == null || !helmet.live
              ? when
              : '$when · $sats satellites';
    }

    return NovaCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NovaGridMap(
            height: 140,
            showMarker: has,
            markerColor: emergency
                ? colors.critical
                : helmet.live
                    ? colors.riding
                    : colors.offline,
            semanticLabel: has
                ? '$firstName\'s position on a map'
                : 'Map with no position yet',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.title),
                    Text(detail, style: context.text.caption),
                  ],
                ),
              ),
              if (has && !emergency) ...[
                const SizedBox(width: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => context.go(AppRoutes.guardianMapPath),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.borderStrong),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, AppSizes.minTouchTarget),
                  ),
                  child: const Text('Open map'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ helmet

class _HelmetCard extends StatelessWidget {
  const _HelmetCard({required this.helmet});

  final GuardianHelmetView helmet;

  @override
  Widget build(BuildContext context) {
    final t = helmet.telemetry;
    final state = switch (helmet.phase) {
      GuardianHelmetPhase.reporting when helmet.live =>
        helmet.connection == null ? 'Online' : 'Online · ${helmet.connection}',
      GuardianHelmetPhase.reporting => 'Offline',
      GuardianHelmetPhase.missing => 'Never reported',
      GuardianHelmetPhase.error => 'Can\'t reach',
      GuardianHelmetPhase.connecting => '—',
    };
    // Sensor readings only mean something while the helmet is live.
    final live = helmet.live;
    final crash = !live
        ? '—'
        : switch (t?.accelerometerReady) {
            true => 'Ready',
            false => 'Not ready',
            null => '—',
          };
    final alcohol = !live
        ? '—'
        : switch (t?.alcoholAlert) {
            true => 'Above threshold',
            false => 'Below threshold',
            null => '—',
          };
    final speed = helmet.speedKmph;

    return NovaCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Column(
        children: [
          NovaValueRow(label: 'Helmet', value: state),
          NovaValueRow(
            label: 'Speed',
            value: speed == null ? '—' : '${speed.toStringAsFixed(0)} km/h',
          ),
          NovaValueRow(label: 'Crash sensor', value: crash),
          NovaValueRow(label: 'Alcohol', value: alcohol),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ safety

class _SafetySummaryView extends StatelessWidget {
  const _SafetySummaryView({required this.summary, required this.now});

  final SafetySummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Count(value: summary.crashes, label: 'Crashes')),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _Count(value: summary.sos, label: 'SOS')),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _Count(value: summary.alcohol, label: 'Alcohol')),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          summary.total >= 20
              ? '${summary.sinceLastAlert(now)} · from the latest 20 alerts'
              : summary.sinceLastAlert(now),
          style: context.text.caption,
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return NovaCard(
      semanticLabel: '$value $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: context.text.h1),
          const SizedBox(height: 2),
          Text(label, style: context.text.labelMuted),
        ],
      ),
    );
  }
}
