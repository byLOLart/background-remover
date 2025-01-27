import 'package:image/image.dart' as img;
import 'dart:math' as math;

/// Clase de utilidad para procesamiento de imágenes
class ImageProcessor {
  /// Mezcla dos colores con una intensidad dada
  static List<num> blendColors(int base, int blend, double intensity) {
    final baseRGBA = _getRGBA(base);
    final blendRGBA = _getRGBA(blend);

    return [
      _blend(baseRGBA.$1, blendRGBA.$1, intensity),
      _blend(baseRGBA.$2, blendRGBA.$2, intensity),
      _blend(baseRGBA.$3, blendRGBA.$3, intensity),
      _blend(baseRGBA.$4, blendRGBA.$4, intensity)
    ];
  }

  /// Aplica transparencia a un color
  static int applyTransparency(int color, double intensity) {
    final rgba = _getRGBA(color);
    final alpha = (rgba.$4 * (1 - intensity)).round().clamp(0, 255);
    return _rgbaToInt(rgba.$1, rgba.$2, rgba.$3, alpha);
  }

  /// Convierte componentes RGBA a un entero de 32 bits
  static int _rgbaToInt(int r, int g, int b, int a) {
    return (r << 24) | (g << 16) | (b << 8) | a;
  }

  /// Extrae componentes RGBA de un color
  static (int, int, int, int) _getRGBA(int color) {
    return (
      (color >> 24) & 0xFF, // R
      (color >> 16) & 0xFF, // G
      (color >> 8) & 0xFF, // B
      color & 0xFF, // A
    );
  }

  /// Función de mezclado básica
  static int _blend(int start, int end, double amount) {
    return (start + (end - start) * amount).round().clamp(0, 255);
  }

  /// Procesa una región de la imagen
  static void processRegion(
    img.Image target,
    img.Image? source,
    int centerX,
    int centerY,
    int radius,
    double intensity, {
    bool erase = false,
  }) {
    final startX = math.max(0, centerX - radius);
    final startY = math.max(0, centerY - radius);
    final endX = math.min(target.width, centerX + radius + 1);
    final endY = math.min(target.height, centerY + radius + 1);

    final radiusSquared = radius * radius;

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final deltaX = x - centerX;
        final deltaY = y - centerY;
        final distanceSquared = deltaX * deltaX + deltaY * deltaY;

        if (distanceSquared <= radiusSquared) {
          final distance = math.sqrt(distanceSquared);
          final falloff = _calculateFalloff(distance / radius);

          if (erase) {
            _applyErase(target, x, y, falloff);
          } else if (source != null) {
            _applyRestore(target, source, x, y, falloff);
          }
        }
      }
    }
  }

  /// Calcula la intensidad del efecto basado en la distancia
  static double _calculateFalloff(double normalizedDistance) {
    // Función suavizada para el borde del pincel
    return (1 - normalizedDistance * normalizedDistance).clamp(0.0, 1.0);
  }

  /// Aplica el efecto de borrado
  static void _applyErase(img.Image image, int x, int y, double intensity) {
    final pixel = image.getPixel(x, y);
    final rgba = _getRGBA(pixel as int);
    final newAlpha = (rgba.$4 * (1 - intensity)).round().clamp(0, 255);
    image.setPixel(
        x, y, img.ColorUint32.rgba(rgba.$1, rgba.$2, rgba.$3, newAlpha));
  }

  /// Aplica el efecto de restauración
  static void _applyRestore(
    img.Image target,
    img.Image source,
    int x,
    int y,
    double intensity,
  ) {
    final targetRGBA = _getRGBA(target.getPixel(x, y) as int);
    final sourceRGBA = _getRGBA(source.getPixel(x, y) as int);

    final r = _blend(targetRGBA.$1, sourceRGBA.$1, intensity);
    final g = _blend(targetRGBA.$2, sourceRGBA.$2, intensity);
    final b = _blend(targetRGBA.$3, sourceRGBA.$3, intensity);
    final a = _blend(targetRGBA.$4, sourceRGBA.$4, intensity);

    target.setPixel(x, y, img.ColorUint32.rgba(r, g, b, a));
  }

  /// Crea una copia segura de una imagen
  static img.Image safeCopy(img.Image source) {
    return img.copyResize(
      source,
      width: source.width,
      height: source.height,
    );
  }

  /// Redimensiona una imagen manteniendo la proporción
  static img.Image resizeIfNeeded(
    img.Image source, {
    int maxWidth = 1024,
    int maxHeight = 1024,
  }) {
    if (source.width <= maxWidth && source.height <= maxHeight) {
      return safeCopy(source);
    }

    final aspectRatio = source.width / source.height;
    int targetWidth, targetHeight;

    if (source.width > source.height) {
      targetWidth = maxWidth;
      targetHeight = (maxWidth / aspectRatio).round();
    } else {
      targetHeight = maxHeight;
      targetWidth = (maxHeight * aspectRatio).round();
    }

    return img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );
  }
}
