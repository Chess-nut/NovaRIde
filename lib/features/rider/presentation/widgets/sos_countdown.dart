/// The SOS button's countdown: 10 seconds to cancel an accidental press,
/// then an SOS alert to NovaRide operations and the rider's guardians.
///
/// **How it reaches them.** The alert is one document in `alerts/`. The
/// operations console and the guardian app already listen there, so it
/// appears on the console's board and on the guardian's Home and Alerts
/// while their app is open. There are no push notifications yet: those
/// need Cloud Functions and Firebase Cloud Messaging.
///
/// **Why the countdown is on the phone.** A helmet crash counts down on the
/// server, so a phone broken in the crash cannot stop the alert. Here the
/// rider is holding the phone and pressed the button themself, so nothing
/// is written until the 10 seconds are up, and Cancel simply never sends.
///
/// **Then it calls [kSosHotline].** As soon as the countdown ends the alert
/// is sent and the phone calls the hotline straight away — the alert keeps
/// sending while the call is up. On Android the call is placed directly
/// (the first time, Android asks the rider to allow phone calls); if that
/// is refused, and on the web, the dialer opens with the number ready.
///
/// **Honest outcomes.** "Sent" only once the server has it. Without a
/// connection the alert stays queued and Firestore sends it on reconnect,
/// and the screen says so. An account not linked to a roster entry cannot
/// raise an alert at all, and the screen says that too, without calling —
/// no countdown has run, so the press may have been an accident. Every
/// outcome offers the call again.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:novaride/app/di.dart';
import 'package:novaride/core/errors/failure.dart';
import 'package:novaride/core/utils/app_logger.dart';
import 'package:novaride/shared/theme.dart';

import '../providers/helmet_telemetry_provider.dart';
import '../providers/rider_alerts_provider.dart';

/// How long the rider has to cancel.
const Duration kSosCountdown = Duration(seconds: 10);

/// How long to wait for the server before saying "not confirmed yet".
const Duration kSosConfirmWithin = Duration(seconds: 15);

/// The number the phone calls once the SOS goes out: the Quezon City
/// helpline. Change it here to point every SOS somewhere else.
const String kSosHotline = '122';

/// Places a call to a number. A provider so tests can watch it instead of
/// reaching for a phone.
typedef SosCaller = Future<void> Function(String number);

final sosCallerProvider = Provider<SosCaller>((ref) => placePhoneCall);

/// A direct call on Android; the dialer with the number filled in when
/// that is not possible (permission refused, the web, iOS).
Future<void> placePhoneCall(String number) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final placed = await FlutterPhoneDirectCaller.callNumber(number);
      if (placed == true) return;
    } on PlatformException catch (e, s) {
      AppLogger.w('Direct call failed, opening the dialer', error: e, stackTrace: s);
    }
  }
  final opened = await launchUrl(Uri.parse('tel:$number'));
  if (!opened) throw StateError('No app could dial $number');
}

/// Opens the countdown over everything.
Future<void> showSosCountdown(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    pageBuilder: (_, _, _) => const SosCountdownScreen(),
  );
}

enum _Phase { counting, sending, sent, queued, failed, notLinked }

class SosCountdownScreen extends ConsumerStatefulWidget {
  const SosCountdownScreen({super.key});

  @override
  ConsumerState<SosCountdownScreen> createState() => _SosCountdownState();
}

class _SosCountdownState extends ConsumerState<SosCountdownScreen> {
  Timer? _ticker;
  int _left = kSosCountdown.inSeconds;
  _Phase _phase = _Phase.counting;
  bool _called = false;

  @override
  void initState() {
    super.initState();
    // Known to be unlinked: say so now, not after ten seconds.
    final linked = ref.read(linkedRiderProvider);
    if (linked.hasValue && linked.value == null) {
      _phase = _Phase.notLinked;
      return;
    }
    HapticFeedback.heavyImpact();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    if (_left <= 1) {
      _send();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _left--);
  }

  // A void seam: the buttons never hold the Future.
  void _send() {
    _ticker?.cancel();
    if (_phase != _Phase.counting && _phase != _Phase.failed) return;
    unawaited(
      _deliver().catchError((Object e, StackTrace s) {
        AppLogger.e('SOS send threw', error: e, stackTrace: s);
        if (mounted) setState(() => _phase = _Phase.failed);
      }),
    );
  }

  Future<void> _deliver() async {
    final rider = ref.read(linkedRiderProvider).value;
    if (rider == null) {
      setState(() => _phase = _Phase.notLinked);
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _left = 0;
    });
    HapticFeedback.heavyImpact();

