import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/theme_controller.dart';
import 'package:provider/provider.dart';

/// Switches the app between light and dark, and says which is active.
///
/// The icon cross-fades and rotates rather than snapping, so the change reads
/// as one continuous action along with the theme's own colour lerp.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key, this.foregroundColor});

  /// Overrides the icon colour on brand-coloured backgrounds, where
  /// `onSurface` would have too little contrast.
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    // Nullable lookup: the control has nothing to drive without a controller
    // (a widget test pumping a bare screen, for instance), so it stays out of
    // the tree rather than throwing.
    final controller = context.watch<ThemeController?>();
    if (controller == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = foregroundColor ?? context.scheme.onSurface;

    return Semantics(
      button: true,
      label: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      child: IconButton(
        tooltip: isDark ? 'Light theme' : 'Dark theme',
        onPressed: () => controller.toggle(Theme.of(context).brightness),
        icon: AnimatedSwitcher(
          duration: Motion.fast,
          switchInCurve: Motion.enter,
          switchOutCurve: Motion.exit,
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey<bool>(isDark),
            color: tint,
          ),
        ),
      ),
    );
  }
}
