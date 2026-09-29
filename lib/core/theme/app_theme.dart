/// The mobile app's [ThemeData].
///
/// Phase 1 keeps the palette exactly where it was — [NovaColors] in
/// `lib/shared/theme.dart`, which the admin console also imports — and only
/// moves the *assembly* of the theme out of `main.dart`. The visual
/// redesign is Phase 2, and it lands here: a semantic palette of this app's
/// own, a real type scale, and component themes, with `shared/theme.dart`
/// left to the console.
///
/// Nothing in `features/` should read a raw [Color] constant once Phase 2
/// is done; until then the moved screens still do, because rewriting their
/// UI now would be the redesign happening twice.
library;

import 'package:flutter/material.dart';
import 'package:novaride/shared/theme.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NovaColors.background,
        fontFamily: 'Roboto',
      );
}
