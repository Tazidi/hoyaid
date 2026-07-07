import 'dart:typed_data';

class TopPrediction {
  final int labelIndex;
  final String speciesId;
  final double confidence;

  const TopPrediction({
    required this.labelIndex,
    required this.speciesId,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'labelIndex': labelIndex,
      'speciesId': speciesId,
      'confidence': confidence,
    };
  }
}

enum OodLevel {
  ok,
  uncertain,
  rejected,
}

class OodEvaluation {
  final double score;
  final double entropy;
  final double topMargin;
  final bool isLowConfidence;
  final bool isLikelyOod;
  final OodLevel level;

  const OodEvaluation({
    required this.score,
    required this.entropy,
    required this.topMargin,
    required this.isLowConfidence,
    required this.isLikelyOod,
    required this.level,
  });
}

class ClassificationPrediction {
  final String modelVersion;
  final int outputCount;
  final List<TopPrediction> topPredictions;
  final OodEvaluation ood;

  const ClassificationPrediction({
    required this.modelVersion,
    required this.outputCount,
    required this.topPredictions,
    required this.ood,
  });

  TopPrediction get topPrediction => topPredictions.first;
  String get speciesId => topPrediction.speciesId;
  double get confidence => topPrediction.confidence;
}

class ProcessedImage {
  final Uint8List displayJpegBytes;
  final Object modelInput;
  final int modelSize;
  final int displaySize;

  const ProcessedImage({
    required this.displayJpegBytes,
    required this.modelInput,
    required this.modelSize,
    required this.displaySize,
  });
}

enum ClassificationLocationSource {
  gps,
  manual,
}

class ClassificationLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final ClassificationLocationSource source;

  const ClassificationLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.source,
  });

  String get sourceValue {
    switch (source) {
      case ClassificationLocationSource.gps:
        return 'gps';
      case ClassificationLocationSource.manual:
        return 'manual';
    }
  }

  String get label {
    final base =
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    if (accuracy == null) return base;
    return '$base (akurasi ${accuracy!.round()} m)';
  }

  Map<String, dynamic> toCallableMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'source': sourceValue,
    };
  }
}

class ClassificationDraft {
  final String sourceImagePath;
  final Uint8List displayJpegBytes;
  final ClassificationPrediction prediction;
  final ClassificationLocation? initialLocation;
  final DateTime createdAt;
  final int modelImageSize;
  final int displayImageSize;

  const ClassificationDraft({
    required this.sourceImagePath,
    required this.displayJpegBytes,
    required this.prediction,
    required this.initialLocation,
    required this.createdAt,
    required this.modelImageSize,
    required this.displayImageSize,
  });
}

class SavedClassification {
  final String classificationId;
  final String imageStoragePath;
  final String imageUrl;

  const SavedClassification({
    required this.classificationId,
    required this.imageStoragePath,
    required this.imageUrl,
  });
}
