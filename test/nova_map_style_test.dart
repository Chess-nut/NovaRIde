// The shared map look (lib/shared/maps/nova_map_style.dart): the values the
// mobile live map uses, and the pin and credit chip it draws.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/shared/maps/nova_map_style.dart';

/// The pin's two circles, found by their decoration.
Finder _circle(Color color) => find.byWidgetPredicate((w) {
  if (w is! Container) return false;
  final d = w.decoration;
  return d is BoxDecoration && d.shape == BoxShape.circle && d.color == color;
});

Future<void> _pumpCentered(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 64, height: 64, child: child)),
      ),
    ),
  );
}

void main() {
  test('tiles: OpenStreetMap, the mobile map\'s zoom and background', () {
    expect(NovaMapStyle.tileUrl, contains('{z}/{x}/{y}'));
    expect(
      NovaMapStyle.tileUrl,
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
    expect(NovaMapStyle.maxNativeZoom, 19);
    expect(NovaMapStyle.minZoom, 4);
    expect(NovaMapStyle.maxZoom, 19);
    expect(NovaMapStyle.background, const Color(0xFF0D1220));
    expect(
      NovaMapStyle.copyrightUri.toString(),
      'https://www.openstreetmap.org/copyright',
    );
  });

  testWidgets('NovaMapPin: 22 px dot with a 3 px dark ring, 56 px halo', (
    tester,
  ) async {
    const color = Color(0xFF3DDC97);
    await _pumpCentered(tester, const NovaMapPin(color: color));

    final dot = _circle(color);
    final halo = _circle(color.withValues(alpha: 0.22));
    expect(dot, findsOneWidget);
    expect(halo, findsOneWidget);
    expect(tester.getSize(dot), const Size(22, 22));
    expect(tester.getSize(halo), const Size(56, 56));
    expect(tester.getCenter(dot), tester.getCenter(halo));

    final ring =
        (tester.widget<Container>(dot).decoration! as BoxDecoration).border!
            as Border;
    expect(ring.top.color, const Color(0xFF0A0E1A));
    expect(ring.top.width, 3);
    expect(NovaMapPin.markerSize(), 64);
  });

  testWidgets('NovaMapPin compact is the same pin at 0.75×', (tester) async {
    const color = Color(0xFFFF3B5C);
    await _pumpCentered(tester, const NovaMapPin(color: color, compact: true));
    expect(tester.getSize(_circle(color)), const Size(16.5, 16.5));
    expect(
      tester.getSize(_circle(color.withValues(alpha: 0.22))),
      const Size(42, 42),
    );
    expect(NovaMapPin.markerSize(compact: true), 48);
  });

  testWidgets('NovaMapCredit: full text, bottom-left, on the dark chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, height: 300, child: NovaMapCredit()),
        ),
      ),
    );
    final text = find.text('© OpenStreetMap contributors');
    expect(text, findsOneWidget);
    expect(find.text('© OSM'), findsNothing);
    expect(tester.widget<Text>(text).style?.color, const Color(0xFFB8C0D0));
    expect(tester.widget<Text>(text).style?.fontSize, 12);
    expect(
      tester.widget<Align>(find.byType(Align)).alignment,
      Alignment.bottomLeft,
    );
    final chip = tester.widget<Container>(
      find.ancestor(of: text, matching: find.byType(Container)).first,
    );
    final box = chip.decoration! as BoxDecoration;
    expect(box.color, const Color(0xCC0A0E1A));
    expect(box.borderRadius, BorderRadius.circular(6));

    // footprint() is the chip with its margin (a Container's box includes
    // its margin), as laid out.
    final footprint = NovaMapCredit.footprint(tester.element(text));
    final drawn = tester.getRect(find.byWidget(chip));
    expect(footprint.width, closeTo(drawn.width, 0.01));
    expect(footprint.height, closeTo(drawn.height, 0.01));
  });

  testWidgets('NovaMapCredit compact: "© OSM"', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NovaMapCredit(compact: true))),
    );
    expect(find.text('© OSM'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsNothing);
  });
}
