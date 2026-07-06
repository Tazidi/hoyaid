import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:hoyaid/features/classification/services/classification_config_service.dart';
import 'package:hoyaid/features/classification/services/image_preprocess_service.dart';
import 'package:hoyaid/features/classification/services/label_map_service.dart';
import 'package:hoyaid/features/classification/services/location_service.dart';
import 'package:hoyaid/features/classification/services/tflite_service.dart';

class ClassificationPipelineService {
  final ClassificationConfigService _configService;
  final LabelMapService _labelMapService;
  final ImagePreprocessService _imagePreprocessService;
  final TFLiteService _tfliteService;
  final LocationService _locationService;

  ClassificationPipelineService({
    ClassificationConfigService? configService,
    LabelMapService? labelMapService,
    ImagePreprocessService? imagePreprocessService,
    TFLiteService? tfliteService,
    LocationService? locationService,
  })  : _configService = configService ?? ClassificationConfigService(),
        _labelMapService = labelMapService ?? LabelMapService(),
        _imagePreprocessService =
            imagePreprocessService ?? ImagePreprocessService(),
        _tfliteService = tfliteService ?? TFLiteService(),
        _locationService = locationService ?? LocationService();

  Future<ClassificationDraft> classifyImage(String imagePath) async {
    final config = await _configService.getConfig();
    await _tfliteService.loadModel(config);
    final labels = await _labelMapService.resolveLabels(config);
    final processed = await _imagePreprocessService.processFile(
      imagePath: imagePath,
      modelSize: config.inputSize,
      displaySize: config.displaySize,
      floatInput: _tfliteService.isFloatInput,
      maxImageSizeMb: config.maxImageSizeMb,
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
