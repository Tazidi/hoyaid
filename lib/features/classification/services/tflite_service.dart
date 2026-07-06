import 'dart:io';
import 'dart:math' as math;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hoyaid/features/classification/models/classification_config.dart';
import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:hoyaid/features/classification/services/ood_service.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  final OodService _oodService;
  final FirebaseStorage _storage;
  Interpreter? _interpreter;
  String? _loadedModelKey;

  TFLiteService({
    OodService? oodService,
    FirebaseStorage? storage,
  })  : _oodService = oodService ?? OodService(),
        _storage = storage ?? FirebaseStorage.instance;

  bool get hasLoadedModel => _interpreter != null;

  Future<void> loadModel(ClassificationConfig config) async {
    final modelKey = config.useRemoteModel &&
            config.remoteModelStoragePath?.isNotEmpty == true
        ? 'remote:${config.remoteModelStoragePath}'
        : 'asset:${config.modelAssetPath}';
    if (_interpreter != null && _loadedModelKey == modelKey) {
      return;
    }

    _interpreter?.close();
    try {
      _interpreter = await _openInterpreter(config);
      _loadedModelKey = modelKey;
    } catch (_) {
      _interpreter = null;
      _loadedModelKey = null;
      throw StateError(
        'Model TFLite tidak dapat dimuat. Periksa aset model dan konfigurasi versi model.',
      );
    }
  }

  Future<Interpreter> _openInterpreter(ClassificationConfig config) async {
    if (config.useRemoteModel &&
        config.remoteModelStoragePath?.isNotEmpty == true &&
        !kIsWeb) {
      final file = File(
        '${Directory.systemTemp.path}/${config.activeModelVersion}.tflite',
      );
      await _storage.ref(config.remoteModelStoragePath!).writeToFile(file);
      return Interpreter.fromFile(file);
    }

    return Interpreter.fromAsset(config.modelAssetPath);
  }

  bool get isFloatInput {
    final interpreter = _requiredInterpreter();
    return interpreter.getInputTensor(0).type == TensorType.float32;
  }

  int get outputCount {
    final shape = _requiredInterpreter().getOutputTensor(0).shape;
    if (shape.isEmpty) return 0;
    return shape.last;
  }

  ClassificationPrediction run({
    required Object modelInput,
    required List<String> labels,
    required ClassificationConfig config,
  }) {
    final interpreter = _requiredInterpreter();
    final count = outputCount;
    if (count <= 0) {
      throw StateError('Output model tidak valid.');
    }
    if (labels.length != count) {
      throw StateError(
        'Jumlah label (${labels.length}) tidak cocok dengan output model '
        '($count). Periksa labels.txt atau label_map/${config.activeModelVersion}.',
      );
    }

    final rawOutput = _runOutput(interpreter, modelInput, count);
    final probabilities = _asProbabilities(rawOutput);
    final ranked = <TopPrediction>[
      for (var i = 0; i < probabilities.length; i++)
        TopPrediction(
          labelIndex: i,
          speciesId: labels[i],
          confidence: probabilities[i],
        ),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    final topPredictions = ranked.take(config.topK).toList();
    final ood = _oodService.evaluate(
      probabilities: probabilities,
      minConfidenceWarning: config.minConfidenceWarning,
      oodThreshold: config.oodThreshold,
    );

    return ClassificationPrediction(
      modelVersion: config.activeModelVersion,
      outputCount: count,
      topPredictions: topPredictions,
      ood: ood,
    );
  }

  List<double> _asProbabilities(List<double> raw) {
    final looksLikeProbability =
        raw.every((value) => value >= 0 && value <= 1) &&
            raw.fold<double>(0, (sum, value) => sum + value) > 0.95 &&
            raw.fold<double>(0, (sum, value) => sum + value) < 1.05;

    if (looksLikeProbability) {
      return raw.map((value) => value.clamp(0.0, 1.0).toDouble()).toList();
    }

    final maxLogit = raw.reduce(math.max);
    final exps = raw.map((value) => math.exp(value - maxLogit)).toList();
    final sum = exps.fold<double>(0, (total, value) => total + value);
    if (sum == 0) return List<double>.filled(raw.length, 0);
    return exps.map((value) => value / sum).toList();
  }

  List<double> _runOutput(
    Interpreter interpreter,
    Object modelInput,
    int count,
  ) {
    final outputTensor = interpreter.getOutputTensor(0);
    if (outputTensor.type == TensorType.float32 ||
        outputTensor.type == TensorType.float64) {
      final output = List.generate(1, (_) => List<double>.filled(count, 0));
      interpreter.run(modelInput, output);
      return output.first;
    }

    final output = List.generate(1, (_) => List<int>.filled(count, 0));
    interpreter.run(modelInput, output);
    final scale = outputTensor.params.scale;
    final zeroPoint = outputTensor.params.zeroPoint;
    if (scale > 0 &&
        (outputTensor.type == TensorType.uint8 ||
            outputTensor.type == TensorType.int8 ||
            outputTensor.type == TensorType.int16)) {
      return output.first
          .map((value) => ((value - zeroPoint) * scale).toDouble())
          .toList();
    }
    return output.first.map((value) => value.toDouble()).toList();
  }

  Interpreter _requiredInterpreter() {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Model TFLite belum dimuat.');
    }
    return interpreter;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loadedModelKey = null;
  }
}
