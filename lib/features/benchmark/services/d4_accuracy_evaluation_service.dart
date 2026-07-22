import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hoyaid/features/benchmark/models/d4_accuracy_evaluation_models.dart';
import 'package:hoyaid/features/classification/models/classification_config.dart';
import 'package:hoyaid/features/classification/services/image_preprocess_service.dart';
import 'package:hoyaid/features/classification/services/tflite_service.dart';

typedef D4EvaluationProgress = void Function({
  required int completed,
  required int total,
  required String currentFile,
});

/// Evaluasi batch lokal untuk membandingkan TFLite Android dengan Keras desktop.
/// GPS, Firebase, pemeriksa kualitas, riwayat, dan upload tidak dipanggil di sini.
class D4AccuracyEvaluationService {
  final ImagePreprocessService _preprocessService;
  final TFLiteService _tfliteService;

  D4AccuracyEvaluationService({
    required ImagePreprocessService preprocessService,
    required TFLiteService tfliteService,
  })  : _preprocessService = preprocessService,
        _tfliteService = tfliteService;

  Future<D4AccuracyEvaluationResult> run({
    required String mobileDatasetRoot,
    D4EvaluationProgress? onProgress,
  }) async {
    final root = Directory(mobileDatasetRoot);
    final manifestFile =
        File('${root.path}${Platform.pathSeparator}d4_test_manifest.csv');
    final imagesRoot = Directory('${root.path}${Platform.pathSeparator}images');
    if (!await manifestFile.exists()) {
      throw StateError(
        'd4_test_manifest.csv tidak ditemukan dalam folder yang dipilih.',
      );
    }
    if (!await imagesRoot.exists()) {
      throw StateError('Folder images tidak ditemukan dalam folder yang dipilih.');
    }

    final manifest = await _readManifest(manifestFile);
    final config = ClassificationConfig.fallback();
    final labels = await _readAssetLabels(config.labelsAssetPath);
    if (labels.length != 30) {
      throw StateError(
        'labels.txt harus berisi 30 label, ditemukan ${labels.length}.',
      );
    }
    if (manifest.length != 355) {
      throw StateError(
        'Manifest D4 harus berisi 355 data, ditemukan ${manifest.length}.',
      );
    }

    final modelBytes = await rootBundle.load(config.modelAssetPath);
    _tfliteService.dispose();
    await _tfliteService.loadModel(config);

    final startedAt = DateTime.now();
    final predictions = <D4BatchPrediction>[];
    try {
      for (var offset = 0; offset < manifest.length; offset++) {
        final sample = manifest[offset];
        final imagePath = _safeJoin(imagesRoot, sample.relativePath);
        try {
          if (!await File(imagePath).exists()) {
            throw StateError('Gambar tidak ditemukan.');
          }
          final preprocessingWatch = Stopwatch()..start();
          final input = await _preprocessService.processEvaluationModelInput(
            imagePath: imagePath,
            modelSize: config.inputSize,
            floatInput: _tfliteService.isFloatInput,
          );
          preprocessingWatch.stop();

          final inferenceWatch = Stopwatch()..start();
          final prediction = _tfliteService.run(
            modelInput: input,
            labels: labels,
            config: config,
          );
          inferenceWatch.stop();
          predictions.add(
            D4BatchPrediction(
              sample: sample,
              predictedIndex: prediction.topPrediction.labelIndex,
              predictedSpeciesId: prediction.topPrediction.speciesId,
              confidence: prediction.topPrediction.confidence,
              top3Indices: prediction.topPredictions
                  .map((item) => item.labelIndex)
                  .toList(),
              top3SpeciesIds: prediction.topPredictions
                  .map((item) => item.speciesId)
                  .toList(),
              preprocessingMs: preprocessingWatch.elapsedMicroseconds /
                  Duration.microsecondsPerMillisecond,
              inferenceMs:
                  inferenceWatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond,
            ),
          );
        } catch (error) {
          predictions.add(
            D4BatchPrediction(
              sample: sample,
              predictedIndex: null,
              predictedSpeciesId: null,
              confidence: null,
              top3Indices: const [],
              top3SpeciesIds: const [],
              preprocessingMs: null,
              inferenceMs: null,
              error: error.toString(),
            ),
          );
        }

        onProgress?.call(
          completed: offset + 1,
          total: manifest.length,
          currentFile: sample.relativePath,
        );
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _tfliteService.dispose();
    }

    final processed = predictions.where((item) => item.isProcessed).toList();
    double mean(Iterable<double> values) {
      final list = values.toList();
      if (list.isEmpty) return 0;
      return list.fold<double>(0, (sum, value) => sum + value) / list.length;
    }

    final finishedAt = DateTime.now();
    return D4AccuracyEvaluationResult(
      startedAt: startedAt,
      finishedAt: finishedAt,
      modelVersion: config.activeModelVersion,
      modelSizeBytes: modelBytes.lengthInBytes,
      expectedSamples: manifest.length,
      predictions: predictions,
      metrics: D4AccuracyMetrics.calculate(
        predictions: predictions,
        classCount: labels.length,
      ),
      meanPreprocessingMs: mean(
        processed.map((item) => item.preprocessingMs ?? 0),
      ),
      meanInferenceMs: mean(
        processed.map((item) => item.inferenceMs ?? 0),
      ),
    );
  }

  Future<List<String>> _readAssetLabels(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
  }

  Future<List<D4ManifestEntry>> _readManifest(File file) async {
    final lines = await file.readAsLines();
    if (lines.isEmpty) throw StateError('Manifest D4 kosong.');
    final headers = lines.first.replaceFirst('\uFEFF', '').split(',');
    const required = {
      'sample_id',
      'relative_path',
      'true_index',
      'true_label',
      'plant_part',
      'background_type',
    };
    if (!required.every(headers.contains)) {
      throw StateError(
        'Kolom manifest D4 tidak lengkap. Buat ulang dengan script desktop.',
      );
    }
    final index = <String, int>{
      for (var position = 0; position < headers.length; position++)
        headers[position]: position,
    };
    String value(List<String> row, String column) => row[index[column]!].trim();

    final entries = <D4ManifestEntry>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final row = line.split(',');
      if (row.length != headers.length) {
        throw StateError(
          'Manifest berisi CSV tidak valid; nama file tidak boleh mengandung koma.',
        );
      }
      final relativePath = value(row, 'relative_path').replaceAll('\\', '/');
      _validateRelativePath(relativePath);
      final trueIndex = int.tryParse(value(row, 'true_index'));
      final sampleId = int.tryParse(value(row, 'sample_id'));
      if (sampleId == null || trueIndex == null || trueIndex < 0 || trueIndex >= 30) {
        throw StateError('sample_id atau true_index pada manifest tidak valid.');
      }
      entries.add(
        D4ManifestEntry(
          sampleId: sampleId,
          relativePath: relativePath,
          trueIndex: trueIndex,
          trueLabel: value(row, 'true_label'),
          plantPart: value(row, 'plant_part'),
          backgroundType: value(row, 'background_type'),
        ),
      );
    }
    if (entries.map((entry) => entry.sampleId).toSet().length != entries.length) {
      throw StateError('sample_id dalam manifest tidak unik.');
    }
    return entries;
  }

  String _safeJoin(Directory root, String relativePath) {
    return '${root.path}${Platform.pathSeparator}'
        '${relativePath.replaceAll('/', Platform.pathSeparator)}';
  }

  void _validateRelativePath(String value) {
    final components = value.split('/');
    if (value.isEmpty || value.startsWith('/') || components.contains('..')) {
      throw StateError('relative_path manifest tidak aman: $value');
    }
  }
}
