import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/core/theme/tokens.dart';

/// A frosted, gradient surface — the balance card and anything that should read
/// as the same material.
///
/// The depth comes from four stacked layers rather than a drop shadow:
///   1. an optional backdrop blur, so whatever sits behind shows through softly
///   2. the brand gradient
///   3. a diagonal sheen, which is what makes it read as glass rather than paint
///   4. a hairline border catching the "light" along the top-left edge
///
/// [onTap] is optional; when given, the whole card becomes a button with a
/// press response and a semantic label.
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(Insets.md),
    this.gradient,
    this.borderRadius,
    this.frosted = false,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  /// Defaults to the theme's card gradient.
  final List<Color>? gradient;

  final BorderRadius? borderRadius;

  /// Blur what is behind the card. Only worth enabling when the card actually
  /// overlaps other content — over a flat background it costs a raster pass and
  /// changes nothing.
  final bool frosted;

  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = widget.borderRadius ?? Radii.mdAll;
    final gradientColors = widget.gradient ?? colors.cardGradient;

    Widget card = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (widget.frosted)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: Glass.blur,
                  sigmaY: Glass.blur,
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              // The sheen: brightest at the top-left corner, gone by the middle.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.glassTint,
                  colors.glassTint.withValues(alpha: Glass.sheenOpacity),
                  Colors.transparent,
                ],
                stops: const [0, 0.35, 0.75],
              ),
              border: Border.all(
                color: colors.glassBorder.withValues(
                  alpha: Glass.borderOpacity,
                ),
              ),
            ),
            padding: widget.padding,
            child: widget.child,
          ),
        ],
      ),
    );

    if (widget.onTap == null) {
      return Semantics(
        label: widget.semanticLabel,
        container: widget.semanticLabel != null,
        child: card,
      );
    }

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1,
          duration: Motion.instant,
          curve: Motion.move,
          child: card,
        ),
      ),
    );
  }
}
