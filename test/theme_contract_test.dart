// The theming contract Phase 2 was asked to keep.
//
// A light theme is not being built. The requirement was that adding one
// later must not mean restructuring anything, and that is a property of
// the code as it stands now — which means it can be tested now, and will
// break loudly the first time somebody writes a colour into a widget.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/app/app.dart';
import 'package:novaride/core/theme/app_colors.dart';
import 'package:novaride/core/theme/app_theme.dart';
import 'package:novaride/core/theme/theme_mode_provider.dart';

import 'support/mobile_app.dart';

void main() {
  silenceAppLogger();

  group('the palette travels with the theme', () {
    testWidgets('AppTheme.from installs its palette as an extension',
        (tester) async {
      late AppColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.from(AppColors.dark),
          home: Builder(
            builder: (context) {
              resolved = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, AppColors.dark);
    });

    // This is the whole point of the structure: a second palette changes
    // what widgets render without any widget knowing it happened.
    testWidgets('a different palette reaches widgets with no widget change',
        (tester) async {
      const other = AppColors(
        surface: Color(0xFFFFFFFF),
        surfaceRaised: Color(0xFFF4F6F9),
        surfaceSunken: Color(0xFFEBEFF5),
        border: Color(0xFFE3E8EF),
        borderStrong: Color(0xFFC7CEDA),
        textPrimary: Color(0xFF0C1420),
        textSecondary: Color(0xFF55637A),
        textMuted: Color(0xFF8A94A6),
        action: Color(0xFF0E9F6E),
        actionPressed: Color(0xFF0B7D57),
        actionDisabled: Color(0xFFC2E5D7),
        onAction: Color(0xFFFFFFFF),
        safe: Color(0xFF0E9F6E),
        riding: Color(0xFF1565D8),
        warning: Color(0xFFB26A00),
        critical: Color(0xFFD01B3C),
        sos: Color(0xFFC2185B),
        offline: Color(0xFF6C7280),
        resolved: Color(0xFF3D8FC7),
        accentViolet: Color(0xFF6D3BD1),
        scrim: Color(0x66000000),
      );

      late Color seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.from(other, brightness: Brightness.light),
          home: Builder(
            builder: (context) {
              seen = context.colors.action;
              return Scaffold(backgroundColor: context.colors.surface);
            },
          ),
        ),
      );

      expect(seen, const Color(0xFF0E9F6E));
      expect(seen, isNot(AppColors.dark.action));
    });

    testWidgets('context.colors falls back rather than throwing',
        (tester) async {
      late AppColors resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = context.colors;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, AppColors.dark);
    });
  });

  group('themeMode is wired', () {
    testWidgets('MaterialApp receives the provider value', (tester) async {
      await pumpMobileApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
    });

    // Only one palette exists, so light and dark are the same theme today.
    // The point is that changing the mode is already possible without
    // touching app.dart.
    testWidgets('changing the mode does not break the app', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const NovaRideApp(),
        ),
      );
      await tester.pumpAndSettle();

      container.read(themeModeProvider.notifier).set(ThemeMode.light);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
    });
  });

  // The rule was "every colour a semantic token, no raw values in
  // widgets". A reviewer cannot hold that line by eye across 20 files, so
  // it is checked mechanically. core/theme/ is where colours are supposed
  // to be defined and is exempt.
  group('no raw colours outside core/theme', () {
    final scanned = <String>[
      'lib/core/widgets',
      'lib/features/auth',
      'lib/features/onboarding',
    ];

    test('no Color(0x…) literals', () {
      final offenders = <String>[];
      for (final dir in scanned) {
        for (final file in _dartFilesIn(dir)) {
          final source = file.readAsStringSync();
          if (RegExp(r'Color\(0x').hasMatch(source)) {
            offenders.add(file.path);
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Define the colour in core/theme/app_colors.dart and read '
            'it with context.colors instead.',
      );
    });

    test('no Colors.* constants except transparent', () {
      final offenders = <String>[];
      for (final dir in scanned) {
        for (final file in _dartFilesIn(dir)) {
          final source = file.readAsStringSync();
          // The lookbehind keeps AppColors.* — the token class itself —
          // from matching, including where it appears in a doc comment.
          final hits = RegExp(r'(?<![A-Za-z])Colors\.(?!transparent)\w+')
              .allMatches(source)
              .map((m) => m.group(0)!)
              .toSet();
          if (hits.isNotEmpty) offenders.add('${file.path}: ${hits.join(', ')}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Material colour constants do not change with the theme. '
            'Use a token from context.colors.',
      );
    });

    test('nothing imports the admin console palette', () {
      final offenders = <String>[];
      for (final dir in scanned) {
        for (final file in _dartFilesIn(dir)) {
          if (file.readAsStringSync().contains('shared/theme.dart')) {
            offenders.add(file.path);
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'lib/shared/theme.dart is the admin console\'s palette. '
            'The mobile app uses core/theme/app_colors.dart.',
      );
    });
  });
}

Iterable<File> _dartFilesIn(String path) => Directory(path)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));
