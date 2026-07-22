import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hoyaid/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccountSlot { primary, secondary }

class StoredAccount {
  final AccountSlot slot;
  final User user;

  const StoredAccount({required this.slot, required this.user});
}

/// Manages at most two Firebase sessions without persisting user passwords.
///
/// Firebase keeps the credentials for each [FirebaseApp] securely on-device.
/// The default Firebase app is the first slot; a named Firebase app holds the
/// optional second slot.
class AccountSessionManager extends ChangeNotifier {
  static const _secondaryAppName = 'saved_secondary_account';
  static const _activeSlotPreferenceKey = 'active_account_slot_v1';

  late final FirebaseApp _primaryApp;
  late final FirebaseAuth _primaryAuth;
  FirebaseApp? _secondaryApp;
  FirebaseAuth? _secondaryAuth;
  StreamSubscription<User?>? _primaryAuthSubscription;
  StreamSubscription<User?>? _secondaryAuthSubscription;
  Future<void>? _initialization;
  AccountSlot _activeSlot = AccountSlot.primary;
  bool _isInitialized = false;

  AccountSessionManager() {
    _primaryApp = Firebase.app();
    _primaryAuth = FirebaseAuth.instanceFor(app: _primaryApp);
    _primaryAuthSubscription = _primaryAuth.authStateChanges().listen(
          _onAuthStateChanged,
        );
    unawaited(initialize());
  }

  bool get isInitialized => _isInitialized;
  AccountSlot get activeSlot => _activeSlot;
  FirebaseApp get activeApp => _appFor(_activeSlot);
  FirebaseAuth get activeAuth => _authFor(_activeSlot);
  FirebaseFirestore get firestore => FirebaseFirestore.instanceFor(
        app: activeApp,
      );
  FirebaseFunctions get functions => FirebaseFunctions.instanceFor(
        app: activeApp,
      );
  FirebaseStorage get storage => FirebaseStorage.instanceFor(app: activeApp);
  User? get currentUser => activeAuth.currentUser;
  Stream<User?> get authStateChanges => activeAuth.authStateChanges();

  List<StoredAccount> get accounts => [
        if (_primaryAuth.currentUser != null)
          StoredAccount(
            slot: AccountSlot.primary,
            user: _primaryAuth.currentUser!,
          ),
        if (_secondaryAuth?.currentUser != null)
          StoredAccount(
            slot: AccountSlot.secondary,
            user: _secondaryAuth!.currentUser!,
          ),
      ];

  bool get canAddAccount => accounts.length < 2;

  Future<void> initialize() {
    return _initialization ??= _restoreSessions();
  }

