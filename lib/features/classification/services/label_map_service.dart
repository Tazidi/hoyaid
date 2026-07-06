import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:hoyaid/features/classification/models/classification_config.dart';
import 'package:hoyaid/features/species/models/label_map.dart';

class LabelMapService {
  final FirebaseFirestore _firestore;
  final AssetBundle _assetBundle;

  LabelMapService({
    FirebaseFirestore? firestore,
    AssetBundle? assetBundle,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _assetBundle = assetBundle ?? rootBundle;

  Future<List<String>> resolveLabels(ClassificationConfig config) async {
    final firestoreLabels =
        await _readFirestoreLabels(config.activeModelVersion);
    if (firestoreLabels.isNotEmpty) return firestoreLabels;
    return _readAssetLabels(config.labelsAssetPath);
  }

  Future<List<String>> _readFirestoreLabels(String modelVersion) async {
    try {
      final snapshot =
          await _firestore.collection('label_map').doc(modelVersion).get();
      if (!snapshot.exists) return const [];

      final labelMap = LabelMapModel.fromSnapshot(snapshot);
      final labels = labelMap.labels
          .where((entry) => entry.speciesId.trim().isNotEmpty)
          .toList()
        ..sort((a, b) => a.labelIndex.compareTo(b.labelIndex));
      return labels.map((entry) => entry.speciesId).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _readAssetLabels(String labelsAssetPath) async {
    final raw = await _assetBundle.loadString(labelsAssetPath);
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
  }
}
