import 'package:flutter_test/flutter_test.dart';
import 'package:hoyaid/features/classification/services/pillow_bilinear_resizer.dart';
import 'package:image/image.dart' as img;

void main() {
  test('matches Pillow 10.4 bilinear downsampling golden pixels', () {
    final source = img.Image(width: 11, height: 7, numChannels: 3);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(
          x,
          y,
          (x * 31 + y * 17) % 256,
          (x * 7 + y * 43) % 256,
          (x * 19 + y * 13) % 256,
        );
      }
    }

    final resized = copyResizePillowBilinear(source, width: 4, height: 3);
    final actual = <int>[];
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        actual.addAll([pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()]);
      }
    }

    expect(actual, <int>[
      51,
      45,
      33,
      128,
      63,
      80,
      182,
      81,
      132,
      79,
      99,
      179,
      87,
      137,
      61,
      163,
      154,
      108,
      149,
      161,
      160,
      76,
      176,
      207,
      123,
      138,
      89,
      173,
      150,
      136,
      89,
      90,
      188,
      105,
      82,
      209,
    ]);
  });
}
