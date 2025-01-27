import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImageEditor {
  final List<img.Image> _history = [];
  int _currentHistoryIndex = -1;
  img.Image? _originalImage;
  img.Image? _currentImage;
  bool _hasChanges = false;
  int _batchOperations = 0;
  Uint8List? _cachedPng;

  ImageEditor();

  Future<void> initialize(Uint8List imageBytes) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return;

    _originalImage = decoded;
    _currentImage = img.copyResize(
      decoded,
      width: decoded.width,
      height: decoded.height,
    );

    _addToHistory(_currentImage!);
    _cachedPng = imageBytes;
  }

  bool get hasChanges => _hasChanges;

  Future<Uint8List?> restoreRegion(Offset point, double brushSize) async {
    return _processRegion(point, brushSize, true);
  }

  Future<Uint8List?> eraseRegion(Offset point, double brushSize) async {
    return _processRegion(point, brushSize, false);
  }

  Future<Uint8List?> _processRegion(
      Offset point, double brushSize, bool isRestore) async {
    if (_originalImage == null || _currentImage == null) return null;

    final x = (point.dx * _currentImage!.width).round();
    final y = (point.dy * _currentImage!.height).round();
    final radius = (brushSize * 0.5).round();

    if (_batchOperations == 0) {
      _currentImage = img.Image.from(_currentImage!);
    }
    _batchOperations++;

    final startX = math.max(0, x - radius);
    final startY = math.max(0, y - radius);
    final endX = math.min(_currentImage!.width, x + radius + 1);
    final endY = math.min(_currentImage!.height, y + radius + 1);

    for (var i = startX; i < endX; i++) {
      for (var j = startY; j < endY; j++) {
        final deltaX = i - x;
        final deltaY = j - y;
        final distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);
        if (distance > radius) continue;

        final intensity = (1.0 - (distance / radius)).clamp(0.0, 1.0);
        final current = _currentImage!.getPixel(i, j);

        if (isRestore) {
          // Restaurar desde la imagen original
          final original = _originalImage!.getPixel(i, j);
          final blendedPixel = _blendToOriginal(current, original, intensity);
          _currentImage!.setPixel(i, j, blendedPixel);
        } else {
          // Borrar a transparente
          final transparent = img.ColorFloat64.rgba(0, 0, 0, 0);
          final blendedPixel = _blendToTransparent(current, intensity);
          _currentImage!.setPixel(i, j, blendedPixel);
        }
      }
    }

    _batchOperations--;

    if (_batchOperations == 0) {
      _hasChanges = true;
      _addToHistory(_currentImage!);
      _cachedPng = Uint8List.fromList(img.encodePng(_currentImage!));
      return _cachedPng;
    }

    return null;
  }

  img.Color _blendToOriginal(
      img.Color current, img.Color original, double intensity) {
    return img.ColorFloat64.rgba(
      _blend(current.r.toDouble(), original.r.toDouble(), intensity) / 255,
      _blend(current.g.toDouble(), original.g.toDouble(), intensity) / 255,
      _blend(current.b.toDouble(), original.b.toDouble(), intensity) / 255,
      _blend(current.a.toDouble(), original.a.toDouble(), intensity) / 255,
    );
  }

  img.Color _blendToTransparent(img.Color current, double intensity) {
    final alpha = current.a.toDouble() * (1 - intensity);
    return img.ColorFloat64.rgba(
      current.r.toDouble() / 255,
      current.g.toDouble() / 255,
      current.b.toDouble() / 255,
      alpha / 255,
    );
  }

  double _blend(double current, double target, double intensity) {
    return (current * (1 - intensity) + target * intensity).clamp(0, 255);
  }

  Future<Uint8List?> undo() async {
    if (_currentHistoryIndex > 0) {
      _currentHistoryIndex--;
      _currentImage = _history[_currentHistoryIndex];
      _cachedPng = Uint8List.fromList(img.encodePng(_currentImage!));
      return _cachedPng;
    }
    return null;
  }

  Future<Uint8List?> redo() async {
    if (_currentHistoryIndex < _history.length - 1) {
      _currentHistoryIndex++;
      _currentImage = _history[_currentHistoryIndex];
      _cachedPng = Uint8List.fromList(img.encodePng(_currentImage!));
      return _cachedPng;
    }
    return null;
  }

  Future<Uint8List?> getCurrentImage() async {
    return _cachedPng;
  }

  void _addToHistory(img.Image image) {
    if (_currentHistoryIndex < _history.length - 1) {
      _history.removeRange(_currentHistoryIndex + 1, _history.length);
    }

    _history.add(img.Image.from(image));
    _currentHistoryIndex = _history.length - 1;

    if (_history.length > 20) {
      _history.removeAt(0);
      _currentHistoryIndex--;
    }
  }

  void dispose() {
    _history.clear();
    _originalImage = null;
    _currentImage = null;
    _cachedPng = null;
  }
}
