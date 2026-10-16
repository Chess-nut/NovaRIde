import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novaride/shared/models/models.dart' show kCrashCountdown;

import '../../../../app/di.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/nova_buttons.dart';
import '../../domain/entities/rider_alert.dart';
import '../providers/rider_alerts_provider.dart';

/// The false-positive countdown (FIRMWARE_CONTRACT.md §3.8).
///
/// Wraps every screen of the app. When the helmet raises a crash for this
/// rider, it covers the screen with a countdown and one action: *I'm OK*.
/// Cancelling inside the countdown calls the alert off; doing nothing lets
/// it escalate to the dispatcher when the countdown runs out.
///
/// **The countdown can only suppress.** Escalation does not depend on
/// anything here: the rules stop accepting a cancel 15 s after the alert's
/// server timestamp, and the console shows it as open from then on. If this
/// widget never runs — app closed, phone broken — the alert goes through.
///
/// **It is shown only while the app is open and in the foreground.** A
/// backgrounded app's listener may be stopped by the OS, and then nothing
/// is shown and the alert escalates. Keeping it alive in the background
/// needs an Android foreground service, which is future work.
///
/// The countdown is timed against the phone's clock, which on a phone with
/// network time is within a second of the server's.
class CrashCountdownGate extends ConsumerStatefulWidget {
  const CrashCountdownGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CrashCountdownGate> createState() => _CrashCountdownGateState();
}

enum _Phase { counting, cancelling, cancelled, escalated, takenUp, failed }

/// How long after a cancelled alert's arrival the rules accept a late
/// stand-down (isRiderStandDown).
const _standDownWindow = Duration(seconds: 90);

/// A cancel that does not come back in this long is reported as not
/// reaching NovaRide. Firestore may still deliver it, but if it arrives
/// after the countdown the rules refuse it, so "the dispatcher has it" is
/// the true thing to say.
const _cancelTimeout = Duration(seconds: 8);

class _CrashCountdownGateState extends ConsumerState<CrashCountdownGate> {
  RiderAlert? _active;
  _Phase _phase = _Phase.counting;
  Timer? _ticker;
  final _dismissed = <String>{};

