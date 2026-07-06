class ClassificationConfig {
  final String activeModelVersion;
  final bool useRemoteModel;
  final String modelAssetPath;
  final String? remoteModelStoragePath;
  final String? remoteModelDownloadUrl;
  final String labelsAssetPath;
  final int inputSize;
  final int displaySize;
  final int topK;
  final double minConfidenceWarning;
  final double oodThreshold;
  final int publicCoordPrecision;
  final int rareCoordPrecision;
  final int maxImageSizeMb;

  const ClassificationConfig({
    required this.activeModelVersion,
    required this.useRemoteModel,
    required this.modelAssetPath,
    this.remoteModelStoragePath,
    this.remoteModelDownloadUrl,
    required this.labelsAssetPath,
    required this.inputSize,
    required this.displaySize,
    required this.topK,
    required this.minConfidenceWarning,
    required this.oodThreshold,
    required this.publicCoordPrecision,
    required this.rareCoordPrecision,
    required this.maxImageSizeMb,
  });

  factory ClassificationConfig.fallback() {
    return const ClassificationConfig(
      activeModelVersion: 'hoya_model_v1',
      useRemoteModel: false,
      modelAssetPath: 'assets/models/hoya_model_v1.tflite',
      remoteModelStoragePath: null,
      remoteModelDownloadUrl: null,
      labelsAssetPath: 'assets/models/labels.txt',
      inputSize: 224,
      displaySize: 640,
      topK: 3,
      minConfidenceWarning: 0.70,
      oodThreshold: 0.60,
      publicCoordPrecision: 2,
      rareCoordPrecision: 1,
      maxImageSizeMb: 5,
    );
  }

  factory ClassificationConfig.fromMap(Map<String, dynamic>? data) {
    final fallback = ClassificationConfig.fallback();
    if (data == null) return fallback;

    int readInt(String key, int defaultValue) {
      final value = data[key];
      if (value is num) return value.toInt();
      return defaultValue;
    }

    double readDouble(String key, double defaultValue) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return defaultValue;
    }

    String readString(String key, String defaultValue) {
      final value = data[key];
      if (value == null || value.toString().trim().isEmpty) {
        return defaultValue;
      }
      return value.toString();
    }

    return ClassificationConfig(
      activeModelVersion: readString(
        'activeModelVersion',
        fallback.activeModelVersion,
      ),
      useRemoteModel: data['useRemoteModel'] == true,
      modelAssetPath: readString('modelAssetPath', fallback.modelAssetPath),
      remoteModelStoragePath: data['remoteModelStoragePath']?.toString(),
      remoteModelDownloadUrl: data['remoteModelDownloadUrl']?.toString(),
      labelsAssetPath: readString('labelsAssetPath', fallback.labelsAssetPath),
      inputSize: readInt('classificationImageSize', fallback.inputSize),
      displaySize: readInt('displayImageSize', fallback.displaySize),
      topK: readInt('topK', fallback.topK),
      minConfidenceWarning: readDouble(
        'minConfidenceWarning',
        fallback.minConfidenceWarning,
      ),
      oodThreshold: readDouble('oodThreshold', fallback.oodThreshold),
      publicCoordPrecision: readInt(
        'publicCoordPrecision',
        fallback.publicCoordPrecision,
      ),
      rareCoordPrecision: readInt(
        'rareCoordPrecision',
        fallback.rareCoordPrecision,
      ),
      maxImageSizeMb: readInt('maxImageSizeMb', fallback.maxImageSizeMb),
    );
  }
}
