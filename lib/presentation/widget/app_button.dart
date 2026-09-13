import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';

/// How much weight a button carries on the screen.
enum AppButtonVariant {
  /// The one action the screen exists for. Filled with the brand gradient.
  primary,

  /// A supporting action. Outlined, transparent fill.
  secondary,

  /// Lowest weight: text only, no container.
  ghost,

  /// Sits on top of a balance card, where the background is the card gradient
  /// and the button itself has to be the light surface.
  onCard,
}

enum AppButtonSize {
  /// 52pt tall — the standard call to action.
  large,

  /// 48pt tall, still at the minimum comfortable tap target.
  medium,
}

/// The app's button.
///
/// Handles the four states a real button needs — idle, pressed, disabled and
/// loading — and guarantees a tap target of at least 48pt with a semantic label,
/// so every button in the app is reachable by a screen reader and by a thumb.
///
/// Passing `null` to [onPressed] disables it; that is also what makes the
/// disabled styling appear, so state and appearance cannot disagree.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
    this.width,
    this.semanticLabel,
    this.enableFeedback = true,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;

  /// Leading icon, shown before the label.
  final IconData? icon;

  /// Trailing icon, shown after the label.
  final IconData? trailingIcon;

  /// Replaces the label with a spinner and blocks presses. The button keeps its
  /// width so the layout does not jump when a request starts.
  final bool isLoading;

  /// Whether to fill the available width. Ignored when [width] is set.
  final bool expand;

  final double? width;

  /// Announced instead of [label] when the visible text is not descriptive on
  /// its own (an icon-led action, say).
  final String? semanticLabel;

  /// Fires a light haptic on press. No-op on platforms without haptics.
  final bool enableFeedback;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  double get _height => switch (widget.size) {
        AppButtonSize.large => 52,
        AppButtonSize.medium => 48,
      };

  void _setPressed(bool value) {
    if (!widget._isEnabled || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _handleTap() {
    if (!widget._isEnabled) return;
    if (widget.enableFeedback) HapticFeedback.lightImpact();
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final style = _resolveStyle(context);

    return Semantics(
      button: true,
      enabled: widget._isEnabled,
      label: widget.semanticLabel ?? widget.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _handleTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1,
            duration: Motion.instant,
            curve: Motion.move,
            child: AnimatedContainer(
              duration: Motion.fast,
              curve: Motion.move,
              width: widget.width ?? (widget.expand ? double.infinity : null),
              height: _height,
              decoration: BoxDecoration(
                borderRadius: Radii.pillAll,
                gradient: style.gradient,
                color: style.fill,
                border: style.border,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Insets.xl),
              child: _buildContent(style),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(_AppButtonStyle style) {
    final textStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(color: style.foreground);

    if (widget.isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(style.foreground),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: style.foreground),
          const SizedBox(width: Insets.xs),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: Insets.xs),
          Icon(widget.trailingIcon, size: 20, color: style.foreground),
        ],
      ],
    );
  }

  _AppButtonStyle _resolveStyle(BuildContext context) {
    final scheme = context.scheme;
    final colors = context.colors;

    if (!widget._isEnabled) {
      // One disabled treatment for every variant, so a dead button is never
      // mistaken for a live one of a different weight.
      return _AppButtonStyle(
        fill: widget.variant == AppButtonVariant.ghost
            ? Colors.transparent
            : colors.mutedFill,
        foreground: colors.subtleText,
        border: widget.variant == AppButtonVariant.secondary
            ? Border.all(color: colors.mutedBorder)
            : null,
      );
    }

    return switch (widget.variant) {
      AppButtonVariant.primary => _AppButtonStyle(
          gradient: LinearGradient(
            colors: [scheme.primary, colors.accent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          foreground: scheme.onPrimary,
        ),
      AppButtonVariant.secondary => _AppButtonStyle(
          fill: Colors.transparent,
          foreground: scheme.primary,
          border: Border.all(color: scheme.primary, width: 1.5),
        ),
      AppButtonVariant.ghost => _AppButtonStyle(
          fill: Colors.transparent,
          foreground: colors.accent,
        ),
      AppButtonVariant.onCard => _AppButtonStyle(
          fill: colors.onCard,
          // The darkest card tone rather than `primary`, which in dark mode is
          // a light blue that would all but vanish on this white fill.
          foreground: colors.cardGradient.first,
        ),
    };
  }
}

class _AppButtonStyle {
  const _AppButtonStyle({
    required this.foreground,
    this.fill,
    this.gradient,
    this.border,
  });

  final Color foreground;
  final Color? fill;
  final Gradient? gradient;
  final BoxBorder? border;
}
