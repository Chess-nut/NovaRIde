import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/errors/firebase_failure_mapper.dart';

void main() {
  test('a blocked Google popup gives browser-specific guidance', () {
    final failure = failureFromGoogleSignIn(
      FirebaseAuthException(code: 'popup-blocked'),
    );

    expect(failure.message, contains('Allow pop-ups'));
  });

  test('cancelled Google sign-in is reported without a credential error', () {
    final failure = failureFromGoogleSignIn(
      FirebaseAuthException(code: 'popup-closed-by-user'),
    );

    expect(
      failure.message,
      'Google sign-in was cancelled. No changes were made.',
    );
  });

  test('Firestore permission denial has an account-data-specific message', () {
    final failure = failureForCode('permission-denied');

    expect(
      failure.message,
      contains('could not read or save your account data'),
    );
    expect(failure.message, contains('access was denied'));
  });

  test('email already in use is not confused with Firestore failure', () {
    final failure = failureForCode('email-already-in-use');

    expect(failure.message, contains('An account already uses that email'));
    expect(failure.message, isNot(contains('access was denied')));
  });
}
