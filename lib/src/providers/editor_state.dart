import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'image_processing.dart';

/// Formatos de imagen soportados para la salida
enum ImageOutputFormat {
  png,
  jpg,
  webp,
  gif,
}

class EditorPoint {
  final double x;
  final double y;

  const EditorPoint(this.x, this.y);
}

/// Configuración de la salida de imagen
class ImageOutputConfig {
  final ImageOutputFormat format;
  final int quality;
  final bool preserveTransparency;

  const ImageOutputConfig({
    this.format = ImageOutputFormat.png,
    this.quality = 90,
    this.preserveTransparency = true,
  });

  /// Codifica la imagen al formato especificado
  Uint8List encodeImage(img.Image image) {
    switch (format) {
      case ImageOutputFormat.png:
        return Uint8List.fromList(img.encodePng(image));
      case ImageOutputFormat.jpg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ImageOutputFormat.webp:
        return Uint8List.fromList(
            img.encodeJpg(image, quality: quality)); // Fallback a JPG
      case ImageOutputFormat.gif:
        return Uint8List.fromList(img.encodeGif(image));
    }
  }
}

/// Estado del editor de imágenes
class EditorState {
  final img.Image? originalImage;
  final img.Image? currentImage;
  final List<img.Image> history;
  final int currentHistoryIndex;
  final bool hasChanges;
  final ImageOutputConfig outputConfig;
  final double brushSize;
  final bool isErasing;
  final bool isBatchProcessing;

  EditorState({
    this.originalImage,
    this.currentImage,
    this.history = const [],
    this.currentHistoryIndex = -1,
    this.hasChanges = false,
    this.outputConfig = const ImageOutputConfig(),
    this.brushSize = 30.0,
    this.isErasing = true,
    this.isBatchProcessing = false,
  });

  EditorState copyWith({
    img.Image? originalImage,
    img.Image? currentImage,
    List<img.Image>? history,
    int? currentHistoryIndex,
    bool? hasChanges,
    ImageOutputConfig? outputConfig,
    double? brushSize,
    bool? isErasing,
    bool? isBatchProcessing,
  }) {
    return EditorState(
      originalImage: originalImage ?? this.originalImage,
      currentImage: currentImage ?? this.currentImage,
      history: history ?? this.history,
      currentHistoryIndex: currentHistoryIndex ?? this.currentHistoryIndex,
      hasChanges: hasChanges ?? this.hasChanges,
      outputConfig: outputConfig ?? this.outputConfig,
      brushSize: brushSize ?? this.brushSize,
      isErasing: isErasing ?? this.isErasing,
      isBatchProcessing: isBatchProcessing ?? this.isBatchProcessing,
    );
  }
}

/// Notificador para el estado del editor
class EditorStateNotifier extends StateNotifier<EditorState> {
  EditorStateNotifier() : super(EditorState());

  /// Inicializa el editor con una imagen
  void initialize(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return;

    final resized = ImageProcessor.resizeIfNeeded(decoded);
    state = EditorState(
      originalImage: resized,
      currentImage: ImageProcessor.safeCopy(resized),
      history: [ImageProcessor.safeCopy(resized)],
      currentHistoryIndex: 0,
      hasChanges: false,
    );
  }

  /// Procesa una región de la imagen
  Future<void> processRegion(EditorPoint point) async {
    if (state.originalImage == null || state.currentImage == null) return;

    final x = (point.x * state.currentImage!.width).round();
    final y = (point.y * state.currentImage!.height).round();
    final radius = (state.brushSize * 0.5).round();

    img.Image workingImage;
    if (!state.isBatchProcessing) {
      workingImage = ImageProcessor.safeCopy(state.currentImage!);
      state = state.copyWith(
        currentImage: workingImage,
        isBatchProcessing: true,
      );
    } else {
      workingImage = state.currentImage!;
    }

    ImageProcessor.processRegion(
      workingImage,
      state.originalImage,
      x,
      y,
      radius,
      1.0,
      erase: state.isErasing,
    );

    if (!state.isBatchProcessing) {
      _addToHistory(workingImage);
    }
  }

  /// Finaliza el procesamiento por lotes
  void endBatchProcessing() {
    if (state.isBatchProcessing && state.currentImage != null) {
      _addToHistory(state.currentImage!);
      state = state.copyWith(isBatchProcessing: false);
    }
  }

  void updateBrushSize(double size) {
    state = state.copyWith(brushSize: size);
  }

  void toggleEraseMode() {
    state = state.copyWith(isErasing: !state.isErasing);
  }

  void updateOutputConfig(ImageOutputConfig config) {
    state = state.copyWith(outputConfig: config);
  }

  void _addToHistory(img.Image image) {
    final newHistory = [
      ...state.history.sublist(0, state.currentHistoryIndex + 1),
      ImageProcessor.safeCopy(image),
    ];

    if (newHistory.length > 20) {
      newHistory.removeAt(0);
    }

    state = state.copyWith(
      currentImage: image,
      history: newHistory,
      currentHistoryIndex: newHistory.length - 1,
      hasChanges: true,
    );
  }

  void undo() {
    if (state.currentHistoryIndex > 0) {
      state = state.copyWith(
        currentHistoryIndex: state.currentHistoryIndex - 1,
        currentImage: ImageProcessor.safeCopy(
            state.history[state.currentHistoryIndex - 1]),
      );
    }
  }

  void redo() {
    if (state.currentHistoryIndex < state.history.length - 1) {
      state = state.copyWith(
        currentHistoryIndex: state.currentHistoryIndex + 1,
        currentImage: ImageProcessor.safeCopy(
            state.history[state.currentHistoryIndex + 1]),
      );
    }
  }

  /// Obtiene la imagen actual en el formato configurado
  Uint8List? getCurrentImage() {
    if (state.currentImage == null) return null;
    return state.outputConfig.encodeImage(state.currentImage!);
  }
}

/// Provider global para el estado del editor
final editorProvider = StateNotifierProvider<EditorStateNotifier, EditorState>(
  (ref) => EditorStateNotifier(),
);
