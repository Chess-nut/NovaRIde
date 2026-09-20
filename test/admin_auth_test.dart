// The authentication seam: role parsing, the simulation's sign-in, the
// operator-facing error messages, and — through a fake AdminAuth injected
// into AdminApp — the login page itself: what it never shows, what the
// keyboard can do on it, the in-flight state, the remembered email, the
// deny-on-unprovisioned path, and the shell leaving when the auth stream
// stops naming its user. Nothing here touches Firebase; that is the point
// of the seam.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/console_build.dart';
import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/data/browser_storage.dart';
import 'package:novaride/admin/data/firebase_admin_auth.dart';
import 'package:novaride/admin/state/admin_session.dart';
import 'package:novaride/main_admin.dart';

import 'support/roboto.dart';

/// Stands in for FirebaseAdminAuth: async, scriptable, and not a
/// LocalAdminAuth — so the login page treats it as the Firestore path.
class _ScriptedAuth implements AdminAuth {
  final _changes = StreamController<AdminUser?>.broadcast();
  final signInCalls = <String>[];

  /// What the next signIn resolves to. A Completer lets a test hold the
  /// sign-in open to inspect the in-flight state.
  Completer<AdminUser>? pending;
  Object? failWith;

  AdminUser? _current;

  @override
  AdminUser? get currentUser => _current;

  @override
  Stream<AdminUser?> authStateChanges() => _changes.stream;

  @override
  Future<AdminUser> signIn(String email, String password) async {
    signInCalls.add(email);
    if (failWith != null) throw failWith!;
    final user = await (pending?.future ?? Future.value(_operator));
    _current = user;
    _changes.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }

  void emit(AdminUser? user) => _changes.add(user);

  void dispose() => _changes.close();
}

const _operator = AdminUser(
  name: 'Quinn Lunatal',
  email: 'qrlunatal@tip.edu.ph',
  role: AdminRole.superAdmin,
);

Future<void> _useDesktopSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _fillAndSubmit(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, 'whatever');
  // The button enables on the frame after both fields are filled.
  await tester.pump();
  await tester.tap(find.text('SIGN IN'));
  await tester.pump();
}

Future<void> _tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Every rendered string that looks like an email address. The email
/// field's own hint is the one address-shaped string the page is allowed
/// to show, and it is not an account.
Iterable<String> _renderedAddresses(WidgetTester tester) {
  final address = RegExp(r'S+@S+.S+');
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .where((data) => address.hasMatch(data) && !data.startsWith('name@'));
}

FocusNode? get _focused => FocusManager.instance.primaryFocus;

