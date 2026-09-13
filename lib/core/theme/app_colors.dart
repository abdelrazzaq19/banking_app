import 'package:flutter/material.dart';

/// Brand colours that do not change between light and dark.
///
/// These are the identity of the product; everything else is derived. They are
/// the only literal colour values the app should contain.
abstract final class Brand {
  /// Seed for both `ColorScheme`s, and the deepest tone of the card gradient.
  static const Color deep = Color(0xFF00499B);
  static const Color mid = Color(0xFF3E96F4);
  static const Color light = Color(0xFF7BC0FF);
}

/// Semantic colours the Material `ColorScheme` has no role for.
///
/// Screens read these through `context.colors` instead of importing raw
/// palette constants, which is what lets the same widget render correctly in
/// both light and dark.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.headerBackground,
    required this.onHeader,
    required this.sheetBackground,
    required this.cardGradient,
    required this.onCard,
    required this.mutedFill,
    required this.mutedBorder,
    required this.subtleText,
    required this.accent,
    required this.success,
    required this.warning,
    required this.glassTint,
    required this.glassBorder,
    required this.chartPalette,
  });

  /// The brand-coloured band behind the home sheet.
  final Color headerBackground;

  /// Text and icons drawn on [headerBackground].
  final Color onHeader;

  /// The rounded panel that sits over the header.
  final Color sheetBackground;

  /// Three stops for the balance card, dark to light.
  final List<Color> cardGradient;

  /// Text and icons drawn on a balance card.
  final Color onCard;

  /// Fill for search fields, segmented-control tracks and other inert chrome.
  final Color mutedFill;

  /// Hairlines, field outlines and dividers.
  final Color mutedBorder;

  /// Secondary copy: captions, hints, de-emphasised labels.
  final Color subtleText;

  /// Interactive accent for links and secondary actions.
  final Color accent;

  /// Positive amounts and confirmations.
  final Color success;

  /// Caution without failure: a middling password, a budget nearly spent.
  final Color warning;

  /// Translucent tint layer of a frosted surface.
  final Color glassTint;

  /// Hairline highlight along the edge of a frosted surface.
  final Color glassBorder;

  /// Categorical series colours, assigned in fixed order and never cycled.
  ///
  /// Validated with the data-viz palette checker against this theme's own chart
  /// surface: lightness band, chroma floor, colour-vision separation and
  /// normal-vision separation all pass in both modes. In light mode three of
  /// the seven sit below 3:1 against white, which the checker flags as needing
  /// relief — the category breakdown ships a labelled, ranked list beside the
  /// bar, so identity never rests on colour alone.
  final List<Color> chartPalette;

  // The header and card blues are deeper than the raw brand light tone: white
  // on Brand.light measures 1.94:1, well under the 4.5:1 AA needs, so card
  // balances and tab labels were effectively unreadable at the light end of the
  // gradient. These tones keep the brand while clearing AA.
  static const AppColors light = AppColors(
    headerBackground: Color(0xFF0B5FC0),
    onHeader: Color(0xFFFFFFFF),
    sheetBackground: Color(0xFFFFFFFF),
    cardGradient: [Color(0xFF00336F), Color(0xFF0B5FC0), Color(0xFF2570C2)],
    onCard: Color(0xFFFFFFFF),
    mutedFill: Color(0xFFF1F4F8),
    mutedBorder: Color(0xFFD8DEE7),
    subtleText: Color(0xFF5B6472),
    // Deepened from 4.27:1 — a near miss, but this tone carries the ghost
    // button's label, which is text like any other.
    accent: Color(0xFF1A6FD0),
    // Darker than a stock material green: the original measured 3.51:1 on
    // white, and this colour carries text — "enough balance", a completed
    // transfer — not just a dot.
    success: Color(0xFF0B8049),
    warning: Color(0xFFB25E02),
    glassTint: Color(0x33FFFFFF),
    glassBorder: Color(0x66FFFFFF),
    chartPalette: [
      Color(0xFF2A78D6), // blue
      Color(0xFFEB6834), // orange
      // Teal rather than the original aqua green. Darkening the green to
      // clear 3:1 dropped it to 5.5 deltaE from the orange under
      // protanopia; moving it round to teal restores 11.1 while keeping
      // enough chroma not to read as grey.
      Color(0xFF00918A), // teal
      // Yellow is the hard one on a white ground: the bright tone measured
      // 2.17:1. Taken down to an amber that clears 3:1 and still reads as
      // the warm slot between orange and magenta.
      Color(0xFFB57400), // yellow
      Color(0xFFD45E8B), // magenta, deepened from 2.69:1 to clear 3:1
      Color(0xFF008300), // green
      Color(0xFF4A3AA7), // violet
    ],
  );

  static const AppColors dark = AppColors(
    headerBackground: Color(0xFF0B2545),
    onHeader: Color(0xFFE8F1FF),
    sheetBackground: Color(0xFF121822),
    cardGradient: [Color(0xFF0A3A73), Color(0xFF16558F), Color(0xFF2570C2)],
    onCard: Color(0xFFFFFFFF),
    mutedFill: Color(0xFF1B2331),
    mutedBorder: Color(0xFF2E3A4C),
    subtleText: Color(0xFF9AA6B8),
    accent: Brand.light,
    success: Color(0xFF4CAF7D),
    warning: Color(0xFFE0A44A),
    glassTint: Color(0x1FFFFFFF),
    glassBorder: Color(0x3DFFFFFF),
    // The same seven hues, re-stepped for the dark surface — not an automatic
    // flip of the light values.
    chartPalette: [
      Color(0xFF3987E5),
      Color(0xFFD95926),
      Color(0xFF199E70),
      Color(0xFFC98500),
      Color(0xFFD55181),
      Color(0xFF008300),
      Color(0xFF9085E9),
    ],
  );

  @override
  AppColors copyWith({
    Color? headerBackground,
    Color? onHeader,
    Color? sheetBackground,
    List<Color>? cardGradient,
    Color? onCard,
    Color? mutedFill,
    Color? mutedBorder,
    Color? subtleText,
    Color? accent,
    Color? success,
    Color? warning,
    Color? glassTint,
    Color? glassBorder,
    List<Color>? chartPalette,
  }) {
    return AppColors(
      headerBackground: headerBackground ?? this.headerBackground,
      onHeader: onHeader ?? this.onHeader,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      cardGradient: cardGradient ?? this.cardGradient,
      onCard: onCard ?? this.onCard,
      mutedFill: mutedFill ?? this.mutedFill,
      mutedBorder: mutedBorder ?? this.mutedBorder,
      subtleText: subtleText ?? this.subtleText,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      chartPalette: chartPalette ?? this.chartPalette,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      headerBackground:
          Color.lerp(headerBackground, other.headerBackground, t)!,
      onHeader: Color.lerp(onHeader, other.onHeader, t)!,
      sheetBackground: Color.lerp(sheetBackground, other.sheetBackground, t)!,
      cardGradient: [
        for (var i = 0; i < cardGradient.length; i++)
          Color.lerp(cardGradient[i], other.cardGradient[i], t)!,
      ],
      onCard: Color.lerp(onCard, other.onCard, t)!,
      mutedFill: Color.lerp(mutedFill, other.mutedFill, t)!,
      mutedBorder: Color.lerp(mutedBorder, other.mutedBorder, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      chartPalette: [
        for (var i = 0; i < chartPalette.length; i++)
          Color.lerp(chartPalette[i], other.chartPalette[i], t)!,
      ],
    );
  }
}

/// Shorthand for the two lookups every screen needs.
extension AppThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Picks a series colour by fixed position.
///
/// Wrapping is a last resort, not a design: past the palette's length the
/// callers should be folding into "Other" instead.
extension ChartPalette on AppColors {
  Color seriesColor(int index) =>
      chartPalette[index % chartPalette.length];
}
