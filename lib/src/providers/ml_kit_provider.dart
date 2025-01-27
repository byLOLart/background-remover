import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// Proveedor para manejar las operaciones de ML Kit de manera controlada
class MLKitProvider {
  static final MLKitProvider _instance = MLKitProvider._internal();
  factory MLKitProvider() => _instance;
  MLKitProvider._internal();

  // Banderas para controlar el uso de servicios
  bool _textRecognitionEnabled = false;
  bool _objectDetectionEnabled = false;

  // Instancias de reconocedores
  TextRecognizer? _textRecognizer;
  ObjectDetector? _objectDetector;

  /// Habilita o deshabilita el reconocimiento de texto
  void setTextRecognitionEnabled(bool enabled) {
    _textRecognitionEnabled = enabled;
    if (!enabled && _textRecognizer != null) {
      _textRecognizer!.close();
      _textRecognizer = null;
    }
  }

  /// Habilita o deshabilita la detección de objetos
  void setObjectDetectionEnabled(bool enabled) {
    _objectDetectionEnabled = enabled;
    if (!enabled && _objectDetector != null) {
      _objectDetector!.close();
      _objectDetector = null;
    }
  }

  /// Realiza el reconocimiento de texto de manera controlada
  Future<String> recognizeText(Uint8List imageBytes) async {
    if (!_textRecognitionEnabled) {
      return '';
    }

    try {
      _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(1024, 1024),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: 1024 * 4,
        ),
      );

      final result = await _textRecognizer!.processImage(inputImage);
      return result.text;
    } catch (e) {
      debugPrint('Error en reconocimiento de texto: $e');
      return '';
    }
  }

  /// Realiza la detección de objetos de manera controlada
  Future<List<DetectedObject>> detectObjects(Uint8List imageBytes) async {
    if (!_objectDetectionEnabled) {
      return [];
    }

    try {
      _objectDetector ??= ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );

      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: InputImageMetadata(
          size: const Size(1024, 1024),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: 1024 * 4,
        ),
      );

      return await _objectDetector!.processImage(inputImage);
    } catch (e) {
      debugPrint('Error en detección de objetos: $e');
      return [];
    }
  }

  /// Libera recursos
  void dispose() {
    _textRecognizer?.close();
    _objectDetector?.close();
    _textRecognizer = null;
    _objectDetector = null;
  }
}
