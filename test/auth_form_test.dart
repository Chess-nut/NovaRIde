// The auth forms' behaviour, as opposed to their looks.
//
// Three of these pin down things that were wrong or missing before Phase
// 2: an errorStyle that could collapse and hide the message, validation
// that only ran on submit, and fields a password manager could not fill.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/features/auth/presentation/pages/login_page.dart';
import 'package:novaride/features/rider/presentation/pages/home_page.dart';

import 'support/mobile_app.dart';

void main() {
  silenceAppLogger();

  Future<void> openLogin(WidgetTester tester) async {
    await pumpMobileApp(tester);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
  }

  group('login form', () {
    testWidgets('does not complain before anything is typed', (tester) async {
      await openLogin(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Enter your password.'), findsNothing);
      expect(find.text('Enter your email or username.'), findsNothing);
    });

    // autovalidateMode: onUserInteraction. The message has to appear once
    // a field has been touched, not only once the button is pressed.
    testWidgets('complains once a field has been touched and emptied',
        (tester) async {
      await openLogin(tester);

      final identifier = find.byType(TextFormField).first;
      await tester.enterText(identifier, 'a');
      await tester.pump();
      await tester.enterText(identifier, '');
      await tester.pumpAndSettle();

      expect(find.text('Enter your email or username.'), findsOneWidget);
    });

    // The message must be laid out, not clipped to nothing by an
    // errorStyle with no height — which is what the default was doing.
    testWidgets('renders the error message with a real size', (tester) async {
      await openLogin(tester);

      final identifier = find.byType(TextFormField).first;
      await tester.enterText(identifier, 'a');
      await tester.pump();
      await tester.enterText(identifier, '');
      await tester.pumpAndSettle();

      final size = tester.getSize(find.text('Enter your email or username.'));
      expect(size.height, greaterThan(8));
      expect(size.width, greaterThan(40));
    });

    testWidgets('offers the fields to a password manager', (tester) async {
      await openLogin(tester);

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.length, 2);
      expect(fields[0].autofillHints, contains(AutofillHints.username));
      expect(fields[1].autofillHints, contains(AutofillHints.password));
      expect(fields[0].textInputAction, TextInputAction.next);
      expect(fields[1].textInputAction, TextInputAction.done);
      expect(fields[1].obscureText, isTrue);
    });

    testWidgets('reveals and re-hides the password', (tester) async {
      await openLogin(tester);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isFalse,
      );

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TextField>(find.byType(TextField)).last.obscureText,
        isTrue,
      );
    });

    // The message is the same for a wrong password and an unknown
    // account, which is the rule the Firebase mapper keeps too.
    testWidgets('reports a bad credential without naming which half',
        (tester) async {
      await openLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, 'nobody');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpass1');
      await tester.tap(find.text('Log in').last);
      await tester.pumpAndSettle();

      expect(find.text('Incorrect username or password.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    // Signing in sets the session and lets the router's gate navigate.
    // Phase 3 changes where the profile comes from and nothing else.
    testWidgets('a good credential lands on the rider home', (tester) async {
      await openLogin(tester);

      await tester.enterText(find.byType(TextFormField).first, 'admin');
      await tester.enterText(find.byType(TextFormField).last, 'admin123');
      await tester.tap(find.text('Log in').last);
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });
  });
}
