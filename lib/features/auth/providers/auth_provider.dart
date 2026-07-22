import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/services/account_session_manager.dart';
import 'package:hoyaid/core/services/auth_service.dart';

/// Holds the two persisted Firebase sessions and the currently active account.
final accountSessionProvider =
    ChangeNotifierProvider<AccountSessionManager>((ref) {
  final manager = AccountSessionManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final activeFirebaseAppProvider = Provider<FirebaseApp>((ref) {
  return ref.watch(accountSessionProvider).activeApp;
});

final activeFirebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return ref.watch(accountSessionProvider).activeAuth;
});

final activeFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return ref.watch(accountSessionProvider).firestore;
});

final activeFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return ref.watch(accountSessionProvider).functions;
});

final activeStorageProvider = Provider<FirebaseStorage>((ref) {
  return ref.watch(accountSessionProvider).storage;
});

/// Provider for the active account's AuthService.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(firebaseAuth: ref.watch(activeFirebaseAuthProvider));
});

/// Stream provider for the active Firebase Auth session.
final authStateProvider = StreamProvider<User?>((ref) {
  final session = ref.watch(accountSessionProvider);
  return session.authStateChanges;
});

/// Provider for the active User (nullable).
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Stream provider for the active user's document in Firestore.
final userDataProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(currentUserProvider);

  if (user == null || user.isAnonymous) {
    return Stream.value(null);
  }

  return ref
      .watch(activeFirestoreProvider)
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});