/// Presses Enter in whichever field currently holds the text input
/// connection — what the web engine does with a keyboard's Enter key.
Future<void> _pressEnter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  group('parseAdminRole', () {
    test('accepts the enum names verbatim', () {
      expect(parseAdminRole('superAdmin'), AdminRole.superAdmin);
      expect(parseAdminRole('dispatcher'), AdminRole.dispatcher);
      expect(parseAdminRole('viewer'), AdminRole.viewer);
    });

    test('tolerates the documented aliases on read', () {
      expect(parseAdminRole('administrator'), AdminRole.superAdmin);
      expect(parseAdminRole('admin'), AdminRole.superAdmin);
      expect(parseAdminRole('operator'), AdminRole.dispatcher);
      expect(parseAdminRole('  viewer '), AdminRole.viewer);
    });

    test('never defaults: unknown, empty, null and non-strings are null', () {
      expect(parseAdminRole('root'), isNull);
      expect(parseAdminRole('SuperAdmin'), isNull);
      expect(parseAdminRole(''), isNull);
      expect(parseAdminRole(null), isNull);
      expect(parseAdminRole(1), isNull);
      expect(parseAdminRole(true), isNull);
    });
  });

  group('LocalAdminAuth', () {
    test('signs the demo accounts in and out through the stream', () async {
      final auth = LocalAdminAuth();
      final seen = <AdminUser?>[];
      final sub = auth.authStateChanges().listen(seen.add);
      addTearDown(sub.cancel);

      final user = await auth.signIn('ADMIN@novaride.ph', 'admin123');
      expect(user.role, AdminRole.superAdmin);
      expect(auth.currentUser, same(user));

      await auth.signOut();
      expect(auth.currentUser, isNull);

      await Future<void>.delayed(Duration.zero);
      expect(seen, [user, null]);
    });

    test('rejects a wrong password with the operator-facing message',
        () async {
      final auth = LocalAdminAuth();
      await expectLater(
        auth.signIn('admin@novaride.ph', 'nope'),
        throwsA(isA<AdminAuthException>()
            .having((e) => e.message, 'message', 'Invalid email or password')),
      );
      expect(auth.currentUser, isNull);
    });
  });

  group('messageForFirebaseCode', () {
    test('maps the codes the login page is required to explain', () {
      expect(messageForFirebaseCode('wrong-password'),
          'Incorrect email or password.');
      expect(messageForFirebaseCode('invalid-credential'),
          'Incorrect email or password.');
      expect(messageForFirebaseCode('user-not-found'),
          messageForFirebaseCode('wrong-password'),
          reason: 'one message for both, or the login page is an '
              'account-enumeration oracle');
      expect(messageForFirebaseCode('too-many-requests'),
          contains('Too many failed attempts'));
      expect(messageForFirebaseCode('network-request-failed'),
          contains('Cannot reach Firebase'));
      expect(messageForFirebaseCode('permission-denied'),
          contains('security rules may not be deployed'));
    });

    test('never surfaces a raw code, known or not', () {
      for (final code in [
        'wrong-password',
        'invalid-credential',
        'user-not-found',
        'too-many-requests',
        'network-request-failed',
        'permission-denied',
        'some-future-code',
        '',
      ]) {
        final message = messageForFirebaseCode(code);
        expect(message, isNot(contains('firebase_auth')), reason: code);
        expect(message, isNot(contains('[')), reason: code);
        if (code.isNotEmpty) {
          expect(message, isNot(contains(code)), reason: code);
        }
        expect(message, endsWith('.'), reason: code);
      }
      expect(messageForFirebaseCode('some-future-code'), signInFailedMessage);
    });
  });

  group('login page on the Firestore path', () {
    testWidgets('names no account: no emails, no role badges, no passwords, '
        'and no simulation line', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      expect(_renderedAddresses(tester), isEmpty,
          reason: 'an operations console does not list its operators on '
              'the front door');
      for (final role in AdminRole.values) {
        expect(find.text(role.label.toUpperCase()), findsNothing);
      }
      for (final account in demoAccounts) {
        expect(find.text(account.password), findsNothing);
      }
      expect(find.textContaining('Simulation mode'), findsNothing,
          reason: 'live is the expected state; only the simulation says so');
      expect(find.textContaining(consoleVersionLabel), findsOneWidget);
    });

    testWidgets('disables the button while a sign-in is in flight, so a '
        'second tap cannot start another', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth()..pending = Completer<AdminUser>();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await _fillAndSubmit(tester, _operator.email);

      expect(auth.signInCalls, hasLength(1));
      expect(find.text('SIGN IN'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(auth.signInCalls, hasLength(1), reason: 'double-click guard');

      auth.pending!.complete(_operator);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('TYPE OF RIDER STATUS'), findsOneWidget);
      expect(find.text('Quinn Lunatal'), findsOneWidget);
      expect(find.text('SUPER ADMIN'), findsOneWidget);

      await _tearDownTree(tester);
    });

    testWidgets('an unprovisioned account is denied with an explanation, '
        'not a role', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth()
        ..failWith = const AdminAuthException(notProvisionedMessage);
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await _fillAndSubmit(tester, 'stranger@tip.edu.ph');
      await tester.pumpAndSettle();

      expect(find.text(notProvisionedMessage), findsOneWidget);
      expect(find.text('TYPE OF RIDER STATUS'), findsNothing);
      expect(find.text('SIGN IN'), findsOneWidget, reason: 'button restored');
    });

    testWidgets('an unexpected provider error shows a sentence, never the '
        'exception', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth()
        ..failWith = StateError('[firebase_auth/invalid-credential] boom');
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await _fillAndSubmit(tester, _operator.email);
      await tester.pumpAndSettle();

      expect(find.textContaining('firebase_auth'), findsNothing);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.textContaining('Sign-in failed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('login page form', () {
    testWidgets('the button enables only once both fields are filled',
        (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      ElevatedButton button() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextFormField).first, _operator.email);
      await tester.pump();
      expect(button().onPressed, isNull, reason: 'password still empty');

      await tester.enterText(find.byType(TextFormField).last, 'secret');
      await tester.pump();
      expect(button().onPressed, isNotNull);
    });

    testWidgets('a malformed email is caught inline, before any round-trip',
        (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await tester.enterText(find.byType(TextFormField).first, 'not-an-address');
      await tester.enterText(find.byType(TextFormField).last, 'secret');
      // The button enables on the frame after both fields are filled.
      await tester.pump();
      await tester.tap(find.text('SIGN IN'));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(auth.signInCalls, isEmpty, reason: 'never reached the provider');
      expect(_focused?.debugLabel, 'login-email',
          reason: 'the cursor goes to the field that needs fixing');

      // Typing again re-checks on every keystroke, so the message goes the
      // moment the address is well-formed.
      await tester.enterText(find.byType(TextFormField).first, 'a@b.co');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsNothing);
    });

    testWidgets('the email is checked on blur, not while it is being typed',
        (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await tester.enterText(find.byType(TextFormField).first, 'half@');
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsNothing,
          reason: 'still typing');

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focused?.debugLabel, 'login-password');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('Enter submits from the password field, and from the email '
        'field once there is a password to submit', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      // From the password field.
      await tester.enterText(find.byType(TextFormField).first, _operator.email);
      await tester.enterText(find.byType(TextFormField).last, 'secret');
      await _pressEnter(tester);
      expect(auth.signInCalls, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('TYPE OF RIDER STATUS'), findsOneWidget);

      auth.emit(null);
      await tester.pumpAndSettle();

      // From the email field with no password yet: Enter moves on to it.
      await tester.enterText(find.byType(TextFormField).first, _operator.email);
      await _pressEnter(tester);
      expect(_focused?.debugLabel, 'login-password');
      expect(auth.signInCalls, hasLength(1), reason: 'nothing to submit yet');

      // From the email field with a password present — the password
      // manager's case: Enter submits.
      await tester.enterText(find.byType(TextFormField).last, 'secret');
      await tester.enterText(find.byType(TextFormField).first, _operator.email);
      await _pressEnter(tester);
      expect(auth.signInCalls, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('TYPE OF RIDER STATUS'), findsOneWidget);

      await _tearDownTree(tester);
    });

    testWidgets('the sign-in error clears as soon as the operator types again',
        (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth()
        ..failWith = const AdminAuthException('Incorrect email or password.');
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await _fillAndSubmit(tester, _operator.email);
      await tester.pumpAndSettle();
      expect(find.text('Incorrect email or password.'), findsOneWidget);

      // The cursor is on the password with the old one selected, so the
      // retry is just typing.
      expect(_focused?.debugLabel, 'login-password');
      final password = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .last
          .controller!;
      expect(password.selection.start, 0);
      expect(password.selection.end, password.text.length);

      await tester.enterText(find.byType(TextFormField).last, 'another try');
      await tester.pump();
      expect(find.text('Incorrect email or password.'), findsNothing);
    });

    testWidgets('remembering the email keeps the address — only the address '
        '— for the next sign-in, and unticking forgets it at once',
        (tester) async {
      await _useDesktopSurface(tester);
      addTearDown(RememberedEmail.clear);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));
      expect(RememberedEmail.load(), isNull);
      expect(_focused?.debugLabel, 'login-email', reason: 'nothing to skip');

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await _fillAndSubmit(tester, _operator.email);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('TYPE OF RIDER STATUS'), findsOneWidget);
      expect(RememberedEmail.load(), _operator.email);

      auth.emit(null);
      await tester.pumpAndSettle();

      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields.first.controller!.text, _operator.email);
      expect(fields.last.controller!.text, isEmpty,
          reason: 'the password is never stored');
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(_focused?.debugLabel, 'login-password',
          reason: 'the cursor starts where the typing does');

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(RememberedEmail.load(), isNull);
    });

    testWidgets('tab order is email, password, sign in, then the secondary '
        'controls', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));
      expect(_focused?.debugLabel, 'login-email', reason: 'autofocus');

      // Filled, so the button is enabled — a disabled button is rightly
      // skipped by traversal, and the point here is the order when it is
      // in play.
      await tester.enterText(find.byType(TextFormField).first, _operator.email);
      await tester.enterText(find.byType(TextFormField).last, 'secret');
      await tester.enterText(find.byType(TextFormField).first, _operator.email);
      await tester.pump();
      expect(_focused?.debugLabel, 'login-email');

      Future<void> tab() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      await tab();
      expect(_focused?.debugLabel, 'login-password');
      await tab();
      expect(_focused?.debugLabel, 'login-submit');
      await tab();
      expect(_focused?.context?.findAncestorWidgetOfExactType<IconButton>(),
          isNotNull, reason: 'show-password toggle is reachable');
      // Space on the focused toggle reveals the password.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      await tab();
      expect(_focused?.context?.findAncestorWidgetOfExactType<Checkbox>(),
          isNotNull, reason: 'remember-email checkbox is reachable');
    });

    testWidgets('fields, toggle and button are labelled for assistive '
        'technology', (tester) async {
      await _useDesktopSurface(tester);
      final handle = tester.ensureSemantics();
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      final email = tester.getSemantics(find.byType(TextFormField).first);
      expect(email, isSemantics(isTextField: true));
      expect(email.label, contains('Email address'));

      final password = tester.getSemantics(find.byType(TextFormField).last);
      expect(password, isSemantics(isTextField: true, isObscured: true));
      expect(password.label, contains('Password'));

      expect(find.byTooltip('Show password'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ElevatedButton)),
        isSemantics(isButton: true, label: 'SIGN IN'),
      );
      handle.dispose();
    });
  });

  group('login page layout', () {
    testWidgets('the simulation says so in the footer', (tester) async {
      await _useDesktopSurface(tester);
      await tester.pumpWidget(const AdminApp());

      expect(find.textContaining('Simulation mode'), findsOneWidget);
      expect(_renderedAddresses(tester), isEmpty,
          reason: 'the demo accounts are documented, not displayed');
      for (final account in demoAccounts) {
        expect(find.text(account.password), findsNothing);
      }
    });

    testWidgets('fits a 1280×720 projector without scrolling, error banner '
        'and simulation line included', (tester) async {
      // 720 minus a browser's tab strip and address bar, in the real font.
      await useProjectorSurface(tester, projectorSize);
      await tester.pumpWidget(const AdminApp());

      await tester.enterText(
          find.byType(TextFormField).first, 'nope@novaride.ph');
      await tester.enterText(find.byType(TextFormField).last, 'wrong');
      // The button enables on the frame after both fields are filled.
      await tester.pump();
      await tester.tap(find.text('SIGN IN'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid email or password'), findsOneWidget);
      expect(find.textContaining('Simulation mode'), findsOneWidget);

      final page = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(page.first).position;
      expect(position.maxScrollExtent, 0, reason: 'nothing to scroll to');
      expect(tester.takeException(), isNull, reason: 'no overflow');
    }, skip: !hasRoboto);

    testWidgets('does not stretch on a wide monitor', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const AdminApp());

      expect(tester.getSize(find.byType(Form)).width, lessThanOrEqualTo(400));
      expect(tester.takeException(), isNull);
    });
  });

  group('session lifecycle', () {
    testWidgets('the shell returns to the login page when the auth stream '
        'emits null', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await _fillAndSubmit(tester, _operator.email);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('TYPE OF RIDER STATUS'), findsOneWidget);

      // A revoked token, a disabled account: the SDK signs out underneath.
      auth.emit(null);
      await tester.pumpAndSettle();

      expect(find.text('NovaRide TNVS Operations'), findsOneWidget);
      expect(find.text('TYPE OF RIDER STATUS'), findsNothing);
      expect(find.text('Quinn Lunatal'), findsNothing,
          reason: 'no stale session data');
    });

    testWidgets('the shell also leaves when a different operator takes over '
        'the session', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await _fillAndSubmit(tester, _operator.email);
      await tester.pump(const Duration(seconds: 1));

      // Another tab signed in as someone else; this shell would otherwise
      // keep acting under the wrong name.
      auth.emit(const AdminUser(
        name: 'Someone Else',
        email: 'qdplegarde@tip.edu.ph',
        role: AdminRole.viewer,
      ));
      await tester.pumpAndSettle();

      expect(find.text('NovaRide TNVS Operations'), findsOneWidget);
      expect(find.text('TYPE OF RIDER STATUS'), findsNothing);
    });

    testWidgets('the sidebar logout goes through signOut and clears the '
        'provider', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      await _fillAndSubmit(tester, _operator.email);
      await tester.pump(const Duration(seconds: 1));
      expect(auth.currentUser, isNotNull);

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(auth.currentUser, isNull);
      expect(find.text('NovaRide TNVS Operations'), findsOneWidget);
    });
  });
}
