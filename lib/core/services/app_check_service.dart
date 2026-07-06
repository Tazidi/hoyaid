import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Service untuk App Check.
/// App Check dikonfigurasi di main.dart saat activate().
/// Class ini menyediakan helper tambahan jika diperlukan.
class AppCheckService {
  static final AppCheckService _instance = AppCheckService._internal();
  factory AppCheckService() => _instance;
  AppCheckService._internal();

  final FirebaseAppCheck _appCheck = FirebaseAppCheck.instance;

  /// Mendapatkan App Check token (untuk debugging atau pengiriman manual).
  /// Di production, token dikirim otomatis oleh Firebase SDK.
  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      return await _appCheck.getToken(forceRefresh);
    } catch (e) {
      if (kDebugMode) print('[AppCheck] getToken error: $e');
      return null;
    }
  }

  /// Listener perubahan token (opsional — untuk advanced use)
  void listenTokenChanges(Function(String?) onToken) {
    _appCheck.onTokenChange.listen((token) {
      onToken(token);
    });
  }
}
