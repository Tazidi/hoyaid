import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Resizes an 8-bit image with the same bilinear downsampling convention used
/// by Pillow 10.x.
///
/// `package:image`'s `Interpolation.linear` samples only the neighboring four
/// pixels. Pillow widens the bilinear kernel while downsampling, so every
/// destination pixel averages a larger source area. D4_6 was evaluated with
/// Pillow; this implementation keeps the mobile evaluation tensor equivalent.
img.Image copyResizePillowBilinear(
  img.Image source, {
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError('Ukuran output harus lebih besar dari nol.');
  }
  if (source.width == width && source.height == height) {
    return _copyRgb(source);
  }

  var intermediate = source;
  if (source.width != width) {
    final horizontal = img.Image(
      width: width,
      height: source.height,
      numChannels: 3,
    );
    final coefficients = _precomputeCoefficients(source.width, width);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < width; x++) {
        final kernel = coefficients[x];
        var red = _roundingBias;
        var green = _roundingBias;
        var blue = _roundingBias;
        for (var offset = 0; offset < kernel.weights.length; offset++) {
          final pixel = source.getPixel(kernel.start + offset, y);
          final weight = kernel.weights[offset];
          red += pixel.r.toInt() * weight;
          green += pixel.g.toInt() * weight;
          blue += pixel.b.toInt() * weight;
        }
        horizontal.setPixelRgb(
          x,
          y,
          _clip8(red),
          _clip8(green),
          _clip8(blue),
        );
      }
    }
    intermediate = horizontal;
  }

  if (source.height == height) {
    return intermediate;
  }

  final output = img.Image(width: width, height: height, numChannels: 3);
  final coefficients = _precomputeCoefficients(source.height, height);
  for (var y = 0; y < height; y++) {
    final kernel = coefficients[y];
    for (var x = 0; x < width; x++) {
      var red = _roundingBias;
      var green = _roundingBias;
      var blue = _roundingBias;
      for (var offset = 0; offset < kernel.weights.length; offset++) {
        final pixel = intermediate.getPixel(x, kernel.start + offset);
        final weight = kernel.weights[offset];
        red += pixel.r.toInt() * weight;
        green += pixel.g.toInt() * weight;
        blue += pixel.b.toInt() * weight;
      }
      output.setPixelRgb(
        x,
        y,
        _clip8(red),
        _clip8(green),
        _clip8(blue),
      );
    }
  }
  return output;
}

img.Image _copyRgb(img.Image source) {
  final output = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      output.setPixelRgb(x, y, pixel.r, pixel.g, pixel.b);
    }
  }
  return output;
}

const int _precisionBits = 22;
const int _coefficientScale = 1 << _precisionBits;
const int _roundingBias = 1 << (_precisionBits - 1);

int _clip8(int value) => (value >> _precisionBits).clamp(0, 255).toInt();

List<_Kernel> _precomputeCoefficients(int inputSize, int outputSize) {
  final scale = inputSize / outputSize;
  final filterScale = math.max(scale, 1.0);
  final support = filterScale;
  final inverseFilterScale = 1.0 / filterScale;

  return List.generate(outputSize, (destination) {
    final center = (destination + 0.5) * scale;
    var start = (center - support + 0.5).toInt();
    start = start.clamp(0, inputSize).toInt();
    var end = (center + support + 0.5).toInt();
    end = end.clamp(0, inputSize).toInt();

    final floatingWeights = <double>[];
    var total = 0.0;
    for (var source = start; source < end; source++) {
      final distance = (source - center + 0.5).abs() * inverseFilterScale;
      final weight = distance < 1.0 ? 1.0 - distance : 0.0;
      floatingWeights.add(weight);
      total += weight;
    }

    final integerWeights = floatingWeights
        .map((weight) => (0.5 + (weight / total) * _coefficientScale).toInt())
        .toList(growable: false);
    return _Kernel(start, integerWeights);
  }, growable: false);
}

class _Kernel {
  const _Kernel(this.start, this.weights);

  final int start;
  final List<int> weights;
}
