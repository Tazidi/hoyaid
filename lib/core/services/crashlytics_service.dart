import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Service wrapper untuk Firebase Crashlytics.
class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  factory CrashlyticsService() => _instance;
  CrashlyticsService._internal();

  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Aktifkan/nonaktifkan pengumpulan data Crashlytics.
  /// Nonaktifkan di debug mode agar tidak mengotori dashboard produksi.
  Future<void> initialize() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  /// Set userId saat login
  Future<void> setUserId(String userId) async {
    await _crashlytics.setUserIdentifier(userId);
  }

  /// Catat error non-fatal
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  /// Log pesan custom (muncul di breadcrumb Crashlytics)
  Future<void> log(String message) async {
    await _crashlytics.log(message);
  }

  /// Set key-value custom (muncul di crash report)
  Future<void> setCustomKey(String key, dynamic value) async {
    await _crashlytics.setCustomKey(key, value);
  }
}
