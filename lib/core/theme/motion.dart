import 'package:flutter/animation.dart';

/// The app's motion language.
///
/// Durations and curves live here so every transition feels like it belongs to
/// the same product, and so timings can be tuned in one place.
abstract final class Motion {
  /// State flips that should feel instant: ripples, colour changes, toggles.
  static const Duration instant = Duration(milliseconds: 120);

  /// The default for most UI reactions.
  static const Duration fast = Duration(milliseconds: 220);

  /// Page and sheet transitions.
  static const Duration medium = Duration(milliseconds: 360);

  /// Deliberate, attention-drawing moves: hero flights, success reveals.
  static const Duration slow = Duration(milliseconds: 560);

  /// Delay between siblings in a staggered list reveal.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Decelerating curve for things entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Accelerating curve for things leaving it.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric curve for things moving within the screen.
  static const Curve move = Curves.easeInOutCubic;

  /// Slight overshoot, for elements that should feel physical.
  static const Curve spring = Curves.easeOutBack;
}
