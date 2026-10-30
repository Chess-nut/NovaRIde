import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// What a figure looks like when nothing is measuring it.
///
/// The rider screens were built with a demo persona in them — 78% battery,
/// 142 trips, a safety score of 92. None of those had a source, and a
/// plausible number is worse than a blank one: it survives a demo right
/// up until somebody asks where it came from, and then it is the whole
/// app's credibility rather than one tile's.
///
/// So anything without a feed shows this instead. It is deliberately
/// quiet — a muted em dash, not an error — because there is nothing
/// wrong; the helmet simply is not reporting to this account yet.
class Unavailable extends StatelessWidget {
  const Unavailable({super.key, this.fontSize = 18});

  final double fontSize;

  /// The character itself, for callers that need a plain string rather
  /// than a widget.
  static const dash = '—';

  @override
  Widget build(BuildContext context) {
    return Text(
      dash,
      style: TextStyle(
        color: context.colors.textMuted,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
      semanticsLabel: 'No data',
    );
  }
}
