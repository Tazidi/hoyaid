import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hoyaid/features/admin/models/admin_models.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';

class AdminService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AdminService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  Stream<AdminStats> watchGlobalStats() {
    return _firestore.collection('stats').doc('global').snapshots().map(
      (snapshot) {
        if (!snapshot.exists) return AdminStats.empty();
        return AdminStats.fromMap(snapshot.data() ?? {});
      },
    );
  }

  Stream<List<AdminUserProfile>> watchUsers({int limit = 50}) {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AdminUserProfile.fromSnapshot).toList(),
        );
  }

  Stream<List<ClassificationRecord>> watchVerificationQueue({int limit = 50}) {
    return _firestore
        .collection('classifications')
        .where('status', isEqualTo: 'active')
        .where('verificationStatus', isEqualTo: 'unverified')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Stream<List<ClassificationRecord>> watchRecentClassifications({
    int limit = 10,
  }) {
    return _firestore
        .collection('classifications')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Stream<List<ClassificationRecord>> watchLowConfidenceClassifications({
    int limit = 20,
  }) {
    return _firestore
        .collection('classifications')
        .where('status', isEqualTo: 'active')
        .where('confidenceBucket', isEqualTo: 'low')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_recordsFromSnapshot);
  }

  Future<void> updateUserUploadLimit({
    required String uid,
    required int uploadLimit,
    required bool trusted,
  }) async {
    final callable = _functions.httpsCallable('updateUserUploadLimit');
    await callable.call<void>({
      'uid': uid,
      'uploadLimit': uploadLimit,
      'trusted': trusted,
    });
  }

  Future<void> recalculateUserUploadUsed(String uid) async {
    final callable = _functions.httpsCallable('recalculateUserUploadUsed');
    await callable.call<void>({'uid': uid});
  }

  Future<void> setVerificationStatus({
    required String classificationId,
    required String status,
  }) async {
    final callable = _functions.httpsCallable('setVerificationStatus');
    await callable.call<void>({
      'classificationId': classificationId,
      'status': status,
    });
  }

  Future<DatasetExportResult> exportDataset({
    bool verifiedOnly = true,
  }) async {
    final callable = _functions.httpsCallable('exportDataset');
    final result = await callable.call<Map<String, dynamic>>({
      'verifiedOnly': verifiedOnly,
    });
    return DatasetExportResult.fromMap(Map<String, dynamic>.from(result.data));
  }

  Future<void> recalculateGlobalStats() async {
    final callable = _functions.httpsCallable('recalculateGlobalStats');
    await callable.call<void>();
  }

  List<ClassificationRecord> _recordsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(ClassificationRecord.fromSnapshot).toList();
  }
}
