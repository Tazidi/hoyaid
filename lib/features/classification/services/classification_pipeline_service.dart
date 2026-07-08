import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:hoyaid/features/classification/services/classification_config_service.dart';
import 'package:hoyaid/features/classification/services/image_preprocess_service.dart';
import 'package:hoyaid/features/classification/services/image_quality_service.dart';
import 'package:hoyaid/features/classification/services/label_map_service.dart';
import 'package:hoyaid/features/classification/services/location_service.dart';
import 'package:hoyaid/features/classification/services/tflite_service.dart';

class ClassificationPipelineService {
  final ClassificationConfigService _configService;
  final LabelMapService _labelMapService;
  final ImagePreprocessService _imagePreprocessService;
  final ImageQualityService _imageQualityService;
  final TFLiteService _tfliteService;
  final LocationService _locationService;

  ClassificationPipelineService({
    ClassificationConfigService? configService,
    LabelMapService? labelMapService,
    ImagePreprocessService? imagePreprocessService,
    ImageQualityService? imageQualityService,
    TFLiteService? tfliteService,
    LocationService? locationService,
  })  : _configService = configService ?? ClassificationConfigService(),
        _labelMapService = labelMapService ?? LabelMapService(),
        _imagePreprocessService =
            imagePreprocessService ?? ImagePreprocessService(),
        _imageQualityService = imageQualityService ?? ImageQualityService(),
        _tfliteService = tfliteService ?? TFLiteService(),
        _locationService = locationService ?? LocationService();

  Future<ClassificationDraft> classifyImage(String imagePath) async {
    final config = await _configService.getConfig();
    await _tfliteService.loadModel(config);
    final labels = await _labelMapService.resolveLabels(config);
    final imageQuality = await _imageQualityService.analyzeFile(imagePath);
    final processed = await _imagePreprocessService.processFile(
      imagePath: imagePath,
      modelSize: config.inputSize,
      displaySize: config.displaySize,
      floatInput: _tfliteService.isFloatInput,
      maxImageSizeMb: config.maxImageSizeMb,
      enhanceLowLight: imageQuality.needsBrightnessEnhancement,
    );
    final prediction = _tfliteService.run(
      modelInput: processed.modelInput,
      labels: labels,
      config: config,
    );

    final location = await _tryReadLocation();
    return ClassificationDraft(
      sourceImagePath: imagePath,
      displayJpegBytes: processed.displayJpegBytes,
      prediction: prediction,
      initialLocation: location,
      createdAt: DateTime.now(),
      modelImageSize: processed.modelSize,
      displayImageSize: processed.displaySize,
      imageQuality: imageQuality,
      enhancementApplied: processed.enhancementApplied,
    );
  }

  Future<ClassificationLocation?> _tryReadLocation() async {
    try {
      return await _locationService.getCurrentLocation();
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _tfliteService.dispose();
  }
}
