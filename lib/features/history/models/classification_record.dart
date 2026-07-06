import 'package:cloud_firestore/cloud_firestore.dart';

enum ClassificationSortOrder {
  newest,
  oldest,
}

enum ClassificationScope {
  mine,
  public,
}

class HistoryFilter {
  final String? speciesId;
  final String? confidenceBucket;
  final String? dateBucket;
  final String? verificationStatus;
  final bool? hasLocation;
  final String? userId;
  final ClassificationSortOrder sortOrder;

  const HistoryFilter({
    this.speciesId,
    this.confidenceBucket,
    this.dateBucket,
    this.verificationStatus,
    this.hasLocation,
    this.userId,
    this.sortOrder = ClassificationSortOrder.newest,
  });

  bool get hasActiveFilters =>
      speciesId != null ||
      confidenceBucket != null ||
      dateBucket != null ||
      verificationStatus != null ||
      hasLocation != null ||
      userId != null;

  HistoryFilter copyWith({
    String? speciesId,
    String? confidenceBucket,
    String? dateBucket,
    String? verificationStatus,
    bool? hasLocation,
    String? userId,
    ClassificationSortOrder? sortOrder,
    bool clearSpeciesId = false,
    bool clearConfidenceBucket = false,
    bool clearDateBucket = false,
    bool clearVerificationStatus = false,
    bool clearHasLocation = false,
    bool clearUserId = false,
  }) {
    return HistoryFilter(
      speciesId: clearSpeciesId ? null : speciesId ?? this.speciesId,
      confidenceBucket: clearConfidenceBucket
          ? null
          : confidenceBucket ?? this.confidenceBucket,
      dateBucket: clearDateBucket ? null : dateBucket ?? this.dateBucket,
      verificationStatus: clearVerificationStatus
          ? null
          : verificationStatus ?? this.verificationStatus,
      hasLocation: clearHasLocation ? null : hasLocation ?? this.hasLocation,
      userId: clearUserId ? null : userId ?? this.userId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class ClassificationRecordPage {
  final List<ClassificationRecord> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const ClassificationRecordPage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}

class ClassificationRecord {
  final String classificationId;
  final String userId;
  final String speciesId;
  final String modelPredictedSpeciesId;
  final String? correctedSpeciesId;
  final double confidence;
  final String confidenceBucket;
  final double? oodScore;
  final List<ClassificationTopPrediction> topPredictions;
  final String? imageUrl;
  final String? imageStoragePath;
  final String status;
  final String verificationStatus;
  final bool hasLocation;
  final String? locationSource;
  final double? latitudePublic;
  final double? longitudePublic;
  final GeoPoint? geoPoint;
  final double? locationAccuracy;
  final String modelVersion;
  final String imageSizeForModel;
  final String imageSizeForDisplay;
  final String? dateBucket;
  final String? correctedBy;
  final DateTime? correctedAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ClassificationPrivateLocation? privateLocation;

  const ClassificationRecord({
    required this.classificationId,
    required this.userId,
    required this.speciesId,
    required this.modelPredictedSpeciesId,
    required this.correctedSpeciesId,
    required this.confidence,
    required this.confidenceBucket,
    required this.oodScore,
    required this.topPredictions,
    required this.imageUrl,
    required this.imageStoragePath,
    required this.status,
    required this.verificationStatus,
    required this.hasLocation,
    required this.locationSource,
    required this.latitudePublic,
    required this.longitudePublic,
    required this.geoPoint,
    required this.locationAccuracy,
    required this.modelVersion,
    required this.imageSizeForModel,
    required this.imageSizeForDisplay,
    required this.dateBucket,
    required this.correctedBy,
    required this.correctedAt,
    required this.verifiedBy,
    required this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.privateLocation,
  });

  bool get isVerified => verificationStatus == 'verified';
  bool get isRejected => verificationStatus == 'rejected';
  bool get isUnverified => verificationStatus == 'unverified';
  bool get hasCorrection => correctedSpeciesId?.isNotEmpty == true;

  String get verificationLabel => switch (verificationStatus) {
        'verified' => 'Telah Terverifikasi Ahli',
        'rejected' => 'Ditolak Ahli',
        'unverified' => 'Pending / Belum Terverifikasi',
        _ => 'Pending / Belum Terverifikasi',
      };

  double? get displayLatitude => privateLocation?.latitude ?? latitudePublic;
  double? get displayLongitude => privateLocation?.longitude ?? longitudePublic;
  GeoPoint? get displayGeoPoint {
    final precise = privateLocation?.geoPoint;
    if (precise != null) return precise;
    final lat = latitudePublic;
    final lng = longitudePublic;
    if (lat == null || lng == null) return geoPoint;
    return GeoPoint(lat, lng);
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  String get locationLabel {
    final lat = displayLatitude;
    final lng = displayLongitude;
    if (lat == null || lng == null) return 'Tanpa lokasi';
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  factory ClassificationRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    ClassificationPrivateLocation? privateLocation,
  }) {
    return ClassificationRecord.fromMap(
      snapshot.data() ?? {},
      documentId: snapshot.id,
      privateLocation: privateLocation,
    );
  }

  factory ClassificationRecord.fromMap(
    Map<String, dynamic> data, {
    required String documentId,
    ClassificationPrivateLocation? privateLocation,
  }) {
    return ClassificationRecord(
      classificationId: _readString(
        data,
        'classificationId',
        fallback: documentId,
      ),
      userId: _readString(data, 'userId'),
      speciesId: _readString(data, 'speciesId'),
      modelPredictedSpeciesId: _readString(
        data,
        'modelPredictedSpeciesId',
        fallback: _readString(data, 'speciesId'),
      ),
      correctedSpeciesId: _readOptionalString(data, 'correctedSpeciesId'),
      confidence: _readDouble(data, 'confidence'),
      confidenceBucket: _readString(
        data,
        'confidenceBucket',
        fallback: 'low',
      ),
      oodScore: _readOptionalDouble(data, 'oodScore'),
      topPredictions: _readTopPredictions(data['topPredictions']),
      imageUrl: _readOptionalString(data, 'imageUrl'),
      imageStoragePath: _readOptionalString(data, 'imageStoragePath'),
      status: _readString(data, 'status', fallback: 'active'),
      verificationStatus: _readString(
        data,
        'verificationStatus',
        fallback: 'unverified',
      ),
      hasLocation: _readBool(data, 'hasLocation'),
      locationSource: _readOptionalString(data, 'locationSource'),
      latitudePublic: _readOptionalDouble(data, 'latitudePublic'),
      longitudePublic: _readOptionalDouble(data, 'longitudePublic'),
      geoPoint:
          data['geoPoint'] is GeoPoint ? data['geoPoint'] as GeoPoint : null,
      locationAccuracy: _readOptionalDouble(data, 'locationAccuracy'),
      modelVersion: _readString(data, 'modelVersion', fallback: '-'),
      imageSizeForModel: _readString(data, 'imageSizeForModel', fallback: '-'),
      imageSizeForDisplay:
          _readString(data, 'imageSizeForDisplay', fallback: '-'),
      dateBucket: _readOptionalString(data, 'dateBucket'),
      correctedBy: _readOptionalString(data, 'correctedBy'),
      correctedAt: _readDate(data, 'correctedAt'),
      verifiedBy: _readOptionalString(data, 'verifiedBy'),
      verifiedAt: _readDate(data, 'verifiedAt'),
      createdAt: _readDate(data, 'createdAt'),
      updatedAt: _readDate(data, 'updatedAt'),
      privateLocation: privateLocation,
    );
  }

  ClassificationRecord copyWith({
    ClassificationPrivateLocation? privateLocation,
  }) {
    return ClassificationRecord(
      classificationId: classificationId,
      userId: userId,
      speciesId: speciesId,
      modelPredictedSpeciesId: modelPredictedSpeciesId,
      correctedSpeciesId: correctedSpeciesId,
      confidence: confidence,
      confidenceBucket: confidenceBucket,
      oodScore: oodScore,
      topPredictions: topPredictions,
      imageUrl: imageUrl,
      imageStoragePath: imageStoragePath,
      status: status,
      verificationStatus: verificationStatus,
      hasLocation: hasLocation,
      locationSource: locationSource,
      latitudePublic: latitudePublic,
      longitudePublic: longitudePublic,
      geoPoint: geoPoint,
      locationAccuracy: locationAccuracy,
      modelVersion: modelVersion,
      imageSizeForModel: imageSizeForModel,
      imageSizeForDisplay: imageSizeForDisplay,
      dateBucket: dateBucket,
      correctedBy: correctedBy,
      correctedAt: correctedAt,
      verifiedBy: verifiedBy,
      verifiedAt: verifiedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      privateLocation: privateLocation ?? this.privateLocation,
    );
  }
}

class ClassificationTopPrediction {
  final int labelIndex;
  final String speciesId;
  final double confidence;

  const ClassificationTopPrediction({
    required this.labelIndex,
    required this.speciesId,
    required this.confidence,
  });

  factory ClassificationTopPrediction.fromMap(
    Map<String, dynamic> data,
    int fallbackIndex,
  ) {
    return ClassificationTopPrediction(
      labelIndex: (data['labelIndex'] as num?)?.toInt() ?? fallbackIndex,
      speciesId: _readString(data, 'speciesId'),
      confidence: _readDouble(data, 'confidence'),
    );
  }
}

class ClassificationPrivateLocation {
  final double latitude;
  final double longitude;
  final GeoPoint? geoPoint;
  final double? accuracy;
  final String? source;

  const ClassificationPrivateLocation({
    required this.latitude,
    required this.longitude,
    required this.geoPoint,
    required this.accuracy,
    required this.source,
  });

  factory ClassificationPrivateLocation.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return ClassificationPrivateLocation(
      latitude: _readDouble(data, 'latitude'),
      longitude: _readDouble(data, 'longitude'),
      geoPoint:
          data['geoPoint'] is GeoPoint ? data['geoPoint'] as GeoPoint : null,
      accuracy: _readOptionalDouble(data, 'accuracy'),
      source: _readOptionalString(data, 'source'),
    );
  }
}

List<ClassificationTopPrediction> _readTopPredictions(Object? value) {
  if (value is! List) return const [];
  return value
      .asMap()
      .entries
      .where((entry) => entry.value is Map)
      .map(
        (entry) => ClassificationTopPrediction.fromMap(
          Map<String, dynamic>.from(entry.value as Map),
          entry.key,
        ),
      )
      .toList();
}

String _readString(
  Map<String, dynamic> data,
  String key, {
  String fallback = '',
}) {
  final value = data[key];
  if (value == null) return fallback;
  return value.toString();
}

String? _readOptionalString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value == null) return null;
  final text = value.toString();
  return text.trim().isEmpty ? null : text;
}

double _readDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) return value.toDouble();
  return 0;
}

double? _readOptionalDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) return value.toDouble();
  return null;
}

bool _readBool(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

DateTime? _readDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
