import 'dart:async';
import 'dart:typed_data';

export 'src/image_editor.dart';
export 'src/image_editor_widget.dart';
import 'src/background_remover_platform.dart';

/// Remove the background from an image
Future<dynamic> removeBackground({required Uint8List imageBytes}) async {
  return await BackgroundRemover.removeBackground(
    imageBytes: imageBytes,
  );
}