  /// The last alert this rider cancelled, for the late stand-down.
  RiderAlert? _lastCancelled;
  bool _standingDown = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(riderAlertsProvider, (_, next) => _onAlerts(next.value ?? const []),
        fireImmediately: true);
    ref.listenManual(linkedRiderProvider, (_, next) => _onRider(next.value),
        fireImmediately: true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _onAlerts(List<RiderAlert> alerts) {
    final active = _active;
    if (active != null) {
      // A dispatcher acknowledged it during the countdown: help is coming,
      // and the rules no longer accept a cancel.
      final now = alerts.where((a) => a.id == active.id).firstOrNull;
      if (_phase == _Phase.counting &&
          now != null &&
          now.status != RiderAlertStatus.pending &&
          now.status != RiderAlertStatus.cancelled) {
        _settle(_Phase.takenUp);
      }
      return;
    }

    final clock = DateTime.now();
    for (final a in alerts) {
      final ends = a.countdownEndsAt;
      if (ends == null || !ends.isAfter(clock) || _dismissed.contains(a.id)) continue;
      setState(() {
        _active = a;
        _phase = _Phase.counting;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
      return;
    }
  }

  void _tick() {
    final ends = _active?.countdownEndsAt;
    if (_phase != _Phase.counting || ends == null) return;
    if (!ends.isAfter(DateTime.now())) {
      _settle(_Phase.escalated);
    } else {
      setState(() {});
    }
  }

  void _settle(_Phase phase) {
    _ticker?.cancel();
    if (mounted) setState(() => _phase = phase);
  }

  Future<void> _cancel() async {
    final alert = _active;
    final rider = ref.read(linkedRiderProvider).value;
    if (alert == null || rider == null || _phase != _Phase.counting) return;
    setState(() => _phase = _Phase.cancelling);
    try {
      await ref
          .read(riderAlertRepositoryProvider)
          .cancelPendingCrash(
            alertId: alert.id,
            riderId: rider.riderId,
            standDown: rider.status == 'emergency',
          )
          .timeout(_cancelTimeout);
      _lastCancelled = alert;
      _settle(_Phase.cancelled);
    } on Failure catch (failure) {
      AppLogger.w('countdown: cancel of ${alert.id} refused: ${failure.message}');
      _settle(_Phase.failed);
    } on TimeoutException {
      AppLogger.w('countdown: cancel of ${alert.id} timed out');
      _settle(_Phase.failed);
    }
  }

  /// The helmet's emergency write can land after the cancel. If it does,
  /// and nothing else critical is live for this rider, stand down — once.
  Future<void> _onRider(LinkedRider? rider) async {
    // Signed out, or unlinked, mid-countdown: it is no longer theirs to
    // answer, and the alert escalates on its own.
    if (rider == null && _active != null && mounted) {
      _ticker?.cancel();
      setState(() => _active = null);
    }
    final cancelled = _lastCancelled;
    if (rider == null || cancelled == null || _standingDown) return;
    if (rider.status != 'emergency') return;
    final arrived = cancelled.timestamp;
    if (arrived == null || !arrived.add(_standDownWindow).isAfter(DateTime.now())) return;
    final alerts = ref.read(riderAlertsProvider).value ?? const [];
    final otherLive = alerts.any((a) => a.id != cancelled.id && a.isCritical && a.isLive);
    if (otherLive) return;

    _standingDown = true;
    try {
      await ref
          .read(riderAlertRepositoryProvider)
          .standDown(riderId: rider.riderId, alertId: cancelled.id);
    } on Failure catch (failure) {
      AppLogger.w('countdown: late stand-down refused: ${failure.message}');
    } finally {
      _standingDown = false;
      _lastCancelled = null;
    }
  }

  void _dismiss() {
    setState(() {
      if (_active != null) _dismissed.add(_active!.id);
      _active = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Stack(
      children: [
        widget.child,
        if (active != null) Positioned.fill(child: _buildOverlay(context, active)),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context, RiderAlert alert) {
    final colors = context.colors;
    final text = context.text;
    final ends = alert.countdownEndsAt;
    final remaining = ends == null
        ? 0
        : (ends.difference(DateTime.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, kCrashCountdown.inSeconds);

    final (Color tone, String headline, String body) = switch (_phase) {
      _Phase.counting || _Phase.cancelling => (
          colors.critical,
          'Crash detected',
          'Are you OK? If you don\'t respond, the dispatcher is alerted when '
              'the timer reaches zero.',
        ),
      _Phase.cancelled => (
          colors.safe,
          'Alert cancelled',
          'Nobody has been dispatched. Ride safe.',
        ),
      _Phase.escalated => (
          colors.critical,
          'The dispatcher has been alerted',
          'Help is being arranged. Keep your phone with you; they may call.',
        ),
      _Phase.takenUp => (
          colors.critical,
          'A dispatcher is responding',
          'Help is being arranged. Keep your phone with you; they may call.',
        ),
      _Phase.failed => (
          colors.warning,
          'The alert could not be cancelled',
          'It may have been too late, or the phone could not reach NovaRide. '
              'The dispatcher has the alert and may call you.',
        ),
    };

    final counting = _phase == _Phase.counting || _phase == _Phase.cancelling;

    return Material(
      color: colors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                counting ? Icons.car_crash_outlined : Icons.info_outline,
                size: 56,
                color: tone,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(headline, textAlign: TextAlign.center, style: text.h1.copyWith(color: tone)),
              if (counting) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '$remaining',
                  key: const ValueKey('countdown-seconds'),
                  textAlign: TextAlign.center,
                  style: text.display.copyWith(color: colors.textPrimary, fontSize: 96),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(body, textAlign: TextAlign.center, style: text.bodyMuted),
              const Spacer(),
              if (counting)
                NovaPrimaryButton(
                  label: 'I\'m OK — cancel alert',
                  busy: _phase == _Phase.cancelling,
                  onPressed: _cancel,
                )
              else
                NovaPrimaryButton(label: 'Close', onPressed: _dismiss),
            ],
          ),
        ),
      ),
    );
  }
}
