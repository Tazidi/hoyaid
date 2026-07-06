import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hoyaid/features/classification/models/classification_models.dart';

class ClassificationService {
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  ClassificationService({
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Future<SavedClassification> saveClassification({
    required ClassificationPrediction prediction,
    required Uint8List displayJpegBytes,
    required int displayImageSize,
    required int modelImageSize,
    ClassificationLocation? location,
  }) async {
    final createData = await _createPendingClassification(
      prediction: prediction,
      displayImageSize: displayImageSize,
      modelImageSize: modelImageSize,
      location: location,
    );
    final classificationId = createData['classificationId']?.toString();
    final imageStoragePath = createData['imageStoragePath']?.toString();
    if (classificationId == null ||
        classificationId.isEmpty ||
        imageStoragePath == null ||
        imageStoragePath.isEmpty) {
      throw StateError('Respons createClassification tidak lengkap.');
    }

    final imageRef = _storage.ref(imageStoragePath);
    try {
      await imageRef
          .putData(
            displayJpegBytes,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'classificationId': classificationId,
                'displaySize': '${displayImageSize}x$displayImageSize',
              },
            ),
          )
          .timeout(const Duration(minutes: 2));
    } catch (error) {
      throw ClassificationSaveException(
        stage: ClassificationSaveStage.uploadImage,
        classificationId: classificationId,
        imageStoragePath: imageStoragePath,
        cause: error,
      );
    }

    final finalize = _functions.httpsCallable('finalizeClassification');
    final HttpsCallableResult<Map<String, dynamic>> finalizeResult;
    try {
      finalizeResult = await finalize
          .call<Map<String, dynamic>>({
            'classificationId': classificationId,
          })
          .timeout(const Duration(seconds: 45));
    } catch (error) {
      throw ClassificationSaveException(
        stage: ClassificationSaveStage.finalize,
        classificationId: classificationId,
        imageStoragePath: imageStoragePath,
        cause: error,
      );
    }
    final finalizeData = Map<String, dynamic>.from(finalizeResult.data);

    return SavedClassification(
      classificationId: classificationId,
      imageStoragePath: imageStoragePath,
      imageUrl: finalizeData['imageUrl']?.toString() ?? '',
    );
  }

  Future<Map<String, dynamic>> _createPendingClassification({
    required ClassificationPrediction prediction,
    required int displayImageSize,
    required int modelImageSize,
    ClassificationLocation? location,
  }) async {
    final create = _functions.httpsCallable('createClassification');
    try {
      final createResult = await create
          .call<Map<String, dynamic>>({
            'speciesId': prediction.speciesId,
            'modelPredictedSpeciesId': prediction.speciesId,
            'confidence': prediction.confidence,
            'oodScore': prediction.ood.score,
            'topPredictions':
                prediction.topPredictions.map((item) => item.toMap()).toList(),
            'modelVersion': prediction.modelVersion,
            'imageSizeForModel': '${modelImageSize}x$modelImageSize',
            'imageSizeForDisplay': '${displayImageSize}x$displayImageSize',
            'location': location?.toCallableMap(),
          })
          .timeout(const Duration(seconds: 45));
      return Map<String, dynamic>.from(createResult.data);
    } catch (error) {
      throw ClassificationSaveException(
        stage: ClassificationSaveStage.createMetadata,
        cause: error,
      );
    }
  }
}

enum ClassificationSaveStage {
  createMetadata,
  uploadImage,
  finalize,
}

class ClassificationSaveException implements Exception {
  final ClassificationSaveStage stage;
  final String? classificationId;
  final String? imageStoragePath;
  final Object cause;

  const ClassificationSaveException({
    required this.stage,
    this.classificationId,
    this.imageStoragePath,
    required this.cause,
  });

  bool get hasPendingDocument =>
      stage == ClassificationSaveStage.uploadImage ||
      stage == ClassificationSaveStage.finalize;

  @override
  String toString() {
    return cause.toString();
  }
}
