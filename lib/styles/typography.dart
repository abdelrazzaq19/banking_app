import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// The original type scale. Screens still reference these names directly while
// they are migrated one at a time; `buildTextTheme` below turns the same scale
// into a real Material `TextTheme` so framework components match.
final headline1 = GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold);
final headline2 = GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold);
final headline3 = GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold);
final headline4 = GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold);
final headline5 = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold);
final headline6 = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold);

final subHeadline1 =
    GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600);
final subHeadline2 =
    GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600);
final subHeadline3 =
    GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600);
final subHeadline4 =
    GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600);
final subHeadline5 =
    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600);

final bodyText1 = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400);
final bodyText2 = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400);
final bodyText3 = GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400);

final caption = GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400);
final metadata = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w400);

/// Builds the Material text theme from the same scale, coloured for [scheme].
///
/// Amounts and account numbers use tabular figures so digits keep their column
/// when a balance animates or a list of transactions is scanned vertically.
TextTheme buildTextTheme(ColorScheme scheme) {
  final onSurface = scheme.onSurface;
  final onSurfaceVariant = scheme.onSurfaceVariant;

  return TextTheme(
    displayLarge: headline1.copyWith(color: onSurface),
    displayMedium: headline2.copyWith(color: onSurface),
    displaySmall: headline3.copyWith(color: onSurface),
    headlineLarge: headline2.copyWith(color: onSurface),
    headlineMedium: headline3.copyWith(color: onSurface),
    headlineSmall: headline4.copyWith(color: onSurface),
    titleLarge: subHeadline3.copyWith(color: onSurface),
    titleMedium: subHeadline4.copyWith(color: onSurface),
    titleSmall: subHeadline5.copyWith(color: onSurface),
    bodyLarge: bodyText1.copyWith(color: onSurface),
    bodyMedium: bodyText2.copyWith(color: onSurface),
    bodySmall: bodyText3.copyWith(color: onSurfaceVariant),
    labelLarge: subHeadline5.copyWith(color: onSurface),
    labelMedium: caption.copyWith(color: onSurfaceVariant),
    labelSmall: metadata.copyWith(color: onSurfaceVariant),
  );
}

/// Monetary figures: same family, but digits of equal width.
TextStyle numeric(TextStyle base) =>
    base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
