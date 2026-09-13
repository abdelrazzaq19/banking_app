import 'package:flutter/material.dart';
import 'package:newtronic_banking/core/theme/motion.dart';
import 'package:newtronic_banking/data/utils/formatted.dart';
import 'package:newtronic_banking/styles/typography.dart';

/// A rupiah figure that counts up to its value instead of appearing at it.
///
/// Re-animates from wherever it was to wherever it is going, so a balance that
/// changes after a transfer visibly moves rather than silently swapping.
/// Tabular figures keep the digits from jittering as they roll.
class AnimatedBalance extends StatelessWidget {
  const AnimatedBalance({
    super.key,
    required this.amount,
    this.style,
    this.duration = Motion.slow,
    this.prefix = 'Rp ',
  });

  /// Whole rupiah.
  final int amount;

  final TextStyle? style;
  final Duration duration;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? Theme.of(context).textTheme.headlineSmall!;

    return Semantics(
      // The settled figure, so a screen reader announces the balance once
      // rather than reading every intermediate frame.
      label: '$prefix${formatRupiah(amount)}',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: amount.toDouble()),
          duration: duration,
          curve: Motion.enter,
          builder: (context, value, _) => Text(
            '$prefix${formatRupiah(value.round())}',
            style: numeric(baseStyle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
