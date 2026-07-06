import 'package:cloud_firestore/cloud_firestore.dart';

class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int activeClassifications;
  final int archivedClassifications;
  final int speciesCount;
  final int unverifiedClassifications;
  final int verifiedClassifications;
  final int rejectedClassifications;
  final int lowConfidenceClassifications;
  final DateTime? updatedAt;

  const AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.activeClassifications,
    required this.archivedClassifications,
    required this.speciesCount,
    required this.unverifiedClassifications,
    required this.verifiedClassifications,
    required this.rejectedClassifications,
    required this.lowConfidenceClassifications,
    required this.updatedAt,
  });

  factory AdminStats.empty() {
    return const AdminStats(
      totalUsers: 0,
      activeUsers: 0,
      activeClassifications: 0,
      archivedClassifications: 0,
      speciesCount: 0,
      unverifiedClassifications: 0,
      verifiedClassifications: 0,
      rejectedClassifications: 0,
      lowConfidenceClassifications: 0,
      updatedAt: null,
    );
  }

  factory AdminStats.fromMap(Map<String, dynamic> data) {
    return AdminStats(
      totalUsers: _readInt(data, 'totalUsers'),
      activeUsers: _readInt(data, 'activeUsers'),
      activeClassifications: _readInt(data, 'activeClassifications'),
      archivedClassifications: _readInt(data, 'archivedClassifications'),
      speciesCount: _readInt(data, 'speciesCount'),
      unverifiedClassifications: _readInt(data, 'unverifiedClassifications'),
      verifiedClassifications: _readInt(data, 'verifiedClassifications'),
      rejectedClassifications: _readInt(data, 'rejectedClassifications'),
      lowConfidenceClassifications:
          _readInt(data, 'lowConfidenceClassifications'),
      updatedAt: _readDate(data, 'updatedAt'),
    );
  }
}

class AdminUserProfile {
  final String uid;
  final String name;
  final String email;
  final String role;
  final int uploadLimit;
  final int uploadUsed;
  final bool trusted;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const AdminUserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.uploadLimit,
    required this.uploadUsed,
    required this.trusted,
    required this.isActive,
    required this.createdAt,
    required this.lastLoginAt,
  });

  bool get isNearQuota =>
      uploadLimit > 0 && uploadUsed >= (uploadLimit * 0.8).ceil();

  factory AdminUserProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return AdminUserProfile(
      uid: _readString(data, 'uid', fallback: snapshot.id),
      name: _readString(
        data,
        'name',
        fallback: _readString(data, 'displayName', fallback: 'Pengguna'),
      ),
      email: _readString(data, 'email'),
      role: _readString(data, 'role', fallback: 'user'),
      uploadLimit: _readInt(data, 'uploadLimit'),
      uploadUsed: _readInt(data, 'uploadUsed'),
      trusted: _readBool(data, 'trusted'),
      isActive: _readBool(data, 'isActive', fallback: true),
      createdAt: _readDate(data, 'createdAt'),
      lastLoginAt: _readDate(data, 'lastLoginAt'),
    );
  }
}

class DatasetExportResult {
  final String storagePath;
  final int rowCount;
  final DateTime? generatedAt;
  final String? downloadUrl;

  const DatasetExportResult({
    required this.storagePath,
    required this.rowCount,
    required this.generatedAt,
    required this.downloadUrl,
  });

  factory DatasetExportResult.fromMap(Map<String, dynamic> data) {
    return DatasetExportResult(
      storagePath: _readString(data, 'storagePath'),
      rowCount: _readInt(data, 'rowCount'),
      generatedAt: _readDate(data, 'generatedAt'),
      downloadUrl: _readOptionalString(data, 'downloadUrl'),
    );
  }
}

int _readInt(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) return value.toInt();
  return 0;
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

bool _readBool(
  Map<String, dynamic> data,
  String key, {
  bool fallback = false,
}) {
  final value = data[key];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

DateTime? _readDate(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
