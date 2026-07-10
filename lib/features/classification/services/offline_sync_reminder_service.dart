import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:hoyaid/features/classification/services/offline_classification_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSyncReminderService {
  static const taskName = 'offline-sync-reminder';
  static const _channelId = 'offline_sync_reminder';
  static const _channelName = 'Pengingat sinkronisasi offline';
  static const _notificationId = 1001;

  static Future<void> requestPermission() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await _init(plugin);
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> showIfNeeded() async {
    final hasPending = await _hasPendingQueue();
    if (!hasPending || !await _isOnline()) return;

    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await _init(plugin);
      await plugin.show(
        _notificationId,
        'Ada data klasifikasi belum tersinkron',
        'Internet sudah tersedia. Buka iHoya untuk upload data offline.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Mengingatkan upload data klasifikasi offline.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> _init(FlutterLocalNotificationsPlugin plugin) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: android));
  }

  static Future<bool> _hasPendingQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(OfflineClassificationQueueService.queueKey);
    if (raw == null || raw.isEmpty) return false;
    final decoded = jsonDecode(raw);
    return decoded is List && decoded.isNotEmpty;
  }

  static Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }
}
