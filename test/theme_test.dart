import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/app_theme.dart';
import 'package:newtronic_banking/core/theme/theme_controller.dart';
import 'package:newtronic_banking/main.dart';
import 'package:newtronic_banking/presentation/screen/auth/authentication_screen.dart';
import 'package:newtronic_banking/presentation/widget/theme_toggle_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrast ratio between two opaque colours, per WCAG 2.1.
///
/// Returns a value from 1 (identical) to 21 (black on white). AA wants 4.5 for
/// body text and 3.0 for large text.
double _contrast(Color a, Color b) {
  double channel(double value) =>
      value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  final first = luminance(a);
  final second = luminance(b);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('ThemeController', () {
    test('defaults to following the system', () async {
      final controller = await ThemeController.load();
      expect(controller.mode, ThemeMode.system);
    });

    test('persists the chosen mode across a reload', () async {
      final controller = await ThemeController.load();
      await controller.setMode(ThemeMode.dark);

      final reloaded = await ThemeController.load();
      expect(reloaded.mode, ThemeMode.dark);
    });

    test('toggle flips to the opposite of the current brightness', () async {
      final controller = await ThemeController.load();

      await controller.toggle(Brightness.light);
      expect(controller.mode, ThemeMode.dark);

      await controller.toggle(Brightness.dark);
      expect(controller.mode, ThemeMode.light);
    });

    test('cycle walks system -> light -> dark -> system', () async {
      final controller = await ThemeController.load();

      await controller.cycle();
      expect(controller.mode, ThemeMode.light);
      await controller.cycle();
      expect(controller.mode, ThemeMode.dark);
      await controller.cycle();
      expect(controller.mode, ThemeMode.system);
    });

    test('notifies listeners only when the mode actually changes', () async {
      final controller = await ThemeController.load();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setMode(ThemeMode.dark);
      await controller.setMode(ThemeMode.dark);

      expect(notifications, 1);
    });
  });

  group('themes', () {
    test('both are Material 3 and carry the AppColors extension', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.useMaterial3, isTrue);
        expect(theme.extension<AppColors>(), isNotNull);
      }
    });

    test('brightness is set correctly on each', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('body text meets WCAG AA against its surface in both themes', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final ratio = _contrast(
          theme.colorScheme.onSurface,
          theme.colorScheme.surface,
        );
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'onSurface on surface in ${theme.brightness}');
      }
    });

    test('primary button labels meet WCAG AA in both themes', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final ratio = _contrast(
          theme.colorScheme.onPrimary,
          theme.colorScheme.primary,
        );
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'onPrimary on primary in ${theme.brightness}');
      }
    });

    test('header text meets WCAG AA in both themes', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = theme.extension<AppColors>()!;
        expect(_contrast(colors.onHeader, colors.headerBackground),
            greaterThanOrEqualTo(4.5),
            reason: 'onHeader on headerBackground in ${theme.brightness}');
      }
    });

    test('subtle text meets WCAG AA against the surface in both themes', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = theme.extension<AppColors>()!;
        expect(_contrast(colors.subtleText, theme.colorScheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'subtleText on surface in ${theme.brightness}');
      }
    });

    test('card text meets WCAG AA against every gradient stop', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = theme.extension<AppColors>()!;
        for (final stop in colors.cardGradient) {
          expect(_contrast(colors.onCard, stop), greaterThanOrEqualTo(4.5),
              reason: 'onCard on a card gradient stop in ${theme.brightness}');
        }
      }
    });

    test('card actions meet WCAG AA against the card action surface', () {
      // The MOVE/QRIS buttons paint `cardGradient.first` on an `onCard` fill.
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final colors = theme.extension<AppColors>()!;
        expect(_contrast(colors.cardGradient.first, colors.onCard),
            greaterThanOrEqualTo(4.5),
            reason: 'card action label in ${theme.brightness}');
      }
    });

    test('light and dark resolve to different surfaces', () {
      expect(
        AppTheme.light.colorScheme.surface,
        isNot(AppTheme.dark.colorScheme.surface),
      );
    });
  });

  group('theme switching', () {
    testWidgets('the toggle flips the app between light and dark',
        (tester) async {
      final controller = await ThemeController.load();
      await tester.pumpWidget(MyApp(themeController: controller));

      // Move past the splash delay onto the authentication screen.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(AuthenticationScreen), findsOneWidget);

      final context = tester.element(find.byType(AuthenticationScreen));
      expect(Theme.of(context).brightness, Brightness.light);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();

      final darkContext = tester.element(find.byType(AuthenticationScreen));
      expect(Theme.of(darkContext).brightness, Brightness.dark);
      expect(controller.mode, ThemeMode.dark);
    });

    testWidgets('the toggle stays out of the tree without a controller',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ThemeToggleButton()),
      ));

      expect(find.byType(IconButton), findsNothing);
    });
  });
}
