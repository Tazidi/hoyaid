import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';
import 'package:hoyaid/features/history/services/history_service.dart';
import 'package:hoyaid/features/map/models/distribution_map_models.dart';
import 'package:latlong2/latlong.dart';

class DistributionMapService {
  final FirebaseFirestore _firestore;
  final HistoryService _historyService;

  DistributionMapService({
    FirebaseFirestore? firestore,
    HistoryService? historyService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _historyService = historyService ?? HistoryService();

  Future<List<DistributionMapPoint>> fetchPoints({
    required DistributionMapFilter filter,
    required String? currentUserId,
    required bool isAdmin,
    int limit = 250,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('classifications')
        .where('status', isEqualTo: 'active')
        .where('hasLocation', isEqualTo: true);

    if (filter.scope == DistributionMapScope.mine) {
      if (currentUserId == null || currentUserId.isEmpty) return const [];
      query = query.where('userId', isEqualTo: currentUserId);
    }

    if (filter.verificationFilter == DistributionVerificationFilter.verified) {
      query = query.where('verificationStatus', isEqualTo: 'verified');
    } else if (filter.verificationFilter ==
        DistributionVerificationFilter.publicUnverified) {
      query = query.where('verificationStatus', isEqualTo: 'unverified');
    }
    final snapshot =
        await query.orderBy('createdAt', descending: true).limit(limit).get();

    final records = snapshot.docs
        .map((doc) => ClassificationRecord.fromSnapshot(doc))
        .where(
          (record) =>
              (isAdmin || record.verificationStatus != 'rejected') &&
              _matchesFilter(record, filter),
        )
        .toList();

    final points = <DistributionMapPoint>[];
    for (final record in records) {
      final privateLocation = await _historyService.fetchReadableLocation(
        record,
        currentUserId: currentUserId,
        isAdmin: isAdmin,
      );
      final enriched = record.copyWith(privateLocation: privateLocation);
      final latitude = enriched.displayLatitude;
      final longitude = enriched.displayLongitude;
      if (latitude == null || longitude == null) continue;

      points.add(
        DistributionMapPoint(
          record: enriched,
          point: LatLng(latitude, longitude),
          isPrecise: privateLocation != null,
        ),
      );
    }

    return points;
  }

  bool _matchesFilter(
    ClassificationRecord record,
    DistributionMapFilter filter,
  ) {
    if (filter.speciesId?.isNotEmpty == true &&
        record.speciesId != filter.speciesId) {
      return false;
    }
    if (filter.dateBucket?.isNotEmpty == true &&
        record.dateBucket != filter.dateBucket) {
      return false;
    }
    if (filter.verificationFilter == DistributionVerificationFilter.verified &&
        !record.isVerified) {
      return false;
    }
    if (filter.verificationFilter ==
            DistributionVerificationFilter.publicUnverified &&
        !record.isUnverified) {
      return false;
    }
    return true;
  }
}
