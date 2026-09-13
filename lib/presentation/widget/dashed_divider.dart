import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';

/// A horizontal dashed rule.
///
/// Used on the receipt, where a perforated line is the visual shorthand for
/// "this part is the stub" — a solid divider reads as a plain list separator.
class DashedDivider extends StatelessWidget {
  const DashedDivider({
    super.key,
    this.height = 1,
    this.dashWidth = 5,
    this.dashGap = 4,
    this.color,
  });

  final double height;
  final double dashWidth;
  final double dashGap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color ?? context.colors.mutedBorder,
          dashWidth: dashWidth,
          dashGap: dashGap,
          thickness: height,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashGap,
    required this.thickness,
  });

  final Color color;
  final double dashWidth;
  final double dashGap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final step = dashWidth + dashGap;
    if (step <= 0) return;

    for (var x = 0.0; x < size.width; x += step) {
      final end = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(end, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.dashGap != dashGap ||
      oldDelegate.thickness != thickness;
}
