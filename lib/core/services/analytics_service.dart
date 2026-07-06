import 'package:firebase_analytics/firebase_analytics.dart';

/// Service wrapper untuk Firebase Analytics.
/// Digunakan di seluruh app untuk mencatat event.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Set userId saat user login
  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  /// Set role user sebagai user property
  Future<void> setUserRole(String role) async {
    await _analytics.setUserProperty(name: 'user_role', value: role);
  }

  /// Catat event login
  Future<void> logLogin({required String method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// Catat event klasifikasi berhasil
  Future<void> logClassification({
    required String speciesId,
    required double confidence,
  }) async {
    await _analytics.logEvent(
      name: 'classification_saved',
      parameters: {
        'species_id': speciesId,
        'confidence': confidence,
      },
    );
  }

  /// Catat event custom
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }
}
