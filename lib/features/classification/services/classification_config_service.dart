import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hoyaid/features/classification/models/classification_config.dart';

class ClassificationConfigService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  ClassificationConfigService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Future<ClassificationConfig> getConfig() async {
    try {
      final snapshot =
          await _firestore.collection('app_config').doc('general').get();
      return ClassificationConfig.fromMap(snapshot.data());
    } catch (_) {
      return ClassificationConfig.fallback();
    }
  }

  Future<void> uploadModelVersion({
    required String version,
    required String fileName,
    required List<int> bytes,
  }) async {
    final normalizedVersion = version.trim();
    if (normalizedVersion.isEmpty) {
      throw ArgumentError('Versi model wajib diisi.');
    }
    if (!fileName.toLowerCase().endsWith('.tflite')) {
      throw ArgumentError('File model harus berformat .tflite.');
    }

    final storagePath = 'models/$normalizedVersion/$fileName';
    final modelRef = _storage.ref(storagePath);
    await modelRef.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(
        contentType: 'application/octet-stream',
        customMetadata: {
          'modelVersion': normalizedVersion,
          'fileName': fileName,
        },
      ),
    );
    final downloadUrl = await modelRef.getDownloadURL();

    await _firestore.collection('app_config').doc('general').set({
      'activeModelVersion': normalizedVersion,
      'useRemoteModel': true,
      'remoteModelStoragePath': storagePath,
      'remoteModelDownloadUrl': downloadUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
