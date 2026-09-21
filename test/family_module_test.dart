import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/emergency_contact/screens/rider_map_page.dart';
import 'package:novaride/emergency_contact/widgets/emergency_bottom_nav_bar.dart';

void main() {
  testWidgets('Emergency Contact map renders core rider content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RiderMapPage()));

    expect(find.text('Live Location'), findsOneWidget);
    expect(find.text('Juan dela Cruz'), findsOneWidget);
    expect(find.textContaining('RIDING'), findsOneWidget);
  });

  testWidgets('Emergency bottom nav includes the required sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(bottomNavigationBar: EmergencyBottomNavBar(selectedIndex: 0))));

    expect(find.text('MAP'), findsOneWidget);
    expect(find.text('ALERTS'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('PROFILE'), findsOneWidget);
  });
}
