// The authentication seam: role parsing, the simulation's sign-in, the
// operator-facing error messages, and — through a fake AdminAuth injected
// into AdminApp — the login page's in-flight state, the deny-on-unprovisioned
// path, and the shell leaving when the auth stream stops naming its user.
// Nothing here touches Firebase; that is the point of the seam.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/data/admin_auth.dart';
import 'package:novaride/admin/data/firebase_admin_auth.dart';
import 'package:novaride/admin/state/admin_session.dart';
import 'package:novaride/main_admin.dart';

/// Stands in for FirebaseAdminAuth: async, scriptable, and not a
/// LocalAdminAuth — so the login page shows the Firestore-path card.
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
  await tester.tap(find.text('SIGN IN'));
  await tester.pump();
}

Future<void> _tearDownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
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
          contains('No console account exists'));
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
    testWidgets('lists provisioned operators without passwords and fills '
        'the email only', (tester) async {
      await _useDesktopSurface(tester);
      final auth = _ScriptedAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AdminApp(auth: auth));

      expect(find.text('OPERATOR ACCOUNTS'), findsOneWidget);
      expect(find.text('DEMO CREDENTIALS'), findsNothing);
      for (final operator in provisionedOperators) {
        expect(find.text(operator.email), findsOneWidget);
      }
      for (final account in demoAccounts) {
        expect(find.text(account.password), findsNothing,
            reason: 'demo passwords belong to the simulation only');
      }

      await tester.enterText(find.byType(TextFormField).last, 'typed');
      await tester.tap(find.text(provisionedOperators.last.email));
      await tester.pump();

      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields.first.controller!.text, provisionedOperators.last.email);
      expect(fields.last.controller!.text, isEmpty,
          reason: 'tapping an operator never fills a password');
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
