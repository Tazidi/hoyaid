import 'dart:math' as math;

import 'package:hoyaid/features/classification/models/classification_models.dart';

class OodService {
  OodEvaluation evaluate({
    required List<double> probabilities,
    required double minConfidenceWarning,
    required double oodThreshold,
  }) {
    if (probabilities.isEmpty) {
      return const OodEvaluation(
        score: 1,
        entropy: 1,
        topMargin: 0,
        isLowConfidence: true,
        isLikelyOod: true,
      );
    }

    final sorted = [...probabilities]..sort((a, b) => b.compareTo(a));
    final top1 = sorted.first;
    final top2 = sorted.length > 1 ? sorted[1] : 0.0;
    final topMargin = (top1 - top2).clamp(0.0, 1.0).toDouble();

    final entropy = _normalizedEntropy(probabilities);
    final lowConfidenceScore = (1 - top1).clamp(0.0, 1.0).toDouble();
    final narrowMarginScore =
        (1 - (topMargin / 0.35)).clamp(0.0, 1.0).toDouble();
    final score = ((lowConfidenceScore * 0.50) +
            (entropy * 0.30) +
            (narrowMarginScore * 0.20))
        .clamp(0.0, 1.0)
        .toDouble();

    final isLowConfidence = top1 < minConfidenceWarning;
    return OodEvaluation(
      score: score,
      entropy: entropy,
      topMargin: topMargin,
      isLowConfidence: isLowConfidence,
      isLikelyOod: isLowConfidence || score >= oodThreshold,
    );
  }

  double _normalizedEntropy(List<double> probabilities) {
    if (probabilities.length <= 1) return 0;

    var entropy = 0.0;
    for (final probability in probabilities) {
      if (probability <= 0) continue;
      entropy -= probability * (math.log(probability) / math.ln2);
    }

    final maxEntropy = math.log(probabilities.length) / math.ln2;
    if (maxEntropy == 0) return 0;
    return (entropy / maxEntropy).clamp(0.0, 1.0).toDouble();
  }
}
