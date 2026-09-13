import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/styles/typography.dart';

/// Builds the app's light and dark themes.
///
/// Both are seeded from the same brand blue so tonal roles stay related, then
/// the roles that carry the brand are pinned so the identity survives Material's
/// tonal derivation.
abstract final class AppTheme {
  static ThemeData get light => _build(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Brand.deep,
          brightness: Brightness.light,
        ).copyWith(
          primary: Brand.deep,
          onPrimary: Colors.white,
          secondary: Brand.mid,
          onSecondary: Colors.white,
          tertiary: Brand.light,
          surface: const Color(0xFFFFFFFF),
          onSurface: const Color(0xFF10151D),
          onSurfaceVariant: const Color(0xFF5B6472),
          surfaceContainerHighest: const Color(0xFFF1F4F8),
          // A real border tone, not the divider grey. This one outlines
          // text fields, where WCAG treats the boundary as what identifies
          // the control and asks for 3:1; the old value measured 1.35:1.
          outline: const Color(0xFF7E8A9B),
          outlineVariant: const Color(0xFFE6EBF1),
        ),
        appColors: AppColors.light,
        scaffoldBackground: const Color(0xFFF7F9FC),
      );

  static ThemeData get dark => _build(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Brand.deep,
          brightness: Brightness.dark,
        ).copyWith(
          primary: Brand.light,
          onPrimary: const Color(0xFF06264A),
          secondary: Brand.mid,
          onSecondary: Colors.white,
          tertiary: Brand.light,
          surface: const Color(0xFF121822),
          onSurface: const Color(0xFFE7ECF3),
          onSurfaceVariant: const Color(0xFF9AA6B8),
          surfaceContainerHighest: const Color(0xFF1B2331),
          outline: const Color(0xFF5E6E85),
          outlineVariant: const Color(0xFF232C3A),
        ),
        appColors: AppColors.dark,
        scaffoldBackground: const Color(0xFF0C1119),
      );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required AppColors appColors,
    required Color scaffoldBackground,
  }) {
    final textTheme = buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[appColors],
      splashFactory: InkSparkle.splashFactory,
      // One transition on every platform: the app's own fade-forward, so route
      // changes feel identical on web, desktop and mobile.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      dividerTheme: DividerThemeData(
        color: appColors.mutedBorder,
        thickness: 1,
        space: Insets.md,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.xl,
            vertical: Insets.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: Radii.pillAll),
          textStyle: textTheme.titleMedium,
          animationDuration: Motion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: appColors.accent,
          textStyle: textTheme.titleSmall,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appColors.mutedFill,
        hintStyle: textTheme.bodyMedium?.copyWith(color: appColors.subtleText),
        labelStyle: textTheme.bodyMedium?.copyWith(color: appColors.subtleText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        // `outline`, not the divider grey: a field's edge is the only thing
        // saying where the field is, so it has to be visible. Dividers keep
        // the lighter `mutedBorder` — a hairline between rows is decorative
        // and WCAG does not hold it to a ratio.
        border: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.pillAll,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: colorScheme.error),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: appColors.subtleText,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.bodyMedium,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: Radii.mdAll),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        elevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetTop),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: appColors.subtleText,
        ),
        shape: RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: Radii.smAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
    );
  }
}
