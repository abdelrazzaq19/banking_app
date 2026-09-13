import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Turns a piece of the live screen into a PNG.
///
/// Shared rather than living on the receipt exporter: the payment-code screen
/// shares an image of a QR the same way, and reaching into receipt code to do
/// it would tie the two features together for no reason.
abstract final class WidgetCapture {
  /// Rasterises whatever [boundaryKey] wraps.
  ///
  /// Returns null when the boundary is not on screen — capturing something
  /// that was never laid out would produce a blank image rather than an error,
  /// which is worse than saying nothing happened.
  ///
  /// Under `flutter_test` this must be driven inside `tester.runAsync`: the
  /// image future is completed by the engine, not by the test's fake clock, so
  /// awaiting it on the fake clock hangs forever.
  static Future<Uint8List?> png(
    GlobalKey boundaryKey, {
    double pixelRatio = 3,
  }) async {
    final object = boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    try {
      final image = await object.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (error, stackTrace) {
      debugPrint('WidgetCapture: could not rasterise the boundary: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
