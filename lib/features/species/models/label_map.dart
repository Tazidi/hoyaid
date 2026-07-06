import 'package:cloud_firestore/cloud_firestore.dart';

class LabelMapEntry {
  final int labelIndex;
  final String speciesId;

  const LabelMapEntry({
    required this.labelIndex,
    required this.speciesId,
  });

  factory LabelMapEntry.fromMap(Map<String, dynamic> data) {
    return LabelMapEntry(
      labelIndex: (data['labelIndex'] as num?)?.toInt() ?? 0,
      speciesId: data['speciesId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'labelIndex': labelIndex,
      'speciesId': speciesId,
    };
  }
}

class LabelMapModel {
  final String modelVersion;
  final String? modelAssetPath;
  final String? labelsAssetPath;
  final bool isActive;
  final List<LabelMapEntry> labels;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LabelMapModel({
    required this.modelVersion,
    this.modelAssetPath,
    this.labelsAssetPath,
    required this.isActive,
    required this.labels,
    this.createdAt,
    this.updatedAt,
  });

  int get labelCount => labels.length;

  factory LabelMapModel.empty({String modelVersion = 'hoya_model_v1'}) {
    return LabelMapModel(
      modelVersion: modelVersion,
      modelAssetPath: 'assets/models/hoya_model_v1.tflite',
      labelsAssetPath: 'assets/models/labels.txt',
      isActive: true,
      labels: const [],
    );
  }

  factory LabelMapModel.fromLabels({
    required String modelVersion,
    required List<String> speciesIds,
  }) {
    return LabelMapModel(
      modelVersion: modelVersion,
      modelAssetPath: 'assets/models/$modelVersion.tflite',
      labelsAssetPath: 'assets/models/labels.txt',
      isActive: true,
      labels: [
        for (var index = 0; index < speciesIds.length; index++)
          LabelMapEntry(labelIndex: index, speciesId: speciesIds[index]),
      ],
    );
  }

  factory LabelMapModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return LabelMapModel.fromMap(snapshot.data() ?? {}, snapshot.id);
  }

  factory LabelMapModel.fromMap(Map<String, dynamic> data, String documentId) {
    DateTime? readDate(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final rawLabels = data['labels'];
    final labels = rawLabels is List
        ? rawLabels
            .whereType<Map>()
            .map((item) => LabelMapEntry.fromMap(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ))
            .toList()
        : <LabelMapEntry>[];
    labels.sort((a, b) => a.labelIndex.compareTo(b.labelIndex));

    return LabelMapModel(
      modelVersion: data['modelVersion']?.toString() ?? documentId,
      modelAssetPath: data['modelAssetPath']?.toString(),
      labelsAssetPath: data['labelsAssetPath']?.toString(),
      isActive: data['isActive'] != false,
      labels: labels,
      createdAt: readDate('createdAt'),
      updatedAt: readDate('updatedAt'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'modelVersion': modelVersion,
      'modelAssetPath': modelAssetPath,
      'labelsAssetPath': labelsAssetPath,
      'labelCount': labels.length,
      'isActive': isActive,
      'labels': labels.map((entry) => entry.toMap()).toList(),
    };
  }
}
