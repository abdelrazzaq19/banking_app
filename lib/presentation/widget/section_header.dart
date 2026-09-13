import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';

/// A titled divider between sections of a screen, with an optional action.
///
/// Marked as a heading for assistive tech, so a screen reader can jump between
/// sections instead of reading a wall of list items.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionPressed,
    this.padding = const EdgeInsets.only(
      left: Insets.lg,
      right: Insets.lg,
      top: Insets.xl,
      bottom: Insets.xs,
    ),
  });

  final String title;

  /// Text of the trailing action. Ignored when [onActionPressed] is null.
  final String? actionLabel;

  final VoidCallback? onActionPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final showAction = actionLabel != null && onActionPressed != null;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (showAction)
            TextButton(
              onPressed: onActionPressed,
              child: Text(
                actionLabel!,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: context.colors.accent),
              ),
            ),
        ],
      ),
    );
  }
}
