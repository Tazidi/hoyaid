import 'dart:io';

import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:image/image.dart' as img;

class ImageQualityService {
  static const double _blurThreshold = 70;
  static const double _darkBrightnessThreshold = 72;
  static const double _brightBrightnessThreshold = 210;
  static const double _brightPixelRatioThreshold = 0.38;
  static const double _minContentFrameRatio = 0.18;

  Future<ImageQualityReport> analyzeFile(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('File gambar tidak dapat dibaca.');
    }

    final oriented = img.bakeOrientation(decoded);
    final sample = img.copyResize(
      _centerCropSquare(oriented),
      width: 192,
      height: 192,
      interpolation: img.Interpolation.linear,
    );

    final brightness = _averageBrightness(sample);
    final brightPixelRatio = _brightPixelRatio(sample);
    final blurScore = _laplacianVariance(sample);
    final contentFrameRatio = _contentFrameRatio(sample);
    final issues = <ImageQualityIssue>{};

    if (blurScore < _blurThreshold) {
      issues.add(ImageQualityIssue.blur);
    }
    if (brightness < _darkBrightnessThreshold) {
      issues.add(ImageQualityIssue.tooDark);
    }
    if (brightness > _brightBrightnessThreshold ||
        brightPixelRatio > _brightPixelRatioThreshold) {
      issues.add(ImageQualityIssue.tooBright);
    }
    if (contentFrameRatio < _minContentFrameRatio) {
      issues.add(ImageQualityIssue.objectTooSmall);
    }

    return ImageQualityReport(
      blurScore: blurScore,
      brightness: brightness,
      brightPixelRatio: brightPixelRatio,
      contentFrameRatio: contentFrameRatio,
      issues: issues,
    );
  }

  img.Image _centerCropSquare(img.Image source) {
    final side = source.width < source.height ? source.width : source.height;
    final x = ((source.width - side) / 2).round();
    final y = ((source.height - side) / 2).round();
    return img.copyCrop(source, x: x, y: y, width: side, height: side);
  }

  double _averageBrightness(img.Image image) {
    var total = 0.0;
    for (final pixel in image) {
      total += _luma(pixel);
    }
    return total / (image.width * image.height);
  }

  double _brightPixelRatio(img.Image image) {
    var brightPixels = 0;
    for (final pixel in image) {
      if (_luma(pixel) >= 238) {
        brightPixels++;
      }
    }
    return brightPixels / (image.width * image.height);
  }

  double _laplacianVariance(img.Image image) {
    final values = <double>[];
    for (var y = 1; y < image.height - 1; y++) {
      for (var x = 1; x < image.width - 1; x++) {
        final center = _luma(image.getPixel(x, y));
        final laplacian = (_luma(image.getPixel(x - 1, y)) +
                _luma(image.getPixel(x + 1, y)) +
                _luma(image.getPixel(x, y - 1)) +
                _luma(image.getPixel(x, y + 1))) -
            (4 * center);
        values.add(laplacian);
      }
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    var variance = 0.0;
    for (final value in values) {
      final delta = value - mean;
      variance += delta * delta;
    }
    return variance / values.length;
  }

  double _contentFrameRatio(img.Image image) {
    final grayMean = _averageBrightness(image);
    var minX = image.width;
    var minY = image.height;
    var maxX = -1;
    var maxY = -1;

    for (var y = 1; y < image.height - 1; y++) {
      for (var x = 1; x < image.width - 1; x++) {
        final pixel = image.getPixel(x, y);
        final greenDominance = pixel.g - ((pixel.r + pixel.b) / 2);
        final contrast = (_luma(pixel) - grayMean).abs();
        if (greenDominance > 16 || contrast > 42) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX < minX || maxY < minY) {
      return 0;
    }

    final area = (maxX - minX + 1) * (maxY - minY + 1);
    return area / (image.width * image.height);
  }

  double _luma(img.Pixel pixel) {
    return (0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b);
  }
}
