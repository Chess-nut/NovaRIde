import 'package:flutter/material.dart';
import 'package:novaride/core/widgets/nova_brand_mark.dart';
import 'package:novaride/shared/theme.dart';

/// What is on screen while the router works out where to send you.
///
/// It has no logic of its own and no timer. The router's redirect moves off
/// it the moment [AuthState] resolves; if the app is sitting here, the
/// session is genuinely still unknown. Deliberately plain — Phase 2 gives
/// it the brand treatment.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: NovaColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NovaLogoMark(size: 88),
            SizedBox(height: 24),
            NovaWordmark(fontSize: 26),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: NovaColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
