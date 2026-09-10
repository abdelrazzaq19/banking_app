import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';

export 'package:newtronic_banking/core/theme/app_colors.dart' show Brand;

// Legacy palette.
//
// These are fixed light-mode values and therefore cannot adapt to dark mode.
// They remain only so screens can be migrated one at a time; new code should
// read `context.scheme` / `context.colors` instead. Each is annotated with the
// semantic token that replaces it.

/// Replaced by `context.scheme.primary`.
const Color primary100 = Brand.deep;

/// Replaced by `context.colors.accent`.
const Color primary90 = Color(0xFF63B4FD);

/// Replaced by `context.colors.headerBackground`.
const Color primary80 = Brand.light;

/// Replaced by `context.colors.mutedBorder`.
const Color secondary20 = Color(0xFFC8C8C8);

/// Replaced by `context.colors.mutedFill`.
const Color secondary10 = Color(0xFFD1D1D1);

/// Replaced by `context.scheme.surface` or `context.colors.onCard`.
const Color secondary0 = Color(0xFFFFFFFF);

/// Replaced by `context.scheme.onSurface`.
const Color text = Color(0xFF000000);
