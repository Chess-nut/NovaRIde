// The rider screens show the person who signed in, and nothing they
// cannot measure.
//
// These screens shipped with a demo persona baked in — "Deor the great",
// Rider #NV-08567, 142 trips, 1,204 km, a safety score of 92, 78%
// battery, a trip from Makati Ave to BGC. Somebody signing up as
// themselves saw an invented stranger.
//
// Two things are asserted, and the second matters as much as the first:
// the real name is on screen, and the invented figures are *gone* rather
// than replaced by other invented figures. A plausible number with no
// source behind it survives a demo right up until somebody asks where it
// came from.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/widgets/unavailable.dart';
import 'package:novaride/features/auth/domain/entities/user_profile.dart';
import 'package:novaride/features/auth/domain/entities/user_role.dart';
import 'package:novaride/features/rider/presentation/pages/home_page.dart';
import 'package:novaride/features/rider/presentation/pages/profile_page.dart';

import 'support/fake_auth_repository.dart';
import 'support/mobile_app.dart';

void main() {
  silenceAppLogger();

  const rider = UserProfile(
    uid: 'uid-rider',
    email: 'juan@example.test',
    username: 'juandc',
    fullName: 'Juan Dela Cruz',
    role: UserRole.rider,
    emailVerified: true,
    phoneNumber: '09171234567',
  );

  /// Everything the two screens used to invent.
  const fabricated = [
    'Deor the great',
    'Rider #NV-08567',
    '142',
    '1,204',
    '92',
    '78%',
    'ESP32',
    '-62\ndBm',
    '0.3G',
    '0.00%',
    '42',
    '8.3',
    '23:47',
    'Makati Ave → Bonifacio Global City',
    'Connected',
    'Helmet Connected',
  ];

  Future<void> signedInAt(WidgetTester tester, String path) async {
    final repository = FakeAuthRepository(
      accounts: {'juan@example.test': ('rider123', rider)},
      usernames: const {'juandc': 'juan@example.test'},
    );
    addTearDown(repository.dispose);
    await pumpMobileApp(tester, repository: repository);
    repository.emit(rider);
    await tester.pumpAndSettle();
  }

  group('rider home', () {
    testWidgets('greets the account that signed in', (tester) async {
      await signedInAt(tester, '/rider');

      expect(find.byType(HomePage), findsOneWidget);
      // First name only: the full name and @username live on Profile.
      expect(find.text('Hi, Juan'), findsOneWidget);
      expect(find.text('Hi, Deor'), findsNothing);
    });

    testWidgets('invents no telemetry', (tester) async {
      await signedInAt(tester, '/rider');

      for (final text in fabricated) {
        expect(find.text(text), findsNothing, reason: 'still showing "$text"');
      }
      // Five readings with nothing behind them: alcohol, posture, impact,
      // location and speed. Battery, hardware, signal, distance and
      // duration are gone from the screen rather than dashed: nothing
      // will ever fill them.
      expect(find.text(Unavailable.dash), findsNWidgets(5));
    });

    testWidgets('says plainly that no helmet is paired', (tester) async {
      await signedInAt(tester, '/rider');
      // The status card, and each of the four sensors.
      expect(find.text('No helmet'), findsNWidgets(5));
      expect(
        find.text('Speed shows only while the helmet is live.'),
        findsOneWidget,
      );
      // A green "Live" over a row of em dashes was the contradiction.
      expect(find.text('Live'), findsNothing);
    });
  });

  group('rider profile', () {
    Future<void> openProfile(WidgetTester tester) async {
      await signedInAt(tester, '/rider');
      await tester.tap(find.byIcon(Icons.person_outline).last);
      await tester.pumpAndSettle();
    }

    testWidgets('names the account and not the demo persona', (tester) async {
      await openProfile(tester);

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsWidgets);
      expect(find.text('@juandc'), findsWidgets);
      expect(find.text('Deor the great'), findsNothing);
      expect(find.text('Rider #NV-08567'), findsNothing);
    });

    // First and last word, so "Juan Dela Cruz" is JC and not JD. Moved
    // here from the home screen, which no longer draws an avatar.
    testWidgets('derives the avatar initials from the real name', (
      tester,
    ) async {
      await openProfile(tester);
      expect(find.text('JC'), findsOneWidget);
      expect(find.text('JD'), findsNothing);
    });

    testWidgets('shows no trip count, distance or safety score', (
      tester,
    ) async {
      await openProfile(tester);

      expect(find.text('142'), findsNothing);
      expect(find.text('1,204'), findsNothing);
      expect(find.text('92'), findsNothing);
      // The three stat tiles are gone rather than dashed: nothing
      // computes trips, distance or a score, so they could only ever be
      // empty. Home dropped its never-filled tiles for the same reason.
      expect(find.text('Total trips'), findsNothing);
      expect(find.text(Unavailable.dash), findsNothing);
    });

    testWidgets('has no rows that go nowhere', (tester) async {
      await openProfile(tester);
      // "Help & Support" did nothing when tapped.
      expect(find.text('Help & Support'), findsNothing);
      expect(find.text('NovaRide v4.2.0'), findsNothing);
      expect(find.text('Privacy policy'), findsOneWidget);
    });

    testWidgets('does not claim a helmet is connected', (tester) async {
      await openProfile(tester);
      expect(find.text('Helmet Connected'), findsNothing);
      expect(find.text('No helmet paired'), findsOneWidget);
    });
  });
}
