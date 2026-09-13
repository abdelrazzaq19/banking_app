import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';
import 'package:newtronic_banking/presentation/widget/app_button.dart';

/// A designed "nothing here yet" panel: illustration, explanation, and — where
/// there is something the user can do about it — an action.
///
/// Replaces bare centred Lottie files, which said only that the screen was
/// empty and never why or what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.animationAsset,
    this.icon,
    this.actionLabel,
    this.onActionPressed,
    this.compact = false,
  });

  final String title;
  final String message;

  /// Lottie file to play above the copy. Takes precedence over [icon].
  final String? animationAsset;

  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  /// Tighter spacing, for an empty state inside a section rather than a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final artSize = compact ? 96.0 : 176.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Insets.xxl,
          vertical: compact ? Insets.lg : Insets.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (animationAsset != null)
              LottieBuilder.asset(
                animationAsset!,
                width: artSize,
                height: artSize,
                fit: BoxFit.contain,
              )
            else if (icon != null)
              Container(
                width: artSize * 0.5,
                height: artSize * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.mutedFill,
                ),
                child: Icon(
                  icon,
                  size: artSize * 0.24,
                  color: colors.subtleText,
                ),
              ),
            SizedBox(height: compact ? Insets.sm : Insets.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.subtleText),
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: Insets.lg),
              AppButton(
                label: actionLabel!,
                onPressed: onActionPressed,
                expand: false,
                size: AppButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
