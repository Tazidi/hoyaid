import 'dart:io';
import 'dart:typed_data';

import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:image/image.dart' as img;

class ImagePreprocessService {
  /// Preprocessing kanonik untuk evaluasi model D4_6.
  ///
  /// Training/evaluasi desktop model memakai EXIF transpose -> RGB ->
  /// resize-with-pad hitam 224×224 -> nilai piksel mentah [0,255]. Metode ini
  /// sengaja terpisah dari alur klasifikasi pengguna yang saat ini memakai
  /// center-crop, agar uji kuantisasi dapat menahan preprocessing tetap sama.
  Future<Object> processEvaluationModelInput({
    required String imagePath,
    required int modelSize,
    required bool floatInput,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('File gambar tidak dapat dibaca.');
    }

    final oriented = img.bakeOrientation(decoded);
    final modelImage = _resizeWithPad(oriented, modelSize);
    return _toModelInput(modelImage, floatInput: floatInput);
  }

  Future<ProcessedImage> processFile({
    required String imagePath,
    required int modelSize,
    required int displaySize,
    required bool floatInput,
    int? maxImageSizeMb,
    bool enhanceLowLight = false,
  }) async {
    final file = File(imagePath);
    if (maxImageSizeMb != null && maxImageSizeMb > 0) {
      final maxBytes = maxImageSizeMb * 1024 * 1024;
      final length = await file.length();
      if (length > maxBytes) {
        throw StateError(
          'Ukuran gambar terlalu besar. Pilih gambar maksimal $maxImageSizeMb MB.',
        );
      }
    }

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('File gambar tidak dapat dibaca.');
    }

    final oriented = img.bakeOrientation(decoded);
    final square = _centerCropSquare(oriented);
    final enhancedSquare = enhanceLowLight ? _enhanceLowLight(square) : square;
    final modelImage = img.copyResize(
      enhancedSquare,
      width: modelSize,
      height: modelSize,
      interpolation: img.Interpolation.linear,
    );
    final displayImage = img.copyResize(
      enhancedSquare,
      width: displaySize,
      height: displaySize,
      interpolation: img.Interpolation.linear,
    );

    return ProcessedImage(
      displayJpegBytes: Uint8List.fromList(
        img.encodeJpg(displayImage, quality: 88),
      ),
      modelInput: _toModelInput(modelImage, floatInput: floatInput),
      modelSize: modelSize,
      displaySize: displaySize,
      enhancementApplied: enhanceLowLight,
    );
  }

  img.Image _enhanceLowLight(img.Image source) {
    final enhanced = img.Image.from(source);
    for (final pixel in enhanced) {
      final red = _clampChannel(((pixel.r - 128) * 1.06) + 142);
      final green = _clampChannel(((pixel.g - 128) * 1.06) + 142);
      final blue = _clampChannel(((pixel.b - 128) * 1.06) + 142);
      pixel
        ..r = red
        ..g = green
        ..b = blue;
    }
    return enhanced;
  }

  int _clampChannel(num value) {
    if (value < 0) return 0;
    if (value > 255) return 255;
    return value.round();
  }

  img.Image _centerCropSquare(img.Image source) {
    final side = source.width < source.height ? source.width : source.height;
    final x = ((source.width - side) / 2).round();
    final y = ((source.height - side) / 2).round();
    return img.copyCrop(source, x: x, y: y, width: side, height: side);
  }
  img.Image _resizeWithPad(img.Image source, int targetSize) {
    final scale = targetSize /
        (source.width > source.height ? source.width : source.height);
    final resizedWidth = (source.width * scale).round().clamp(1, targetSize).toInt();
    final resizedHeight =
        (source.height * scale).round().clamp(1, targetSize).toInt();
    final resized = img.copyResize(
      source,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );
    final canvas =
        img.Image(width: targetSize, height: targetSize, numChannels: 3);
    for (final pixel in canvas) {
      pixel
        ..r = 0
        ..g = 0
        ..b = 0;
    }
    img.compositeImage(
      canvas,
      resized,
      dstX: (targetSize - resizedWidth) ~/ 2,
      dstY: (targetSize - resizedHeight) ~/ 2,
    );
    return canvas;
  }


  Object _toModelInput(img.Image image, {required bool floatInput}) {
    return [
      List.generate(image.height, (y) {
        return List.generate(image.width, (x) {
          final pixel = image.getPixel(x, y);
          if (floatInput) {
            // PENTING: Model V8 (MobileNetV3) menggunakan include_preprocessing=True
            // sehingga mengharapkan input float32 dalam rentang [0.0, 255.0].
            // Jangan dibagi 255.0.
            return [
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          }
          return [
            pixel.r.toInt(),
            pixel.g.toInt(),
            pixel.b.toInt(),
          ];
        });
      }),
    ];
  }
}
