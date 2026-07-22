import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Menyiapkan saran area persegi untuk model klasifikasi tanpa menjalankan ML.
///
/// Saran dibuat dari warna hijau, saturasi, dan kontras pada sampel kecil
/// gambar. Pengguna tetap dapat memindahkan atau mengubah kotaknya.
class CropSuggestionService {
  static const int _analysisSide = 256;
  static const int _previewLongestSide = 1440;

  Future<CropEditorData> prepareEditor(XFile source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Foto tidak dapat dibaca untuk pengaturan area scan.');
    }

    final oriented = img.bakeOrientation(decoded);
    final preview = _previewFor(oriented);
    return CropEditorData(
      previewJpegBytes: Uint8List.fromList(img.encodeJpg(preview, quality: 92)),
      previewWidth: preview.width,
      previewHeight: preview.height,
      suggestedSelection: _suggestSelection(oriented),
    );
  }

  Future<XFile> createCroppedImage({
    required XFile source,
    required CropSelection selection,
  }) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Foto tidak dapat dipotong karena file tidak terbaca.');
    }

    final image = img.bakeOrientation(decoded);
    final x = (selection.left.clamp(0.0, 1.0) * image.width).round();
    final y = (selection.top.clamp(0.0, 1.0) * image.height).round();
    final width = (selection.width.clamp(0.01, 1.0) * image.width)
        .round()
        .clamp(1, image.width - x);
    final height = (selection.height.clamp(0.01, 1.0) * image.height)
        .round()
        .clamp(1, image.height - y);
    final cropped = img.copyCrop(
      image,
      x: x,
      y: y,
      width: width,
      height: height,
    );

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}${Platform.pathSeparator}'
        'ihoya_scan_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(img.encodeJpg(cropped, quality: 95));
    return XFile(path);
  }

  img.Image _previewFor(img.Image source) {
    final longestSide = math.max(source.width, source.height);
    if (longestSide <= _previewLongestSide) return source;
    return img.copyResize(source, width: _previewLongestSide);
  }

  CropSelection _suggestSelection(img.Image source) {
    final sample = _analysisFor(source);
    final meanLuma = _meanLuma(sample);
    var totalWeight = 0.0;
    var weightedX = 0.0;
    var weightedY = 0.0;

    for (var y = 0; y < sample.height; y++) {
      for (var x = 0; x < sample.width; x++) {
        final weight = _subjectWeight(sample.getPixel(x, y), meanLuma);
        totalWeight += weight;
        weightedX += x * weight;
        weightedY += y * weight;
      }
    }

    if (totalWeight < sample.width * sample.height * 5) {
      return _selectionAround(source, 0.5, 0.5, 0.76);
    }

    final centerX = weightedX / totalWeight;
    final centerY = weightedY / totalWeight;
    var varianceX = 0.0;
    var varianceY = 0.0;
    for (var y = 0; y < sample.height; y++) {
      for (var x = 0; x < sample.width; x++) {
        final weight = _subjectWeight(sample.getPixel(x, y), meanLuma);
        varianceX += math.pow(x - centerX, 2) * weight;
        varianceY += math.pow(y - centerY, 2) * weight;
      }
    }

    final spread = math.max(
      math.sqrt(varianceX / totalWeight) / sample.width,
      math.sqrt(varianceY / totalWeight) / sample.height,
    );
    final coverage = (spread * 4.4).clamp(0.50, 0.90).toDouble();
    return _selectionAround(
      source,
      centerX / sample.width,
      centerY / sample.height,
      coverage,
    );
  }

  img.Image _analysisFor(img.Image source) {
    if (math.max(source.width, source.height) <= _analysisSide) return source;
    return img.copyResize(source, width: _analysisSide);
  }

  CropSelection _selectionAround(
    img.Image image,
    double normalizedX,
    double normalizedY,
    double coverage,
  ) {
    final side = math.min(image.width, image.height) * coverage;
    final centerX = normalizedX.clamp(0.0, 1.0) * image.width;
    final centerY = normalizedY.clamp(0.0, 1.0) * image.height;
    final left = (centerX - (side / 2)).clamp(0.0, image.width - side);
    final top = (centerY - (side / 2)).clamp(0.0, image.height - side);
    return CropSelection(
      left: left / image.width,
      top: top / image.height,
      width: side / image.width,
      height: side / image.height,
    );
  }

  double _meanLuma(img.Image image) {
    var total = 0.0;
    for (final pixel in image) {
      total += _luma(pixel);
    }
    return total / (image.width * image.height);
  }

  double _subjectWeight(img.Pixel pixel, double meanLuma) {
    final red = pixel.r.toDouble();
    final green = pixel.g.toDouble();
    final blue = pixel.b.toDouble();
    final greenDominance = green - ((red + blue) / 2);
    final saturation = math.max(red, math.max(green, blue)) -
        math.min(red, math.min(green, blue));
    final contrast = (_luma(pixel) - meanLuma).abs();
    return math.max(0, greenDominance - 8) +
        (math.max(0, saturation - 24) * 0.35) +
        (math.max(0, contrast - 30) * 0.55);
  }

  double _luma(img.Pixel pixel) =>
      (0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b);
}

class CropEditorData {
  final Uint8List previewJpegBytes;
  final int previewWidth;
  final int previewHeight;
  final CropSelection suggestedSelection;

  const CropEditorData({
    required this.previewJpegBytes,
    required this.previewWidth,
    required this.previewHeight,
    required this.suggestedSelection,
  });
}

class CropSelection {
  final double left;
  final double top;
  final double width;
  final double height;

  const CropSelection({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}
