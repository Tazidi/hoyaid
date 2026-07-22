import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/history/services/history_service.dart';
import 'package:hoyaid/features/map/models/distribution_map_models.dart';
import 'package:hoyaid/features/map/services/distribution_map_service.dart';

final distributionMapServiceProvider = Provider<DistributionMapService>((ref) {
  final firestore = ref.watch(activeFirestoreProvider);
  final functions = ref.watch(activeFunctionsProvider);
  return DistributionMapService(
    firestore: firestore,
    historyService: HistoryService(firestore: firestore, functions: functions),
  );
});

final distributionMapPointsProvider = FutureProvider.autoDispose
    .family<List<DistributionMapPoint>, DistributionMapFilter>((ref, filter) {
  final user = ref.watch(currentUserProvider);
  final userData = ref.watch(userDataProvider).valueOrNull;
  return ref.watch(distributionMapServiceProvider).fetchPoints(
        filter: filter,
        currentUserId: user?.uid,
        isAdmin: userData?['role'] == 'admin',
      );
});
