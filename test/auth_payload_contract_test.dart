// Exports the payloads ensureProfile actually writes, so the rules tests
// can run them against the real ruleset.
//
// **Why this file exists.** The rules tests in rules_test/ were written
// with hand-made fixtures, so they proved the rules were right about a
// payload somebody typed in JavaScript — not about the payload the Dart
// code sends. A field the app omits and the rules require would pass
// every test here and fail at sign-up. That is not hypothetical: it is
// the gap named in the Phase 3 report.
//
// So: this test builds each payload through the production builders on
// FirebaseAuthRepository and writes it to rules_test/fixtures/. The Node
// side reads that file and runs it through a transaction against the
// real firestore.rules. Between them, a shape the rules refuse fails the
// suite.
//
// Run `flutter test` before `npm test` in rules_test/. The fixture is
// committed, so a change to the payload is visible in review as a change
// to this JSON.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/features/auth/data/firebase_auth_repository.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';

/// What the Node side turns back into `serverTimestamp()`.
///
/// The builders take the sentinel as an argument, which is the whole
/// reason they can run outside a Firebase app.
const serverTimestampMarker = '__SERVER_TIMESTAMP__';

/// Must match the ids the Node test signs in as.
const riderUid = 'uid-mobile-rider';
const riderEmail = 'rider@example.test';
const guardianUid = 'uid-mobile-guardian';
const guardianEmail = 'guardian@example.test';

void main() {
  test('exports the real ensureProfile payloads for the rules tests', () {
    final payloads = {
      'riderUid': riderUid,
      'riderEmail': riderEmail,
      'guardianUid': guardianUid,
      'guardianEmail': guardianEmail,
      'usernameLower': 'riderone',
      'user': FirebaseAuthRepository.buildUserDocument(
        uid: riderUid,
        email: riderEmail,
        username: 'riderone',
        fullName: 'Rider One',
        role: UserRole.rider,
        phoneNumber: '09171234567',
        serverTimestamp: serverTimestampMarker,
      ),
      'guardianUser': FirebaseAuthRepository.buildUserDocument(
        uid: guardianUid,
        email: guardianEmail,
        username: 'guardianone',
        fullName: 'Guardian One',
        role: UserRole.guardian,
        serverTimestamp: serverTimestampMarker,
      ),
      'profile': FirebaseAuthRepository.buildProfileDocument(
        serverTimestamp: serverTimestampMarker,
      ),
      'usernameClaim': FirebaseAuthRepository.buildUsernameClaim(
        uid: riderUid,
        email: riderEmail,
        serverTimestamp: serverTimestampMarker,
      ),
      'loginTouch': FirebaseAuthRepository.buildLoginTouch(
        serverTimestamp: serverTimestampMarker,
        fcmToken: 'a-push-token',
      ),
      'loginTouchNoToken': FirebaseAuthRepository.buildLoginTouch(
        serverTimestamp: serverTimestampMarker,
      ),
    };

    final file = File('rules_test/fixtures/auth_payloads.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(payloads)}\n',
    );

    expect(file.existsSync(), isTrue);
  });

  // The Node side proves the rules accept these. These prove the things
  // a rules test cannot see — that the app is sending what it should,
  // rather than something the rules merely tolerate.
  group('the payloads themselves', () {
    final user = FirebaseAuthRepository.buildUserDocument(
      uid: riderUid,
      email: riderEmail,
      username: 'riderone',
      fullName: 'Rider One',
      role: UserRole.rider,
      serverTimestamp: serverTimestampMarker,
    );

    // The field whose absence would have been caught here.
    test('users/ always carries fullName as a string', () {
      expect(user['fullName'], isA<String>());
      expect(user['fullName'], 'Rider One');
    });

    test('users/ carries the role as a wire name the rules accept', () {
      expect(user['role'], 'rider');
      expect(user['familyId'], riderUid);
      expect(
        FirebaseAuthRepository.buildUserDocument(
          uid: guardianUid,
          email: guardianEmail,
          username: 'guardianone',
          fullName: 'Guardian One',
          role: UserRole.guardian,
          serverTimestamp: serverTimestampMarker,
        )['role'],
        'guardian',
      );
    });

    test('a rider family and owner membership use server timestamps', () {
      final family = FirebaseAuthRepository.buildFamilyDocument(
        ownerUid: riderUid,
        serverTimestamp: serverTimestampMarker,
      );
      final member = FirebaseAuthRepository.buildFamilyMemberDocument(
        uid: riderUid,
        role: 'rider',
        displayName: 'Rider One',
        serverTimestamp: serverTimestampMarker,
      );

      expect(family, {
        'ownerUid': riderUid,
        'createdAt': serverTimestampMarker,
        'updatedAt': serverTimestampMarker,
      });
      expect(member['uid'], riderUid);
      expect(member['role'], 'rider');
      expect(member['status'], 'active');
      expect(member['displayName'], 'Rider One');
      expect(member['permissions'], {
        'liveLocation': true,
        'emergencyAlerts': true,
        'tripStatus': true,
        'helmetStatus': true,
        'incidentHistory': true,
      });
      expect(member['createdAt'], serverTimestampMarker);
      expect(member['updatedAt'], serverTimestampMarker);
    });

    test('every timestamp is the server clock, never a DateTime', () {
      for (final key in ['createdAt', 'updatedAt', 'lastLoginAt']) {
        expect(user[key], serverTimestampMarker, reason: key);
      }
      for (final value in user.values) {
        expect(value, isNot(isA<DateTime>()));
      }
    });

    // The rules use hasOnly here, because the document is readable by
    // anyone. A fourth key would be refused — and would be exposed.
    test('the username claim has exactly three keys', () {
      final claim = FirebaseAuthRepository.buildUsernameClaim(
        uid: riderUid,
        email: riderEmail,
        serverTimestamp: serverTimestampMarker,
      );
      expect(claim.keys.toSet(), {'uid', 'email', 'createdAt'});
    });

    // The rules refuse an update that changes either. Keeping them out
    // of the map is what makes the transaction legal.
    test('the sign-in touch never carries role or createdAt', () {
      final touch = FirebaseAuthRepository.buildLoginTouch(
        serverTimestamp: serverTimestampMarker,
        fcmToken: 'a-push-token',
      );
      expect(touch.keys.toSet(), {'lastLoginAt', 'updatedAt', 'fcmToken'});
      expect(touch.containsKey('role'), isFalse);
      expect(touch.containsKey('createdAt'), isFalse);
    });

    test('an empty fcmToken is left out rather than written blank', () {
      final touch = FirebaseAuthRepository.buildLoginTouch(
        serverTimestamp: serverTimestampMarker,
        fcmToken: '',
      );
      expect(touch.containsKey('fcmToken'), isFalse);
    });

    // The brief's last line, checked on the payload rather than trusted.
    test('no payload carries anything credential-shaped', () {
      const forbidden = {
        'password', 'passwordHash', 'passwordSalt', 'idToken', 'accessToken',
        'refreshToken', 'token', 'secret', 'apiKey', 'privateKey',
      };
      final all = [
        user,
        FirebaseAuthRepository.buildProfileDocument(
            serverTimestamp: serverTimestampMarker),
        FirebaseAuthRepository.buildUsernameClaim(
            uid: riderUid, email: riderEmail,
            serverTimestamp: serverTimestampMarker),
        FirebaseAuthRepository.buildLoginTouch(
            serverTimestamp: serverTimestampMarker, fcmToken: 'a-push-token'),
      ];
      for (final payload in all) {
        expect(payload.keys.toSet().intersection(forbidden), isEmpty);
      }
    });
  });
}
