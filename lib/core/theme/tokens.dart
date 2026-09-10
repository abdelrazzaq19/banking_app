import 'package:flutter/widgets.dart';

/// Spacing scale. Every gap in the app should come from here rather than a
/// one-off number, so rhythm stays consistent as screens are rebuilt.
abstract final class Insets {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(md);
  static const EdgeInsets sheet = EdgeInsets.all(md);
}

/// Corner radii. `pill` is deliberately large so it always fully rounds.
abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get pillAll => BorderRadius.circular(pill);

  static const BorderRadius sheetTop = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
  );
}

/// Frosted-glass surface constants, used by the balance cards.
abstract final class Glass {
  /// Sigma passed to the backdrop blur.
  static const double blur = 18;

  /// How much the tint layer covers what is behind it.
  static const double tintOpacity = 0.16;

  /// Opacity of the hairline highlight along a glass edge.
  static const double borderOpacity = 0.28;

  /// Opacity of the inner highlight sweep.
  static const double sheenOpacity = 0.10;
}

/// Standard opacities for de-emphasised content.
abstract final class Alphas {
  static const double disabled = 0.38;
  static const double subtle = 0.60;
  static const double hairline = 0.20;
  static const double scrim = 0.50;
}
