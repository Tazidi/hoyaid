import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Audit trail for records first stored offline. A success is recorded only
/// after `finalizeClassification` verifies both the Storage object and document.
class OfflineSyncMetricsStore {
  static const _key = 'offline_sync_metrics_v1';

  Future<void> recordQueued(String itemId) async {
    final entries = await _load();
    if (entries.any((entry) => entry.itemId == itemId)) return;
    entries.add(OfflineSyncMetric(itemId: itemId, queuedAt: DateTime.now()));
    await _save(entries);
  }

  Future<void> recordSuccess(String itemId, Duration duration) async {
    final entries = await _load();
    final index = entries.indexWhere((entry) => entry.itemId == itemId);
    if (index < 0) return;
    entries[index] = entries[index].copyWith(
      syncedAt: DateTime.now(),
      syncDurationMs: duration.inMilliseconds,
    );
    await _save(entries);
  }

  Future<List<OfflineSyncMetric>> load() => _load();

  Future<List<OfflineSyncMetric>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((entry) => OfflineSyncMetric.fromMap(
              Map<String, dynamic>.from(entry as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<OfflineSyncMetric> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(entries.map((entry) => entry.toMap()).toList()),
    );
  }
}

class OfflineSyncMetric {
  final String itemId;
  final DateTime queuedAt;
  final DateTime? syncedAt;
  final int? syncDurationMs;

  const OfflineSyncMetric({
    required this.itemId,
    required this.queuedAt,
    this.syncedAt,
    this.syncDurationMs,
  });

  bool get isSynced => syncedAt != null && syncDurationMs != null;

  OfflineSyncMetric copyWith({DateTime? syncedAt, int? syncDurationMs}) {
    return OfflineSyncMetric(
      itemId: itemId,
      queuedAt: queuedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      syncDurationMs: syncDurationMs ?? this.syncDurationMs,
    );
  }

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'queuedAt': queuedAt.toIso8601String(),
        'syncedAt': syncedAt?.toIso8601String(),
        'syncDurationMs': syncDurationMs,
      };

  factory OfflineSyncMetric.fromMap(Map<String, dynamic> map) {
    return OfflineSyncMetric(
      itemId: map['itemId'].toString(),
      queuedAt: DateTime.parse(map['queuedAt'].toString()),
      syncedAt: map['syncedAt'] == null
          ? null
          : DateTime.tryParse(map['syncedAt'].toString()),
      syncDurationMs: (map['syncDurationMs'] as num?)?.toInt(),
    );
  }
}
