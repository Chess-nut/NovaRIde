import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/family/screens/family_dashboard_page.dart';
import 'package:novaride/family/widgets/family_bottom_nav_bar.dart';

void main() {
  testWidgets('Family dashboard renders core safety content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FamilyDashboardPage()));

    expect(find.text('Family Safety'), findsOneWidget);
    expect(find.text('Rider Status'), findsOneWidget);
    expect(find.text('CURRENT TRIP'), findsOneWidget);
    expect(find.text('LIVE LOCATION'), findsOneWidget);
  });

  testWidgets('Family bottom nav includes the required sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(bottomNavigationBar: FamilyBottomNavBar(selectedIndex: 0))));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
