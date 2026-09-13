import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/app_colors.dart';
import 'package:newtronic_banking/core/theme/motion.dart';

/// Progress dots for a [PageView], where the active dot stretches into a pill.
///
/// Driven by the controller's continuous page offset rather than a whole-number
/// index, so the indicator moves *with* the page instead of snapping after it.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.controller,
    required this.count,
    this.fallbackIndex = 0,
    this.onDotTapped,
  });

  final PageController controller;
  final int count;

  /// Used before the controller has been attached to a viewport and can report
  /// a page — on the very first frame.
  final int fallbackIndex;

  /// When given, dots become buttons that jump to their page.
  final ValueChanged<int>? onDotTapped;

  double _currentPage() {
    if (!controller.hasClients) return fallbackIndex.toDouble();
    if (!controller.position.hasContentDimensions) {
      return controller.initialPage.toDouble();
    }
    return controller.page ?? controller.initialPage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = _currentPage();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < count; index++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: onDotTapped != null,
                  selected: index == page.round(),
                  label: 'Step ${index + 1} of $count',
                  child: GestureDetector(
                    onTap: onDotTapped == null
                        ? null
                        : () => onDotTapped!(index),
                    // A 10pt dot is far too small to hit; the padding above plus
                    // this box give it a real target without changing the look.
                    child: SizedBox(
                      height: 32,
                      child: Center(
                        child: AnimatedContainer(
                          duration: Motion.fast,
                          curve: Motion.move,
                          width: _widthFor(index, page),
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Color.lerp(
                              colors.mutedBorder,
                              context.scheme.primary,
                              _proximity(index, page),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 1 when the page is exactly on [index], falling to 0 one page away.
  double _proximity(int index, double page) =>
      (1 - (page - index).abs()).clamp(0.0, 1.0);

  double _widthFor(int index, double page) =>
      8 + 22 * _proximity(index, page);
}
