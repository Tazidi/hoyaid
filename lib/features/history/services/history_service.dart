import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';

class HistoryService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  HistoryService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _classifications =>
      _firestore.collection('classifications');

  Future<ClassificationRecordPage> fetchPage({
    required ClassificationScope scope,
    required HistoryFilter filter,
    required String? currentUserId,
    required bool isAdmin,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query =
        _classifications.where('status', isEqualTo: 'active');

    if (scope == ClassificationScope.mine) {
      if (currentUserId == null || currentUserId.isEmpty) {
        return const ClassificationRecordPage(
          items: [],
          lastDocument: null,
          hasMore: false,
        );
      }
      query = query.where('userId', isEqualTo: currentUserId);
    } else if (isAdmin && filter.userId?.isNotEmpty == true) {
      query = query.where('userId', isEqualTo: filter.userId);
    }

    final serverLimit = filter.hasActiveFilters ? limit * 4 : limit;
    query = query
        .orderBy(
          'createdAt',
          descending: filter.sortOrder == ClassificationSortOrder.newest,
        )
        .limit(serverLimit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final records = snapshot.docs
        .map((doc) => ClassificationRecord.fromSnapshot(doc))
        .where((record) => _matchesFilter(record, filter))
        .take(limit)
        .toList();

    if (!isAdmin && scope == ClassificationScope.public) {
      records.removeWhere((record) => record.verificationStatus == 'rejected');
    }

    return ClassificationRecordPage(
      items: records,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == serverLimit,
    );
  }

  bool _matchesFilter(ClassificationRecord record, HistoryFilter filter) {
    if (filter.speciesId?.isNotEmpty == true &&
        record.speciesId != filter.speciesId) {
      return false;
    }
    if (filter.confidenceBucket?.isNotEmpty == true &&
        record.confidenceBucket != filter.confidenceBucket) {
      return false;
    }
    if (filter.dateBucket?.isNotEmpty == true &&
        record.dateBucket != filter.dateBucket) {
      return false;
    }
    if (filter.verificationStatus?.isNotEmpty == true &&
        record.verificationStatus != filter.verificationStatus) {
      return false;
    }
    if (filter.hasLocation != null &&
        record.hasLocation != filter.hasLocation) {
      return false;
    }
    return true;
  }

  Stream<ClassificationRecord?> watchClassification(
    String classificationId, {
    required String? currentUserId,
    required bool isAdmin,
  }) {
    return _classifications.doc(classificationId).snapshots().asyncMap(
      (snapshot) async {
        if (!snapshot.exists) return null;
        final record = ClassificationRecord.fromSnapshot(snapshot);
        final location = await fetchReadableLocation(
          record,
          currentUserId: currentUserId,
          isAdmin: isAdmin,
        );
        return record.copyWith(privateLocation: location);
      },
    );
  }

  Future<ClassificationPrivateLocation?> fetchReadableLocation(
    ClassificationRecord record, {
    required String? currentUserId,
    required bool isAdmin,
  }) async {
    if (!record.hasLocation) return null;
    final canReadPrivate = isAdmin || record.userId == currentUserId;
    if (!canReadPrivate) return null;

    try {
      final snapshot = await _classifications
          .doc(record.classificationId)
          .collection('private')
          .doc('location')
          .get();
      if (!snapshot.exists) return null;
      return ClassificationPrivateLocation.fromSnapshot(snapshot);
    } on FirebaseException {
      return null;
    }
  }

  Future<void> correctClassificationLabel({
    required String classificationId,
    required String speciesId,
  }) async {
    final callable = _functions.httpsCallable('correctClassificationLabel');
    await callable.call<void>({
      'classificationId': classificationId,
      'speciesId': speciesId,
    });
  }

  Future<void> archiveAndDeleteClassification({
    required String classificationId,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('archiveAndDeleteClassification');
    await callable.call<void>({
      'classificationId': classificationId,
      'reason': reason,
    });
  }
}
