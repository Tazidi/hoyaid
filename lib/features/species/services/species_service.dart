import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/models/label_map.dart';

class SpeciesService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;

  SpeciesService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _imagePicker = imagePicker ?? ImagePicker();

  CollectionReference<Map<String, dynamic>> get _speciesCollection =>
      _firestore.collection('species');

  CollectionReference<Map<String, dynamic>> get _labelMapCollection =>
      _firestore.collection('label_map');

  Stream<List<HoyaSpecies>> watchActiveSpecies() {
    return _speciesCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_speciesFromSnapshot);
  }

  Stream<List<HoyaSpecies>> watchAllSpecies() {
    return _speciesCollection.snapshots().map(_speciesFromSnapshot);
  }

  Stream<HoyaSpecies?> watchSpecies(String speciesId) {
    return _speciesCollection.doc(speciesId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return HoyaSpecies.fromSnapshot(snapshot);
    });
  }

  Future<void> saveSpecies(HoyaSpecies species, {String? actorId}) async {
    final docRef = _speciesCollection.doc(species.speciesId);
    final snapshot = await docRef.get();
    final now = FieldValue.serverTimestamp();
    final data = {
      ...species.toFirestore(),
      'updatedAt': now,
      'updatedBy': actorId ?? 'admin',
    };

    if (!snapshot.exists) {
      data['createdAt'] = now;
      data['createdBy'] = actorId ?? 'admin';
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> setSpeciesActive(
    String speciesId,
    bool isActive, {
    String? actorId,
  }) async {
    await _speciesCollection.doc(speciesId).set({
      'speciesId': speciesId,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorId ?? 'admin',
    }, SetOptions(merge: true));
  }

  Future<XFile?> pickReferenceImage() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1800,
    );
  }

  Future<ReferenceImageUpload> uploadReferenceImage({
    required String speciesId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = _extensionFor(image.name);
    final storagePath = 'species_images/$speciesId/reference.$extension';
    final ref = _storage.ref(storagePath);

    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: _contentTypeFor(extension)),
    );

    final url = await ref.getDownloadURL();
    return ReferenceImageUpload(url: url, storagePath: storagePath);
  }

  Stream<LabelMapModel?> watchLabelMap(String modelVersion) {
    return _labelMapCollection.doc(modelVersion).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return LabelMapModel.fromSnapshot(snapshot);
    });
  }

  Future<void> saveLabelMap(LabelMapModel labelMap, {String? actorId}) async {
    final docRef = _labelMapCollection.doc(labelMap.modelVersion);
    final snapshot = await docRef.get();
    final now = FieldValue.serverTimestamp();
    final data = {
      ...labelMap.toFirestore(),
      'updatedAt': now,
      'updatedBy': actorId ?? 'admin',
    };

    if (!snapshot.exists) {
      data['createdAt'] = now;
      data['createdBy'] = actorId ?? 'admin';
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  List<HoyaSpecies> _speciesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = snapshot.docs.map(HoyaSpecies.fromSnapshot).toList();
    items.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return items;
  }

  String _extensionFor(String fileName) {
    final parts = fileName.toLowerCase().split('.');
    final extension = parts.length > 1 ? parts.last : 'jpg';
    if (extension == 'jpeg' || extension == 'png' || extension == 'webp') {
      return extension;
    }
    return 'jpg';
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'image/jpeg';
    }
  }
}

class ReferenceImageUpload {
  final String url;
  final String storagePath;

  const ReferenceImageUpload({
    required this.url,
    required this.storagePath,
  });
}
