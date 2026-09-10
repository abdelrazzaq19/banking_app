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
    required this.glassTint,
    required this.glassBorder,
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

  /// Translucent tint layer of a frosted surface.
  final Color glassTint;

  /// Hairline highlight along the edge of a frosted surface.
  final Color glassBorder;

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
    accent: Color(0xFF1F7AE0),
    success: Color(0xFF0F9D58),
    glassTint: Color(0x33FFFFFF),
    glassBorder: Color(0x66FFFFFF),
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
    glassTint: Color(0x1FFFFFFF),
    glassBorder: Color(0x3DFFFFFF),
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
    Color? glassTint,
    Color? glassBorder,
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
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
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
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
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
