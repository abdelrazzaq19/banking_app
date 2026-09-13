import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/app_theme.dart';

/// WCAG relative luminance.
double _luminance(Color color) {
  double channel(double value) =>
      value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4)
          as double;

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colours, 1 to 21.
double contrastRatio(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

/// AA for body text.
const double _bodyMinimum = 4.5;

/// AA for large text and for the boundary of a user-interface component.
const double _largeMinimum = 3.0;

void _expectContrast(
  String what,
  Color foreground,
  Color background, {
  double minimum = _bodyMinimum,
}) {
  final ratio = contrastRatio(foreground, background);
  expect(
    ratio,
    greaterThanOrEqualTo(minimum),
    reason: '$what measures ${ratio.toStringAsFixed(2)}:1, '
        'under the ${minimum.toStringAsFixed(1)}:1 WCAG AA needs',
  );
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group('$name theme meets WCAG AA', () {
      final scheme = theme.colorScheme;
      final colors = theme.extension<AppColors>()!;

      test('body text on every surface it sits on', () {
        _expectContrast('onSurface on surface', scheme.onSurface,
            scheme.surface);
        _expectContrast('onSurface on the muted fill', scheme.onSurface,
            colors.mutedFill);
        _expectContrast('onSurfaceVariant on surface', scheme.onSurfaceVariant,
            scheme.surface);
        _expectContrast('onSurface on the sheet', scheme.onSurface,
            colors.sheetBackground);
      });

      test('the subdued text that carries dates and captions', () {
        // Secondary text is still text, so it is held to the body ratio
        // rather than the large-text one.
        _expectContrast('subtleText on surface', colors.subtleText,
            scheme.surface);
        _expectContrast('subtleText on the muted fill', colors.subtleText,
            colors.mutedFill);
      });

      test('text on the brand surfaces', () {
        _expectContrast('onHeader on the header', colors.onHeader,
            colors.headerBackground);
        for (final (index, stop) in colors.cardGradient.indexed) {
          _expectContrast('onCard on gradient stop $index', colors.onCard,
              stop);
        }
      });

      test('text on the filled controls', () {
        _expectContrast('onPrimary on primary', scheme.onPrimary,
            scheme.primary);
        // `secondary` is deliberately not checked: nothing in the app
        // fills a surface with it. The secondary *button* is an outline,
        // drawing its label in `primary` on the page's own background, so
        // that is the pair that actually ships.
        _expectContrast('a secondary button label on surface', scheme.primary,
            scheme.surface);
        _expectContrast('onError on error', scheme.onError, scheme.error);
        _expectContrast('onErrorContainer on the error container',
            scheme.onErrorContainer, scheme.errorContainer);
        _expectContrast('onPrimaryContainer on the primary container',
            scheme.onPrimaryContainer, scheme.primaryContainer);
      });

      test('the status colours used for money in and money out', () {
        _expectContrast('success on surface', colors.success, scheme.surface);
        _expectContrast('warning on surface', colors.warning, scheme.surface);
        _expectContrast('accent on surface', colors.accent, scheme.surface);
      });

      test('the edge of a control is visible', () {
        // WCAG 1.4.11 asks 3:1 of the visual information needed to identify a
        // control. A text field's outline is exactly that — without it there
        // is nothing saying where the field is.
        _expectContrast('a field outline against the surface', scheme.outline,
            scheme.surface, minimum: _largeMinimum);
        _expectContrast('a field outline against the muted fill',
            scheme.outline, colors.mutedFill, minimum: _largeMinimum);

        // `mutedBorder` is deliberately exempt. It draws hairline dividers
        // between rows, which are decorative: removing them entirely would
        // lose no information, so holding them to a ratio would only make the
        // app louder.
      });

      test('chart series stay distinguishable from their ground', () {
        for (final (index, series) in colors.chartPalette.indexed) {
          _expectContrast('chart series $index on surface', series,
              scheme.surface,
              minimum: _largeMinimum);
        }
      });
    });
  }

  group('the ratio maths itself', () {
    test('black on white is the maximum', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
    });

    test('a colour against itself is the minimum', () {
      expect(
        contrastRatio(const Color(0xFF3366AA), const Color(0xFF3366AA)),
        closeTo(1, 0.01),
      );
    });

    test('order does not matter', () {
      const a = Color(0xFF1A2B3C);
      const b = Color(0xFFEEDDCC);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 0.0001));
    });
  });
}