  Future<void> _restoreSessions() async {
    await _ensureSecondarySession();
    final preferences = await SharedPreferences.getInstance();
    final savedSlot = preferences.getString(_activeSlotPreferenceKey);
    final requestedSlot = savedSlot == AccountSlot.secondary.name
        ? AccountSlot.secondary
        : AccountSlot.primary;

    if (_authFor(requestedSlot).currentUser != null) {
      _activeSlot = requestedSlot;
    } else if (_primaryAuth.currentUser != null) {
      _activeSlot = AccountSlot.primary;
    } else if (_secondaryAuth?.currentUser != null) {
      _activeSlot = AccountSlot.secondary;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> switchTo(AccountSlot slot) async {
    await initialize();
    if (_authFor(slot).currentUser == null) {
      throw StateError('Akun ini sudah tidak tersedia di perangkat.');
    }
    if (_activeSlot == slot) return;

    _activeSlot = slot;
    await _persistActiveSlot();
    notifyListeners();
  }

  Future<UserCredential> addAccountWithEmail({
    required String email,
    required String password,
  }) async {
    final target = await _nextAvailableSlot();
    final credential = await target.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _activateAddedAccount(target.slot, target.auth, credential.user);
    return credential;
  }

  Future<UserCredential?> addAccountWithGoogle() async {
    final target = await _nextAvailableSlot();
    final googleSignIn = GoogleSignIn();

    // Firebase sessions stay intact; this only opens the Google account picker
    // so the user can choose a different Google identity if needed.
    await googleSignIn.signOut();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await target.auth.signInWithCredential(credential);
    await _activateAddedAccount(target.slot, target.auth, userCredential.user);
    return userCredential;
  }

  Future<void> removeAccount(AccountSlot slot) async {
    await initialize();
    final auth = _authFor(slot);
    if (auth.currentUser == null) return;

    await auth.signOut();
    if (_activeSlot == slot) {
      final alternate = slot == AccountSlot.primary
          ? AccountSlot.secondary
          : AccountSlot.primary;
      _activeSlot = _authFor(alternate).currentUser != null
          ? alternate
          : AccountSlot.primary;
    }
    await _persistActiveSlot();
    notifyListeners();
  }

  Future<void> removeActiveAccount() => removeAccount(_activeSlot);

  Future<void> _ensureSecondarySession() async {
    if (_secondaryAuth != null) return;

    final existing = Firebase.apps.where(
      (app) => app.name == _secondaryAppName,
    );
    final app = existing.isNotEmpty
        ? existing.first
        : await Firebase.initializeApp(
            name: _secondaryAppName,
            options: DefaultFirebaseOptions.currentPlatform,
          );
    _secondaryApp = app;
    _secondaryAuth = FirebaseAuth.instanceFor(app: app);

    FirebaseFirestore.instanceFor(app: app).settings = const Settings(
      persistenceEnabled: true,
    );
    if (!kIsWeb) {
      try {
        await FirebaseAppCheck.instanceFor(app: app).activate(
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
        );
      } catch (error) {
        debugPrint('App Check sesi akun kedua belum aktif: $error');
      }
    }
    _secondaryAuthSubscription = _secondaryAuth!.authStateChanges().listen(
          _onAuthStateChanged,
        );
  }

  Future<_AvailableAccountSlot> _nextAvailableSlot() async {
    await initialize();
    if (_primaryAuth.currentUser == null) {
      return _AvailableAccountSlot(AccountSlot.primary, _primaryAuth);
    }
    await _ensureSecondarySession();
    if (_secondaryAuth!.currentUser == null) {
      return _AvailableAccountSlot(AccountSlot.secondary, _secondaryAuth!);
    }
    throw StateError('Maksimal dua akun dapat disimpan pada perangkat ini.');
  }

  Future<void> _activateAddedAccount(
    AccountSlot slot,
    FirebaseAuth auth,
    User? user,
  ) async {
    if (user == null) {
      throw StateError('Data akun tidak diterima. Coba lagi.');
    }
    final duplicate = accounts.any(
      (account) => account.slot != slot && account.user.uid == user.uid,
    );
    if (duplicate) {
      await auth.signOut();
      throw StateError('Akun ini sudah tersimpan pada perangkat.');
    }

    _activeSlot = slot;
    await _persistActiveSlot();
    notifyListeners();
  }

  FirebaseApp _appFor(AccountSlot slot) {
    if (slot == AccountSlot.primary) return _primaryApp;
    return _secondaryApp ?? _primaryApp;
  }

  FirebaseAuth _authFor(AccountSlot slot) {
    if (slot == AccountSlot.primary) return _primaryAuth;
    return _secondaryAuth ?? _primaryAuth;
  }

  void _onAuthStateChanged(User? _) {
    if (_isInitialized && _authFor(_activeSlot).currentUser == null) {
      final alternate = _activeSlot == AccountSlot.primary
          ? AccountSlot.secondary
          : AccountSlot.primary;
      if (_authFor(alternate).currentUser != null) {
        _activeSlot = alternate;
        unawaited(_persistActiveSlot());
      }
    }
    notifyListeners();
  }

  Future<void> _persistActiveSlot() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activeSlotPreferenceKey, _activeSlot.name);
  }

  @override
  void dispose() {
    _primaryAuthSubscription?.cancel();
    _secondaryAuthSubscription?.cancel();
    super.dispose();
  }
}

class _AvailableAccountSlot {
  final AccountSlot slot;
  final FirebaseAuth auth;

  const _AvailableAccountSlot(this.slot, this.auth);
}
