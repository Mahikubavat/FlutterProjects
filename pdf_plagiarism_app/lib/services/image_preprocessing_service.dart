import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Applies conservative, OCR-friendly changes without rewriting document
/// content. EXIF orientation handles rotated phone photos; resizing, grayscale,
/// contrast, and a small blur help Tesseract with shadows and camera noise.
class ImagePreprocessingService {
  static Future<Uint8List> prepareAsync(Uint8List input) =>
      compute(prepare, input);

  static Uint8List prepare(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return input;

    var image = img.bakeOrientation(decoded);
    image = img.trim(image, fuzzy: 0.06, padding: 8);
    if (image.width > 2600) {
      image = img.copyResize(image,
          width: 2600, interpolation: img.Interpolation.cubic);
    }
    image = img.grayscale(image);
    image = _deskew(image);
    image = img.gaussianBlur(image, radius: 1);
    image = img.adjustColor(image, contrast: 1.25, brightness: 1.04);
    return Uint8List.fromList(img.encodeJpg(image, quality: 95));
  }

  static img.Image _deskew(img.Image source) {
    // Optimization: Downscale to a fast 400px thumbnail to detect the skew angle.
    // Testing rotations on a thumbnail is ~40x faster than rotating the full image 8 times.
    // The winning angle is then applied only once to the full source image.
    const thumbWidth = 400;
    final thumb = source.width > thumbWidth
        ? img.copyResize(source,
            width: thumbWidth, interpolation: img.Interpolation.linear)
        : source;

    var bestAngle = 0.0;
    var bestScore = _horizontalInkScore(thumb);
    for (var angle = -4.0; angle <= 4.0; angle += 1.0) {
      if (angle == 0) continue;
      final candidate = img.copyRotate(thumb, angle: angle);
      final score = _horizontalInkScore(candidate);
      if (score > bestScore) {
        bestAngle = angle;
        bestScore = score;
      }
    }
    if (bestAngle == 0.0) return source;
    return img.copyRotate(source, angle: bestAngle);
  }

  static int _horizontalInkScore(img.Image image) {
    var score = 0;
    for (var y = 0; y < image.height; y += 4) {
      for (var x = 0; x < image.width - 1; x += 4) {
        if (image.getPixel(x, y).r < 170 && image.getPixel(x + 1, y).r < 170) {
          score++;
        }
      }
    }
    return score;
  }
}
