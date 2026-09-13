import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

/// Reads the bytes of a picture the user chose, or null if they chose none.
typedef PickImageBytes = Future<Uint8List?> Function();

/// Opens the platform's own file chooser.
///
/// `file_selector` rather than `image_picker`: this app is verified on Chrome
/// and Windows, where there is no camera roll to offer and `file_selector` is
/// the package with first-party support on both.
Future<Uint8List?> pickImageFromFiles() async {
  const images = XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
    // Needed separately on the web and on macOS, which filter by type rather
    // than by extension.
    mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/bmp',
      'image/webp'],
    uniformTypeIdentifiers: ['public.image'],
  );

  final file = await openFile(acceptedTypeGroups: [images]);
  if (file == null) return null;

  return file.readAsBytes();
}
