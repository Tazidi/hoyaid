import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:hoyaid/features/classification/services/classification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineClassificationQueueService {
  static const queueKey = 'offline_classification_queue_v1';

  final ClassificationService _classificationService;
  bool _isSyncing = false;

  OfflineClassificationQueueService({
    ClassificationService? classificationService,
  }) : _classificationService =
            classificationService ?? ClassificationService();

  Future<OfflineClassificationItem> enqueue({
    required String userId,
    required ClassificationPrediction prediction,
    required List<int> displayJpegBytes,
    required int displayImageSize,
    required int modelImageSize,
    ClassificationLocation? location,
  }) async {
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final dir = await _offlineImageDir();
    final imageFile = File('${dir.path}${Platform.pathSeparator}$id.jpg');
    await imageFile.writeAsBytes(displayJpegBytes, flush: true);

    final item = OfflineClassificationItem(
      id: id,
      userId: userId,
      imagePath: imageFile.path,
      prediction: prediction,
      displayImageSize: displayImageSize,
      modelImageSize: modelImageSize,
      location: location,
      createdAt: DateTime.now(),
      status: OfflineClassificationStatus.pendingUpload,
    );
    final items = await pendingItems();
    await _saveItems([...items, item]);
    return item;
  }

  Future<List<OfflineClassificationItem>> pendingItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(queueKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List;
    return list
        .map((item) => OfflineClassificationItem.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.status != OfflineClassificationStatus.synced)
        .toList();
  }

  Future<int> syncPending() async {
    if (_isSyncing || !await _isOnline()) return 0;
    _isSyncing = true;
    var synced = 0;
    try {
      var items = await pendingItems();
      for (final item in items) {
        final imageFile = File(item.imagePath);
        if (!await imageFile.exists()) continue;
        try {
          await _classificationService.saveClassification(
            prediction: item.prediction,
            displayJpegBytes: await imageFile.readAsBytes(),
            displayImageSize: item.displayImageSize,
            modelImageSize: item.modelImageSize,
            location: item.location,
          );
          try {
            await imageFile.delete();
          } catch (_) {}
          items = items
              .where((queued) => queued.id != item.id)
              .toList(growable: false);
          await _saveItems(items);
          synced++;
        } catch (_) {
          break;
        }
      }
      return synced;
    } finally {
      _isSyncing = false;
    }
  }

  StreamSubscription<List<ConnectivityResult>> startAutoSync() {
    unawaited(syncPending());
    return Connectivity().onConnectivityChanged.listen((_) {
      unawaited(syncPending());
    });
  }

  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<Directory> _offlineImageDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(
        '${root.path}${Platform.pathSeparator}offline_classifications');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _saveItems(List<OfflineClassificationItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      queueKey,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
  }
}

enum OfflineClassificationStatus { pendingUpload, synced }

class OfflineClassificationItem {
  final String id;
  final String userId;
  final String imagePath;
  final ClassificationPrediction prediction;
  final int displayImageSize;
  final int modelImageSize;
  final ClassificationLocation? location;
  final DateTime createdAt;
  final OfflineClassificationStatus status;

  const OfflineClassificationItem({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.prediction,
    required this.displayImageSize,
    required this.modelImageSize,
    required this.location,
    required this.createdAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'imagePath': imagePath,
      'prediction': prediction.toMap(),
      'displayImageSize': displayImageSize,
      'modelImageSize': modelImageSize,
      'location': location?.toCallableMap(),
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
    };
  }

  factory OfflineClassificationItem.fromMap(Map<String, dynamic> data) {
    final location = data['location'];
    return OfflineClassificationItem(
      id: data['id'].toString(),
      userId: data['userId'].toString(),
      imagePath: data['imagePath'].toString(),
      prediction: ClassificationPrediction.fromMap(
        Map<String, dynamic>.from(data['prediction']),
      ),
      displayImageSize: (data['displayImageSize'] as num).toInt(),
      modelImageSize: (data['modelImageSize'] as num).toInt(),
      location: location == null
          ? null
          : ClassificationLocation.fromMap(Map<String, dynamic>.from(location)),
      createdAt: DateTime.parse(data['createdAt'].toString()),
      status: OfflineClassificationStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => OfflineClassificationStatus.pendingUpload,
      ),
    );
  }
}