    final t = ref.read(helmetTelemetryProvider).value;
    final send = ref
        .read(riderAlertRepositoryProvider)
        .sendSos(
          rider: rider,
          lat: t?.lat,
          lng: t?.lng,
          fixAt: t?.positionAt,
        );
    // The alert is on its way; now the call. Only once per SOS — a retry
    // after a failed send does not ring the hotline a second time.
    if (!_called) {
      _called = true;
      _callHotline();
    }
    try {
      await send.timeout(kSosConfirmWithin);
      if (!mounted) return;
      setState(() => _phase = _Phase.sent);
    } on TimeoutException {
      // Still queued: Firestore sends it once the phone is back online.
      if (!mounted) return;
      setState(() => _phase = _Phase.queued);
      unawaited(
        send
            .then((_) {
              if (mounted) setState(() => _phase = _Phase.sent);
            })
            .catchError((Object e, StackTrace s) {
              AppLogger.e('Queued SOS failed', error: e, stackTrace: s);
              if (mounted) setState(() => _phase = _Phase.failed);
            }),
      );
    } on Failure catch (e, s) {
      AppLogger.e('SOS refused: ${e.message}', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _phase = _Phase.failed);
    }
  }

  void _cancel() {
    _ticker?.cancel();
    Navigator.of(context).pop();
  }

  void _close() => Navigator.of(context).pop();

  void _callHotline() {
    final call = ref.read(sosCallerProvider);
    unawaited(
      call(kSosHotline).catchError((Object e, StackTrace s) {
        AppLogger.w('Calling $kSosHotline failed', error: e, stackTrace: s);
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Couldn\'t start the call. Dial $kSosHotline.'),
            ),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back during the countdown is a cancel; while sending it is not.
      canPop: _phase != _Phase.sending,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _ticker?.cancel();
      },
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: switch (_phase) {
              _Phase.counting => _Counting(
                left: _left,
                onCancel: _cancel,
                onSendNow: _send,
              ),
              _Phase.sending => const _Outcome(
                icon: Icons.sos,
                color: NovaColors.red,
                title: 'Sending SOS…',
                body: 'Alerting NovaRide operations and your guardians.',
                busy: true,
              ),
              _Phase.sent => _Outcome(
                icon: Icons.check_circle,
                color: NovaColors.green,
                title: 'SOS sent',
                body:
                    'NovaRide operations and your guardians can see your '
                    'alert now, with your helmet\'s last location. Your '
                    'phone is calling $kSosHotline. Stay where you are if '
                    'it is safe.',
                onCall: _callHotline,
                onClose: _close,
              ),
              _Phase.queued => _Outcome(
                icon: Icons.cloud_off,
                color: NovaColors.amber,
                title: 'Not confirmed yet',
                body:
                    'Your phone has no connection. The SOS is saved and will '
                    'send as soon as you are back online. Your phone is '
                    'calling $kSosHotline.',
                onCall: _callHotline,
                onClose: _close,
              ),
              _Phase.failed => _Outcome(
                icon: Icons.error_outline,
                color: NovaColors.red,
                title: 'SOS didn\'t go through',
                body:
                    'NovaRide couldn\'t send your alert. Try again — the '
                    'call to $kSosHotline has already started.',
                onRetry: _send,
                onCall: _callHotline,
                onClose: _close,
              ),
              _Phase.notLinked => _Outcome(
                icon: Icons.link_off,
                color: NovaColors.amber,
                title: 'SOS can\'t reach operations yet',
                body:
                    'Your account isn\'t linked to a NovaRide rider profile, '
                    'so there is no one to alert. Ask operations to link it. '
                    'If you need help now, call $kSosHotline.',
                onCall: _callHotline,
                onClose: _close,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// The big number, Cancel and Send now.
class _Counting extends StatelessWidget {
  const _Counting({
    required this.left,
    required this.onCancel,
    required this.onSendNow,
  });

  final int left;
  final VoidCallback onCancel;
  final VoidCallback onSendNow;

  @override
  Widget build(BuildContext context) {
    final total = kSosCountdown.inSeconds;
    return Column(
      children: [
        const Spacer(),
        const Text(
          'SENDING SOS IN',
          style: TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          label: 'Sending SOS in $left seconds',
          excludeSemantics: true,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: left / total,
                    strokeWidth: 10,
                    color: NovaColors.red,
                    backgroundColor: NovaColors.cardBorder,
                  ),
                ),
                Text(
                  '$left',
                  key: const ValueKey('sos-seconds'),
                  style: const TextStyle(
                    color: NovaColors.primaryText,
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'NovaRide operations and your guardians will be alerted with your '
          'helmet\'s location, and your phone will call $kSosHotline.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NovaColors.primaryText,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton(
            onPressed: onCancel,
            style: FilledButton.styleFrom(
              backgroundColor: NovaColors.green,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'CANCEL — I\'M OK',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: onSendNow,
            style: OutlinedButton.styleFrom(
              foregroundColor: NovaColors.red,
              side: const BorderSide(color: NovaColors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'SEND NOW',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

/// What happened, and what the rider can do next.
class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.busy = false,
    this.onRetry,
    this.onCall,
    this.onClose,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool busy;
  final VoidCallback? onRetry;
  final VoidCallback? onCall;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: busy
              ? Padding(
                  padding: const EdgeInsets.all(34),
                  child: CircularProgressIndicator(
                    color: color,
                    strokeWidth: 5,
                  ),
                )
              : Icon(icon, color: color, size: 56),
        ),
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NovaColors.primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: NovaColors.secondaryText,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const Spacer(),
        if (onRetry != null) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: NovaColors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (onCall != null) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.call),
              label: const Text(
                'CALL $kSosHotline',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: NovaColors.primaryText,
                side: const BorderSide(color: NovaColors.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (onClose != null)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: onClose,
              child: const Text(
                'Close',
                style: TextStyle(
                  color: NovaColors.secondaryText,
                  fontSize: 15,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
