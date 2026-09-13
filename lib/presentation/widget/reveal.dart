import 'package:flutter/widgets.dart';
import 'package:newtronic_banking/core/theme/motion.dart';

/// Fades and lifts [child] into place, offset by its position in a group.
///
/// One entrance animation used everywhere, so lists, cards and headers all
/// arrive with the same character instead of each screen inventing its own.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 16,
    this.enabled = true,
  });

  final Widget child;

  /// Position in the group; each step delays the animation by [Motion.stagger].
  final int index;

  /// How far the child travels upward as it fades in.
  final double offset;

  /// Set false to render the child immediately — used by tests and by callers
  /// that rebuild often enough that a re-entrance would read as a flicker.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.medium + Motion.stagger * index,
      curve: Motion.enter,
      builder: (context, value, child) {
        final progress = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * offset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Wraps each of [children] in a [Reveal] whose delay grows with its position.
///
/// Saves callers from threading an index through by hand:
///
/// ```dart
/// Column(children: staggeredReveal([header, cards, activity]))
/// ```
List<Widget> staggeredReveal(
  List<Widget> children, {
  double offset = 16,
  int startIndex = 0,
  bool enabled = true,
}) {
  return <Widget>[
    for (var i = 0; i < children.length; i++)
      Reveal(
        index: startIndex + i,
        offset: offset,
        enabled: enabled,
        child: children[i],
      ),
  ];
}
