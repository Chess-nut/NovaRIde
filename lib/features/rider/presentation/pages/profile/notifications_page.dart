import 'package:flutter/material.dart';

import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_spacing.dart';
import 'package:novaride/core/widgets/nova_lists.dart';
import 'package:novaride/core/widgets/nova_surfaces.dart';

/// "Notifications" — which alerts the rider is told about.
///
/// **Nothing sends push notifications yet** (there is no messaging
/// package and no server-side sender), so these switches have nothing to
/// switch. They used to flip freely and change nothing; they now show the
/// intended defaults, disabled, under a note that says why. The "Reports
/// & updates" group is gone: there is no weekly report and no
/// promotions to opt out of.
///
/// When push lands, give each row an `onChanged` and a saved preference.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const NovaScreenHeader(
              title: 'Notifications',
              subtitle: 'What NovaRide tells you about',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  kRiderGutter,
                  AppSpacing.lg,
                  kRiderGutter,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    NovaNote(
                      text:
                          'Push notifications aren\'t set up in this version '
                          'of NovaRide. Alerts still reach the operations '
                          'console, and the helmet texts its emergency number.',
                    ),
                    SizedBox(height: AppSpacing.xxl),
                    NovaSectionLabel('Delivery'),
                    SizedBox(height: AppSpacing.md),
                    NovaListGroup(
                      children: [
                        NovaSwitchRow(
                          icon: Icons.notifications_none,
                          title: 'Push notifications',
                          subtitle: 'On this phone',
                          value: true,
                          onChanged: null,
                        ),
                        NovaSwitchRow(
                          icon: Icons.sms_outlined,
                          title: 'Text messages',
                          subtitle: 'A backup when there is no data',
                          value: true,
                          onChanged: null,
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xxl),
                    NovaSectionLabel('Safety alerts'),
                    SizedBox(height: AppSpacing.md),
                    NovaListGroup(
                      children: [
                        NovaSwitchRow(
                          icon: Icons.car_crash,
                          title: 'Crash and SOS',
                          subtitle: 'Always on: these cannot be muted',
                          value: true,
                          onChanged: null,
                        ),
                        NovaSwitchRow(
                          icon: Icons.water_drop_outlined,
                          title: 'Alcohol warnings',
                          subtitle: 'When a reading is above the threshold',
                          value: true,
                          onChanged: null,
                        ),
                        NovaSwitchRow(
                          icon: Icons.gps_off,
                          title: 'Helmet offline',
                          subtitle: 'When it stops reporting',
                          value: true,
                          onChanged: null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
