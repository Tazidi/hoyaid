import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hoyaid/features/classification/services/location_service.dart';
import 'package:hoyaid/features/classification/services/offline_sync_metrics_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GeoTagTestCondition {
  outdoor('Luar ruangan'),
  greenhouse('Dalam rumah kaca/kanopi rapat');

  final String label;
  const GeoTagTestCondition(this.label);
}

class GeoTaggingEvaluationService {
  static const _gpsFixKey = 'geo_tagging_first_fix_samples_v1';
  final FirebaseFirestore _firestore;
  final LocationService _locationService;
  final OfflineSyncMetricsStore _offlineMetrics;

  GeoTaggingEvaluationService({
    FirebaseFirestore? firestore,
    LocationService? locationService,
    OfflineSyncMetricsStore? offlineMetrics,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _locationService = locationService ?? LocationService(),
        _offlineMetrics = offlineMetrics ?? OfflineSyncMetricsStore();

  Future<GeoTagFixSample?> measureFirstFix(
      GeoTagTestCondition condition) async {
    final measurement = await _locationService.measureFirstFix();
    if (measurement == null) return null;
    final sample = GeoTagFixSample(
      condition: condition,
      timestamp: DateTime.now(),
      durationMs: measurement.elapsed.inMilliseconds,
      accuracyMeters: measurement.location.accuracy,
    );
    final samples = await _loadFixSamples();
    samples.add(sample);
    await _saveFixSamples(samples);
    return sample;
  }

  Future<GeoTaggingReport> buildReport() async {
    final snapshot = await _firestore
        .collection('classifications')
        .where('status', isEqualTo: 'active')
        .get();
    final rows = snapshot.docs.map((doc) => doc.data()).toList();
    final geoTagged = rows.where(_hasCompleteCoordinates).toList();
    final manual = geoTagged
        .where((data) => data['locationSource']?.toString() == 'manual')
        .length;
    final accuracies = geoTagged
        .where((data) => data['locationSource']?.toString() == 'gps')
        .map((data) => (data['locationAccuracy'] as num?)?.toDouble())
        .whereType<double>()
        .where((value) => value.isFinite && value >= 0)
        .toList();
    final samples = await _loadFixSamples();
    final offline = await _offlineMetrics.load();
    return GeoTaggingReport(
      geoTaggedCount: geoTagged.length,
      manualCount: manual,
      gpsAccuracy: NumericSummary.fromValues(accuracies),
      firstFixByCondition: {
        for (final condition in GeoTagTestCondition.values)
          condition: NumericSummary.fromValues(samples
              .where((sample) => sample.condition == condition)
              .map((sample) => sample.durationMs / 1000)
              .toList()),
      },
      offlineTotal: offline.length,
      offlineSynced: offline.where((entry) => entry.isSynced).length,
      offlineSyncDuration: NumericSummary.fromValues(offline
          .where((entry) => entry.isSynced)
          .map((entry) => entry.syncDurationMs! / 1000)
          .toList()),
    );
  }

  bool _hasCompleteCoordinates(Map<String, dynamic> data) {
    return data['latitudePublic'] is num && data['longitudePublic'] is num;
  }

  Future<List<GeoTagFixSample>> _loadFixSamples() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_gpsFixKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((entry) =>
              GeoTagFixSample.fromMap(Map<String, dynamic>.from(entry as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveFixSamples(List<GeoTagFixSample> samples) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _gpsFixKey,
      jsonEncode(samples.map((sample) => sample.toMap()).toList()),
    );
  }
}

class GeoTagFixSample {
  final GeoTagTestCondition condition;
  final DateTime timestamp;
  final int durationMs;
  final double? accuracyMeters;

  const GeoTagFixSample({
    required this.condition,
    required this.timestamp,
    required this.durationMs,
    required this.accuracyMeters,
  });

  Map<String, dynamic> toMap() => {
        'condition': condition.name,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': durationMs,
        'accuracyMeters': accuracyMeters,
      };

  factory GeoTagFixSample.fromMap(Map<String, dynamic> map) {
    return GeoTagFixSample(
      condition: GeoTagTestCondition.values.firstWhere(
        (value) => value.name == map['condition'],
        orElse: () => GeoTagTestCondition.outdoor,
      ),
      timestamp: DateTime.parse(map['timestamp'].toString()),
      durationMs: (map['durationMs'] as num).toInt(),
      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),
    );
  }
}

class NumericSummary {
  final int count;
  final double? mean;
  final double? standardDeviation;
  final double? minimum;
  final double? maximum;

  const NumericSummary._({
    required this.count,
    this.mean,
    this.standardDeviation,
    this.minimum,
    this.maximum,
  });

  factory NumericSummary.fromValues(List<double> values) {
    if (values.isEmpty) return const NumericSummary._(count: 0);
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.length > 1
        ? values
                .map((value) => math.pow(value - mean, 2))
                .reduce((a, b) => a + b) /
            (values.length - 1)
        : 0.0;
    return NumericSummary._(
      count: values.length,
      mean: mean,
      standardDeviation: math.sqrt(variance),
      minimum: values.reduce((a, b) => a < b ? a : b),
      maximum: values.reduce((a, b) => a > b ? a : b),
    );
  }

  String format({String unit = ''}) {
    if (count == 0) return 'Belum ada data';
    final suffix = unit.isEmpty ? '' : ' $unit';
    return '${mean!.toStringAsFixed(1)} ± ${standardDeviation!.toStringAsFixed(1)}$suffix, '
        'rentang ${minimum!.toStringAsFixed(1)}–${maximum!.toStringAsFixed(1)}$suffix (n = $count)';
  }
}

class GeoTaggingReport {
  final int geoTaggedCount;
  final int manualCount;
  final NumericSummary gpsAccuracy;
  final Map<GeoTagTestCondition, NumericSummary> firstFixByCondition;
  final int offlineTotal;
  final int offlineSynced;
  final NumericSummary offlineSyncDuration;

  const GeoTaggingReport({
    required this.geoTaggedCount,
    required this.manualCount,
    required this.gpsAccuracy,
    required this.firstFixByCondition,
    required this.offlineTotal,
    required this.offlineSynced,
    required this.offlineSyncDuration,
  });

  double get manualPercentage =>
      geoTaggedCount == 0 ? 0 : manualCount / geoTaggedCount * 100;
  double get offlineSuccessPercentage =>
      offlineTotal == 0 ? 0 : offlineSynced / offlineTotal * 100;

  String get clipboardText => '''Pengujian geo-tagging iHoya

a. Jumlah rekaman ber-geo-tag: n = $geoTaggedCount rekaman.
b. Waktu perolehan koordinat pertama:
${GeoTagTestCondition.values.map((condition) => '- ${condition.label}: ${firstFixByCondition[condition]!.format(unit: 'detik')}').join('\n')}
c. Akurasi horizontal GPS: ${gpsAccuracy.format(unit: 'm')}.
d. Koordinat manual: $manualCount dari $geoTaggedCount rekaman (${manualPercentage.toStringAsFixed(1)}%).
e. Sinkronisasi offline → online: $offlineSynced dari $offlineTotal rekaman (${offlineSuccessPercentage.toStringAsFixed(1)}%); waktu sinkronisasi ${offlineSyncDuration.format(unit: 'detik')}.''';
}
