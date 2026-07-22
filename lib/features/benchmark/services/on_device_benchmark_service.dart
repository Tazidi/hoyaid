import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hoyaid/features/benchmark/models/on_device_benchmark_models.dart';
import 'package:hoyaid/features/benchmark/services/device_performance_monitor.dart';
import 'package:hoyaid/features/classification/models/classification_config.dart';
import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:hoyaid/features/classification/services/classification_config_service.dart';
import 'package:hoyaid/features/classification/services/image_preprocess_service.dart';
import 'package:hoyaid/features/classification/services/image_quality_service.dart';
import 'package:hoyaid/features/classification/services/label_map_service.dart';
import 'package:hoyaid/features/classification/services/tflite_service.dart';

/// Menjalankan benchmark lokal. Tidak membaca GPS, tidak menyimpan hasil, dan
/// tidak melakukan unggah Firebase selama bagian yang diukur.
class OnDeviceBenchmarkService {
  final ClassificationConfigService _configService;
  final LabelMapService _labelMapService;
  final ImagePreprocessService _imagePreprocessService;
  final ImageQualityService _imageQualityService;
  final TFLiteService _tfliteService;
  final DevicePerformanceMonitor _resourceMonitor;

  OnDeviceBenchmarkService({
    required ClassificationConfigService configService,
    required LabelMapService labelMapService,
    required ImagePreprocessService imagePreprocessService,
    required ImageQualityService imageQualityService,
    required TFLiteService tfliteService,
    DevicePerformanceMonitor? resourceMonitor,
  })  : _configService = configService,
        _labelMapService = labelMapService,
        _imagePreprocessService = imagePreprocessService,
        _imageQualityService = imageQualityService,
        _tfliteService = tfliteService,
        _resourceMonitor = resourceMonitor ?? DevicePerformanceMonitor();

  Future<OnDeviceBenchmarkResult> run({
    required String imagePath,
    int warmupRuns = 5,
    int measuredRuns = 30,
  }) async {
    if (warmupRuns < 1 || measuredRuns < 2) {
      throw ArgumentError('Warm-up minimal 1 dan pengukuran minimal 2 kali.');
    }

    // Persiapan sengaja dilakukan sebelum monitor agar jaringan Firestore
    // (konfigurasi/label) tidak memengaruhi metrik on-device.
    final config = await _configService.getConfig();
    final labels = await _labelMapService.resolveLabels(config);
    final device = await _resourceMonitor.getDeviceInfo();

    final qualityStopwatch = Stopwatch()..start();
    final imageQuality = await _imageQualityService.analyzeFile(imagePath);
    qualityStopwatch.stop();

    // Cold-load dilaporkan terpisah dari inferensi hangat yang berulang.
    _tfliteService.dispose();
    final loadStopwatch = Stopwatch()..start();
    await _tfliteService.loadModel(config);
    loadStopwatch.stop();
    final modelSizeBytes = await _readModelSize(config);

    await _resourceMonitor.start();
    ProcessResourceUsage? resources;
    try {
      for (var index = 0; index < warmupRuns; index++) {
        final processed = await _preprocess(
          imagePath: imagePath,
          config: config,
          imageQuality: imageQuality,
        );
        _tfliteService.run(
          modelInput: processed.modelInput,
          labels: labels,
          config: config,
        );
      }

      final preprocessingSamples = <double>[];
      final inferenceSamples = <double>[];
      ClassificationPrediction? lastPrediction;
      for (var index = 0; index < measuredRuns; index++) {
        final preprocessingStopwatch = Stopwatch()..start();
        final processed = await _preprocess(
          imagePath: imagePath,
          config: config,
          imageQuality: imageQuality,
        );
        preprocessingStopwatch.stop();

        final inferenceStopwatch = Stopwatch()..start();
        lastPrediction = _tfliteService.run(
          modelInput: processed.modelInput,
          labels: labels,
          config: config,
        );
        inferenceStopwatch.stop();

        preprocessingSamples.add(
          preprocessingStopwatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond,
        );
        inferenceSamples.add(
          inferenceStopwatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond,
        );
      }

      if (lastPrediction == null) {
        throw StateError('Prediksi benchmark tidak tersedia.');
      }
      final preprocessing = LatencyStatistics.fromSamples(preprocessingSamples);
      final inference = LatencyStatistics.fromSamples(inferenceSamples);
      final core = LatencyStatistics.fromSamples([
        for (var index = 0; index < measuredRuns; index++)
          preprocessingSamples[index] + inferenceSamples[index],
      ]);

      return OnDeviceBenchmarkResult(
        createdAt: DateTime.now(),
        sourceImageName: _fileName(imagePath),
        modelVersion: config.activeModelVersion,
        modelSizeBytes: modelSizeBytes,
        warmupRuns: warmupRuns,
        measuredRuns: measuredRuns,
        modelLoadMs:
            loadStopwatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond,
        imageQualityMs:
            qualityStopwatch.elapsedMicroseconds / Duration.microsecondsPerMillisecond,
        preprocessing: preprocessing,
        inference: inference,
        coreProcessing: core,
        resources: (resources ??= await _resourceMonitor.stop()),
        device: device,
        topPrediction: lastPrediction.speciesId,
        confidence: lastPrediction.confidence,
      );
    } finally {
      if (resources == null) {
        try {
          resources = await _resourceMonitor.stop();
        } catch (_) {
          // Jangan menutupi error benchmark utama bila monitor sudah berhenti.
        }
      }
      _tfliteService.dispose();
    }
  }

  Future<ProcessedImage> _preprocess({
    required String imagePath,
    required ClassificationConfig config,
    required ImageQualityReport imageQuality,
  }) {
    return _imagePreprocessService.processFile(
      imagePath: imagePath,
      modelSize: config.inputSize,
      displaySize: config.displaySize,
      floatInput: _tfliteService.isFloatInput,
      maxImageSizeMb: config.maxImageSizeMb,
      enhanceLowLight: imageQuality.needsBrightnessEnhancement,
    );
  }

  Future<int> _readModelSize(ClassificationConfig config) async {
    if (config.useRemoteModel &&
        config.remoteModelStoragePath?.isNotEmpty == true) {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        '${config.activeModelVersion}.tflite',
      );
      if (await file.exists()) return file.length();
    }

    final bytes = await rootBundle.load(config.modelAssetPath);
    return bytes.lengthInBytes;
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;
}
