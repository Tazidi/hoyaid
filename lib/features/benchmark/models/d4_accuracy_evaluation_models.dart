import 'dart:convert';

class D4ManifestEntry {
  final int sampleId;
  final String relativePath;
  final int trueIndex;
  final String trueLabel;
  final String plantPart;
  final String backgroundType;

  const D4ManifestEntry({
    required this.sampleId,
    required this.relativePath,
    required this.trueIndex,
    required this.trueLabel,
    required this.plantPart,
    required this.backgroundType,
  });
}

class D4BatchPrediction {
  final D4ManifestEntry sample;
  final int? predictedIndex;
  final String? predictedSpeciesId;
  final double? confidence;
  final List<int> top3Indices;
  final List<String> top3SpeciesIds;
  final double? preprocessingMs;
  final double? inferenceMs;
  final String? error;

  const D4BatchPrediction({
    required this.sample,
    required this.predictedIndex,
    required this.predictedSpeciesId,
    required this.confidence,
    required this.top3Indices,
    required this.top3SpeciesIds,
    required this.preprocessingMs,
    required this.inferenceMs,
    this.error,
  });

  bool get isProcessed => predictedIndex != null && error == null;
  bool get isCorrectTop1 => predictedIndex == sample.trueIndex;
  bool get isCorrectTop3 => top3Indices.contains(sample.trueIndex);

  Map<String, String> toCsvRow() => {
        'sample_id': sample.sampleId.toString(),
        'relative_path': sample.relativePath,
        'true_index': sample.trueIndex.toString(),
        'true_label': sample.trueLabel,
        'predicted_index': predictedIndex?.toString() ?? '',
        'predicted_species_id': predictedSpeciesId ?? '',
        'confidence': confidence?.toStringAsFixed(8) ?? '',
        'top3_indices': top3Indices.join('|'),
        'top3_species_ids': top3SpeciesIds.join('|'),
        'correct_top1': isProcessed ? isCorrectTop1.toString() : '',
        'correct_top3': isProcessed ? isCorrectTop3.toString() : '',
        'preprocessing_ms': preprocessingMs?.toStringAsFixed(3) ?? '',
        'inference_ms': inferenceMs?.toStringAsFixed(3) ?? '',
        'error': error ?? '',
      };
}

class D4AccuracyMetrics {
  final int evaluatedSamples;
  final int correctTop1;
  final int correctTop3;
  final double accuracy;
  final double top3Accuracy;
  final double macroPrecision;
  final double macroRecall;
  final double macroF1;

  const D4AccuracyMetrics({
    required this.evaluatedSamples,
    required this.correctTop1,
    required this.correctTop3,
    required this.accuracy,
    required this.top3Accuracy,
    required this.macroPrecision,
    required this.macroRecall,
    required this.macroF1,
  });

  factory D4AccuracyMetrics.calculate({
    required List<D4BatchPrediction> predictions,
    required int classCount,
  }) {
    final evaluated = predictions.where((item) => item.isProcessed).toList();
    if (evaluated.isEmpty) {
      return const D4AccuracyMetrics(
        evaluatedSamples: 0,
        correctTop1: 0,
        correctTop3: 0,
        accuracy: 0,
        top3Accuracy: 0,
        macroPrecision: 0,
        macroRecall: 0,
        macroF1: 0,
      );
    }

    final precision = <double>[];
    final recall = <double>[];
    final f1 = <double>[];
    for (var index = 0; index < classCount; index++) {
      final truePositive = evaluated
          .where((item) => item.sample.trueIndex == index && item.predictedIndex == index)
          .length;
      final falsePositive = evaluated
          .where((item) => item.sample.trueIndex != index && item.predictedIndex == index)
          .length;
      final falseNegative = evaluated
          .where((item) => item.sample.trueIndex == index && item.predictedIndex != index)
          .length;
      final classPrecision = truePositive + falsePositive == 0
          ? 0.0
          : truePositive / (truePositive + falsePositive);
      final classRecall = truePositive + falseNegative == 0
          ? 0.0
          : truePositive / (truePositive + falseNegative);
      final classF1 = classPrecision + classRecall == 0
          ? 0.0
          : 2 * classPrecision * classRecall / (classPrecision + classRecall);
      precision.add(classPrecision);
      recall.add(classRecall);
      f1.add(classF1);
    }

    final correctTop1 = evaluated.where((item) => item.isCorrectTop1).length;
    final correctTop3 = evaluated.where((item) => item.isCorrectTop3).length;
    double average(List<double> values) =>
        values.fold<double>(0, (sum, value) => sum + value) / values.length;
    return D4AccuracyMetrics(
      evaluatedSamples: evaluated.length,
      correctTop1: correctTop1,
      correctTop3: correctTop3,
      accuracy: correctTop1 / evaluated.length,
      top3Accuracy: correctTop3 / evaluated.length,
      macroPrecision: average(precision),
      macroRecall: average(recall),
      macroF1: average(f1),
    );
  }

