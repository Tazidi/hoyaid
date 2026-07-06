import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/features/classification/services/camera_permission_service.dart';
import 'package:hoyaid/features/classification/services/classification_config_service.dart';
import 'package:hoyaid/features/classification/services/classification_pipeline_service.dart';
import 'package:hoyaid/features/classification/services/classification_service.dart';
import 'package:hoyaid/features/classification/services/image_preprocess_service.dart';
import 'package:hoyaid/features/classification/services/label_map_service.dart';
import 'package:hoyaid/features/classification/services/location_service.dart';
import 'package:hoyaid/features/classification/services/ood_service.dart';
import 'package:hoyaid/features/classification/services/tflite_service.dart';

final classificationConfigServiceProvider =
    Provider<ClassificationConfigService>((ref) {
  return ClassificationConfigService();
});

final labelMapServiceProvider = Provider<LabelMapService>((ref) {
  return LabelMapService();
});

final imagePreprocessServiceProvider = Provider<ImagePreprocessService>((ref) {
  return ImagePreprocessService();
});

final oodServiceProvider = Provider<OodService>((ref) {
  return OodService();
});

final tfliteServiceProvider = Provider<TFLiteService>((ref) {
  final service = TFLiteService(oodService: ref.watch(oodServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final cameraPermissionServiceProvider =
    Provider<CameraPermissionService>((ref) {
  return CameraPermissionService();
});

final classificationPipelineServiceProvider =
    Provider<ClassificationPipelineService>((ref) {
  return ClassificationPipelineService(
    configService: ref.watch(classificationConfigServiceProvider),
    labelMapService: ref.watch(labelMapServiceProvider),
    imagePreprocessService: ref.watch(imagePreprocessServiceProvider),
    tfliteService: ref.watch(tfliteServiceProvider),
    locationService: ref.watch(locationServiceProvider),
  );
});

final classificationServiceProvider = Provider<ClassificationService>((ref) {
  return ClassificationService();
});
