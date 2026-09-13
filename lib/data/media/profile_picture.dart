import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Why a chosen picture could not be used.
enum PictureFailure {
  cancelled,
  tooLarge,
  notAnImage,
  failed;

  String get message => switch (this) {
        cancelled => 'No picture chosen.',
        tooLarge =>
          'That file is larger than ${ProfilePicture.maxSourceBytes ~/ (1024 * 1024)}MB. '
              'Pick a smaller one.',
        notAnImage => 'That file is not an image we can read.',
        failed => 'The picture could not be prepared.',
      };
}

/// A profile picture, prepared for storage.
///
/// Pictures are kept as a `data:` URI rather than a file path. A path is
/// meaningless on the web, and on desktop it would point at a file the user is
/// free to move or delete, leaving a broken avatar with no way to explain it.
/// The image travels with the record instead.
///
/// Every picture is cropped square and scaled to [size] first. A phone camera
/// photo is several megabytes; storing one verbatim would put a multi-megabyte
/// base64 string into `shared_preferences`, which is read whole on launch.
abstract final class ProfilePicture {
  /// The stored edge length, in pixels.
  ///
  /// Large enough for the 84pt profile avatar on a 3x screen without being
  /// sharp enough to be worth the bytes anywhere else.
  static const int size = 256;

  /// The largest file worth decoding.
  ///
  /// Decoding happens on the UI isolate, and on the web there is no isolate to
  /// move it to, so an enormous file is refused rather than freezing the app
  /// while it is resized.
  static const int maxSourceBytes = 12 * 1024 * 1024;

  static const String _prefix = 'data:image/png;base64,';

  /// Whether [value] is a picture this app stored, rather than a remote URL.
  static bool isStored(String value) => value.startsWith('data:image/');

  /// The bytes behind a stored picture, or null if [value] is not one.
  ///
  /// Returns null rather than throwing on a malformed payload: a corrupt
  /// stored value should fall back to the placeholder avatar, not take the
  /// profile screen down with it.
  static Uint8List? decode(String value) {
    if (!isStored(value)) return null;

    final comma = value.indexOf(',');
    if (comma < 0) return null;

    try {
      return base64Decode(value.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  /// Crops [raw] to a centred square, scales it to [size], and encodes it.
  ///
  /// Centre-cropping rather than squashing: a portrait photo squashed to a
  /// square makes a face look wrong in a way a crop does not.
  static Future<(String?, PictureFailure?)> prepare(Uint8List raw) async {
    if (raw.length > maxSourceBytes) return (null, PictureFailure.tooLarge);

    ui.Image source;
    try {
      source = await decodeImageFromList(raw);
    } catch (error, stackTrace) {
      debugPrint('ProfilePicture: could not decode the chosen file: $error');
      debugPrintStack(stackTrace: stackTrace);
      return (null, PictureFailure.notAnImage);
    }

    try {
      final square = await _squareCrop(source);
      final data = await square.toByteData(format: ui.ImageByteFormat.png);
      square.dispose();
      if (data == null) return (null, PictureFailure.failed);

      return ('$_prefix${base64Encode(data.buffer.asUint8List())}', null);
    } catch (error, stackTrace) {
      debugPrint('ProfilePicture: could not prepare the picture: $error');
      debugPrintStack(stackTrace: stackTrace);
      return (null, PictureFailure.failed);
    } finally {
      source.dispose();
    }
  }

  /// Draws the middle square of [source] into a [size] by [size] image.
  static Future<ui.Image> _squareCrop(ui.Image source) async {
    final edge = source.width < source.height ? source.width : source.height;
    final left = (source.width - edge) / 2;
    final top = (source.height - edge) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(left, top, edge.toDouble(), edge.toDouble()),
      const Rect.fromLTWH(0, 0, size * 1.0, size * 1.0),
      Paint()..filterQuality = FilterQuality.medium,
    );

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(size, size);
    } finally {
      picture.dispose();
    }
  }
}
