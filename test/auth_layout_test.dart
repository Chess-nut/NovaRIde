// Every auth screen at small-phone size, with no overflow.
//
// Signal leans on generous spacing, which is exactly the thing that
// overflows on a 320×568 screen. These pump each of the eight screens at
// the smallest size worth supporting and fail on a RenderFlex overflow —
// the yellow-and-black stripes nobody wants on a projector.
//
// 320×568 is an iPhone SE 1st-gen / small Android at 1x. If it fits here
// it fits on the phones the study will actually use.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:novaride/app/di.dart';
import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_theme.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:novaride/features/auth/presentation/pages/legal_document_page.dart';
import 'package:novaride/features/auth/presentation/pages/login_page.dart';
import 'package:novaride/features/auth/presentation/pages/signup_page.dart';
import 'package:novaride/features/auth/presentation/pages/verify_email_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/role_selection_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/splash_page.dart';
import 'package:novaride/features/onboarding/presentation/pages/welcome_page.dart';

import 'support/fake_auth_repository.dart';
import 'support/mobile_app.dart';
import 'support/roboto.dart';

void main() {
  silenceAppLogger();

  const small = Size(320, 568);
  const tall = Size(412, 915);

  /// The screens ask go_router whether they can pop, so a bare
  /// MaterialApp is not enough context — they need a real router around
  /// them. One route, rendering the page under test.
  Future<void> pumpAt(
    WidgetTester tester,
    Widget page,
    Size size, {
    double keyboardInset = 0,
  }) async {
    // The test binding renders every glyph as a wide square, which makes
    // any width measurement meaningless. Load the SDK's real Roboto.
    await tester.runAsync(loadRoboto);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    if (keyboardInset > 0) {
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    }
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // The screens reach authStateProvider, which builds the real
        // repository unless it is overridden here.
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.from(AppColors.dark),
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => page)],
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the splash spins forever and would time out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  final screens = <String, Widget>{
    'splash': const SplashPage(),
    'welcome': const WelcomePage(),
    'select user type': const RoleSelectionPage(),
    'login (rider)': const LoginPage(),
    'login (guardian)': const LoginPage(role: UserRole.guardian),
    'signup': const SignupPage(),
    'forgot password': const ForgotPasswordPage(),
    'verify email': const VerifyEmailPage(email: 'rider@example.com'),
    'terms': const LegalDocumentPage(document: LegalDocument.terms),
    'privacy': const LegalDocumentPage(document: LegalDocument.privacy),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} fits a 320x568 screen', (tester) async {
      await pumpAt(tester, entry.value, small);
      expect(tester.takeException(), isNull);
    }, skip: !hasRoboto);

    testWidgets('${entry.key} fits a 412x915 screen', (tester) async {
      await pumpAt(tester, entry.value, tall);
      expect(tester.takeException(), isNull);
    }, skip: !hasRoboto);
  }

  // The forms are the ones at risk: the keyboard takes more than half the
  // screen, and a form that cannot scroll under it traps the last field.
  testWidgets('the sign-up form scrolls when the keyboard is up',
      (tester) async {
    await pumpAt(tester, const SignupPage(), small, keyboardInset: 280);

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, skip: !hasRoboto);
}
