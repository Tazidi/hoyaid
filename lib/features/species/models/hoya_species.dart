import 'package:cloud_firestore/cloud_firestore.dart';

class HoyaSpecies {
  final String speciesId;
  final String scientificName;
  final String? localName;
  final String distribution;
  final String description;
  final bool hasMedicalUse;
  final String medicalUse;
  final String medicalUseDescription;
  final String? referenceImageUrl;
  final String? referenceImageSourcePath;
  final String? referenceStoragePath;
  final bool isRare;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const HoyaSpecies({
    required this.speciesId,
    required this.scientificName,
    this.localName,
    required this.distribution,
    required this.description,
    required this.hasMedicalUse,
    required this.medicalUse,
    required this.medicalUseDescription,
    this.referenceImageUrl,
    this.referenceImageSourcePath,
    this.referenceStoragePath,
    required this.isRare,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  String get displayName =>
      scientificName.trim().isEmpty ? speciesId : scientificName.trim();

  String get sortKey => displayName
      .replaceFirst(RegExp(r'^hoya\s+', caseSensitive: false), '')
      .toLowerCase();

  String get searchText => [
        speciesId,
        scientificName,
        localName ?? '',
        distribution,
        description,
      ].join(' ').toLowerCase();

  factory HoyaSpecies.empty({String speciesId = ''}) {
    return HoyaSpecies(
      speciesId: speciesId,
      scientificName: '',
      localName: '',
      distribution: '-',
      description: '-',
      hasMedicalUse: false,
      medicalUse: '-',
      medicalUseDescription: '-',
      isRare: false,
      isActive: true,
    );
  }

  factory HoyaSpecies.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return HoyaSpecies.fromMap(snapshot.data() ?? {}, documentId: snapshot.id);
  }

  factory HoyaSpecies.fromMap(
    Map<String, dynamic> data, {
    String? documentId,
  }) {
    String readString(String key, [String fallback = '']) {
      final value = data[key];
      if (value == null) return fallback;
      return value.toString();
    }

    String? readOptionalString(String key) {
      final value = data[key];
      if (value == null || value.toString().trim().isEmpty) return null;
      return value.toString();
    }

    bool readBool(String key, {bool fallback = false}) {
      final value = data[key];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return fallback;
    }

    DateTime? readDate(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final medicalUseDescription = readString(
      'medicalUseDescription',
      readString('medicalUse', '-'),
    );

    return HoyaSpecies(
      speciesId: readString('speciesId', documentId ?? ''),
      scientificName: readString('scientificName', documentId ?? ''),
      localName: readOptionalString('localName'),
      distribution: readString('distribution', '-'),
      description: readString('description', '-'),
      hasMedicalUse: readBool('hasMedicalUse'),
      medicalUse: readString('medicalUse', medicalUseDescription),
      medicalUseDescription: medicalUseDescription,
      referenceImageUrl: readOptionalString('referenceImageUrl'),
      referenceImageSourcePath: readOptionalString('referenceImageSourcePath'),
      referenceStoragePath: readOptionalString('referenceStoragePath'),
      isRare: readBool('isRare'),
      isActive: readBool('isActive', fallback: true),
      createdAt: readDate('createdAt'),
      updatedAt: readDate('updatedAt'),
      createdBy: readOptionalString('createdBy'),
      updatedBy: readOptionalString('updatedBy'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'speciesId': speciesId,
      'scientificName': scientificName,
      'localName': localName,
      'distribution': distribution,
      'description': description,
      'hasMedicalUse': hasMedicalUse,
      'medicalUse': medicalUse,
      'medicalUseDescription': medicalUseDescription,
      'referenceImageUrl': referenceImageUrl,
      'referenceImageSourcePath': referenceImageSourcePath,
      'referenceStoragePath': referenceStoragePath,
      'isRare': isRare,
      'isActive': isActive,
    };
  }

  HoyaSpecies copyWith({
    String? speciesId,
    String? scientificName,
    String? localName,
    String? distribution,
    String? description,
    bool? hasMedicalUse,
    String? medicalUse,
    String? medicalUseDescription,
    String? referenceImageUrl,
    String? referenceImageSourcePath,
    String? referenceStoragePath,
    bool? isRare,
    bool? isActive,
  }) {
    return HoyaSpecies(
      speciesId: speciesId ?? this.speciesId,
      scientificName: scientificName ?? this.scientificName,
      localName: localName ?? this.localName,
      distribution: distribution ?? this.distribution,
      description: description ?? this.description,
      hasMedicalUse: hasMedicalUse ?? this.hasMedicalUse,
      medicalUse: medicalUse ?? this.medicalUse,
      medicalUseDescription:
          medicalUseDescription ?? this.medicalUseDescription,
      referenceImageUrl: referenceImageUrl ?? this.referenceImageUrl,
      referenceImageSourcePath:
          referenceImageSourcePath ?? this.referenceImageSourcePath,
      referenceStoragePath: referenceStoragePath ?? this.referenceStoragePath,
      isRare: isRare ?? this.isRare,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }
}