  Map<String, Object> toJson() => {
        'evaluated_samples': evaluatedSamples,
        'correct_top1': correctTop1,
        'correct_top3': correctTop3,
        'accuracy': accuracy,
        'top3_accuracy': top3Accuracy,
        'macro_precision': macroPrecision,
        'macro_recall': macroRecall,
        'macro_f1': macroF1,
      };
}

class D4AccuracyEvaluationResult {
  final DateTime startedAt;
  final DateTime finishedAt;
  final String modelVersion;
  final int modelSizeBytes;
  final int expectedSamples;
  final List<D4BatchPrediction> predictions;
  final D4AccuracyMetrics metrics;
  final double meanPreprocessingMs;
  final double meanInferenceMs;

  const D4AccuracyEvaluationResult({
    required this.startedAt,
    required this.finishedAt,
    required this.modelVersion,
    required this.modelSizeBytes,
    required this.expectedSamples,
    required this.predictions,
    required this.metrics,
    required this.meanPreprocessingMs,
    required this.meanInferenceMs,
  });

  int get failedSamples => predictions.where((item) => !item.isProcessed).length;
  Duration get elapsed => finishedAt.difference(startedAt);

  String get clipboardText => [
        'Evaluasi akurasi TFLite on-device — D4',
        'Model: $modelVersion (${(modelSizeBytes / 1000000).toStringAsFixed(2)} MB)',
        'Preprocessing: EXIF transpose → RGB → resize-with-pad 224×224 → raw [0,255]',
        'Data: ${metrics.evaluatedSamples}/$expectedSamples berhasil diproses; gagal $failedSamples',
        'Accuracy top-1: ${metrics.accuracy.toStringAsFixed(4)} (${metrics.correctTop1}/${metrics.evaluatedSamples})',
        'Macro precision: ${metrics.macroPrecision.toStringAsFixed(4)}',
        'Macro recall: ${metrics.macroRecall.toStringAsFixed(4)}',
        'Macro-F1: ${metrics.macroF1.toStringAsFixed(4)}',
        'Top-3 accuracy: ${metrics.top3Accuracy.toStringAsFixed(4)} (${metrics.correctTop3}/${metrics.evaluatedSamples})',
        'Rata-rata preprocessing: ${meanPreprocessingMs.toStringAsFixed(2)} ms/citra',
        'Rata-rata inferensi: ${meanInferenceMs.toStringAsFixed(2)} ms/citra',
        'Durasi keseluruhan: ${elapsed.inSeconds}s',
      ].join('\n');

  Map<String, Object> toSummaryJson() => {
        'created_at': finishedAt.toIso8601String(),
        'platform': 'android_on_device',
        'model_version': modelVersion,
        'model_size_bytes': modelSizeBytes,
        'expected_samples': expectedSamples,
        'failed_samples': failedSamples,
        'elapsed_ms': elapsed.inMilliseconds,
        'preprocessing': 'EXIF transpose -> RGB -> resize-with-pad 224x224 -> raw [0,255]',
        'mean_preprocessing_ms': meanPreprocessingMs,
        'mean_inference_ms': meanInferenceMs,
        'metrics': metrics.toJson(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toSummaryJson());
}
