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
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('@juandc'), findsOneWidget);
    });

    // First and last word, so "Juan Dela Cruz" is JC and not JD.
    testWidgets('derives the avatar initials from the real name',
        (tester) async {
      await signedInAt(tester, '/rider');
      expect(find.text('JC'), findsOneWidget);
      expect(find.text('JD'), findsNothing);
    });

    testWidgets('invents no telemetry', (tester) async {
      await signedInAt(tester, '/rider');

      for (final text in fabricated) {
        expect(find.text(text), findsNothing, reason: 'still showing "$text"');
      }
      // Eight tiles with nothing behind them: battery, hardware,
      // signal, impact, alcohol, speed, distance, duration.
      //
      // Two finders, because the trip metrics are RichText (the unit is
      // a second span in a smaller size) and find.text does not look
      // inside one without being asked.
      expect(find.text(Unavailable.dash), findsNWidgets(5));
      expect(
        find.textContaining(Unavailable.dash, findRichText: true),
        findsNWidgets(8),
      );
    });

    testWidgets('says plainly that no helmet is paired', (tester) async {
      await signedInAt(tester, '/rider');
      expect(find.text('No helmet'), findsOneWidget);
      expect(find.text('No trip in progress'), findsOneWidget);
      // The green LIVE dot over three em dashes was the contradiction.
      expect(find.text('LIVE'), findsNothing);
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

    testWidgets('shows no trip count, distance or safety score',
        (tester) async {
      await openProfile(tester);

      expect(find.text('142'), findsNothing);
      expect(find.text('1,204'), findsNothing);
      expect(find.text('92'), findsNothing);
      expect(find.text('TOTAL TRIPS'), findsOneWidget);
      expect(find.text(Unavailable.dash), findsNWidgets(3));
    });

    testWidgets('does not claim a helmet is connected', (tester) async {
      await openProfile(tester);
      expect(find.text('Helmet Connected'), findsNothing);
      expect(find.text('No helmet paired'), findsOneWidget);
    });
  });
}
