import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/coordinates.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../../../core/widgets/nova_grid_map.dart';
import '../../../../core/widgets/nova_lists.dart';
import '../../../../core/widgets/nova_surfaces.dart';
import '../../../rider/presentation/providers/helmet_telemetry_provider.dart';
import '../providers/guardian_providers.dart';
import '../widgets/guardian_common.dart';

/// "Map" — where the rider's helmet is, or was.
///
/// The drawing marks that there is a fix; the sheet gives the numbers and
/// "Open in Google Maps" shows the real place. Speed only while live.
class GuardianMapPage extends ConsumerWidget {
  const GuardianMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final link = ref.watch(myGuardianLinkProvider).value;
    final account = ref.watch(followedRiderAccountProvider).value;
    final now = ref.watch(helmetClockProvider).value ?? DateTime.now();
    final helmet = GuardianHelmetView.from(ref.watch(helmetTelemetryProvider), now);
    final alerts = ref.watch(followedAlertsProvider).value ?? const [];
    final emergency = activeEmergencyIn(alerts) != null;

    if (link == null) {
      return Scaffold(
        backgroundColor: colors.surface,
        body: const SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NovaScreenHeader(title: 'Map', showBack: false),
              Expanded(child: GuardianNotLinked()),
            ],
          ),
        ),
        bottomNavigationBar: const GuardianBottomNavBar(selectedIndex: 1),
      );
    }

    final t = helmet.telemetry;
    final has = helmet.hasPosition;
    final taken = t?.positionAt;
    final name = account?.firstName ?? 'Your rider';
    final link0 = mapLinkFor(t);
    final speed = helmet.speedKmph;

    final topLine = !has
        ? '$name · no GPS fix yet'
        : taken == null
            ? '$name · last known position'
            : '$name · fix taken ${novaTimeAgo(taken, now)}';

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: NovaGridMap(
              borderRadius: 0,
              showMarker: has,
              markerColor: emergency
                  ? colors.critical
                  : helmet.live
                      ? colors.riding
                      : colors.offline,
              semanticLabel: has
                  ? 'Map with $name\'s ${helmet.live ? 'current' : 'last known'} position'
                  : 'Map with no position yet',
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: NovaCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: colors.textSecondary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(topLine, style: context.text.body)),
                    if (t != null)
                      NovaPill(
                        label: helmet.live ? 'Live' : 'Offline',
                        tone: helmet.live ? NovaTone.safe : NovaTone.offline,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg + 8)),
              ),
              padding: const EdgeInsets.fromLTRB(
                  kRiderGutter, AppSpacing.md, kRiderGutter, AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (has) ...[
                    if (helmet.live)
                      NovaValueRow(
                        label: 'Speed',
                        value: speed == null
                            ? '—'
                            : '${speed.toStringAsFixed(0)} km/h',
                      ),
                    if (helmet.live && t?.satellites != null)
                      NovaValueRow(label: 'Satellites', value: '${t!.satellites}'),
                    NovaValueRow(label: 'Latitude', value: formatLatitude(t!.lat!)),
                    NovaValueRow(label: 'Longitude', value: formatLongitude(t.lng!)),
                    const SizedBox(height: AppSpacing.lg),
                    NovaPrimaryButton(
                      label: 'Open in Google Maps',
                      icon: Icons.map_outlined,
                      onPressed: link0 == null
                          ? null
                          : () => openExternal(context, Uri.parse(link0),
                              failure: 'Couldn\'t open a map app.'),
                    ),
                  ] else
                    Text(
                      'No position yet. The helmet needs a GPS fix, and its '
                      'antenna has to see the sky.',
                      style: context.text.bodyMuted,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const GuardianBottomNavBar(selectedIndex: 1),
    );
  }
}
