// The test binding renders every glyph as a wide square, which wraps
// single-line copy onto two or three lines and makes any layout-height
// check meaningless. Tests that assert on fit load the console's real
// face — the SDK's own Roboto — under the family name the app asks for.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final Directory? _materialFonts = Platform.environment['FLUTTER_ROOT'] == null
    ? null
    : Directory(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/'
        'material_fonts',
      );

/// False when the SDK's font cache cannot be found; tests that need the
/// real font pass `skip: !hasRoboto` rather than measuring the wrong thing.
bool get hasRoboto =>
    _materialFonts != null &&
    File('${_materialFonts!.path}/roboto-regular.ttf').existsSync();

/// Loads Roboto regular, medium and bold as the `Roboto` family. Must run
/// inside `tester.runAsync`: it reads real files, and a widget test body
/// runs under fake async where that would never complete.
Future<void> loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold']) {
    final file = File('${_materialFonts!.path}/roboto-$weight.ttf');
    loader.addFont(
      file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
}

/// A 1280×720 projector after a browser's tab strip and address bar.
const projectorSize = Size(1280, 633);

Future<void> useProjectorSurface(WidgetTester tester, Size size) async {
  await tester.runAsync(loadRoboto);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}
