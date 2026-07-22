import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/features/admin/models/admin_models.dart';
import 'package:hoyaid/features/admin/services/admin_service.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(
    firestore: ref.watch(activeFirestoreProvider),
    functions: ref.watch(activeFunctionsProvider),
  );
});

final adminStatsProvider = StreamProvider<AdminStats>((ref) {
  return ref.watch(adminServiceProvider).watchGlobalStats();
});

final adminUsersProvider = StreamProvider<List<AdminUserProfile>>((ref) {
  return ref.watch(adminServiceProvider).watchUsers();
});

final adminVerificationQueueProvider =
    StreamProvider<List<ClassificationRecord>>((ref) {
  return ref.watch(adminServiceProvider).watchVerificationQueue();
});

final adminRecentClassificationsProvider =
    StreamProvider<List<ClassificationRecord>>((ref) {
  return ref.watch(adminServiceProvider).watchRecentClassifications();
});

final adminLowConfidenceProvider =
    StreamProvider<List<ClassificationRecord>>((ref) {
  return ref.watch(adminServiceProvider).watchLowConfidenceClassifications();
});
