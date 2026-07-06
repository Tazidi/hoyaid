import 'dart:io';
import 'dart:typed_data';

import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:image/image.dart' as img;

class ImagePreprocessService {
  Future<ProcessedImage> processFile({
    required String imagePath,
    required int modelSize,
    required int displaySize,
    required bool floatInput,
    int? maxImageSizeMb,
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
    final modelImage = img.copyResize(
      square,
      width: modelSize,
      height: modelSize,
      interpolation: img.Interpolation.linear,
    );
    final displayImage = img.copyResize(
      square,
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
    );
  }

  img.Image _centerCropSquare(img.Image source) {
    final side = source.width < source.height ? source.width : source.height;
    final x = ((source.width - side) / 2).round();
    final y = ((source.height - side) / 2).round();
    return img.copyCrop(source, x: x, y: y, width: side, height: side);
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
