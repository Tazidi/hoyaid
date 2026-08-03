import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum GeoTaggingPlanStepType {
  firstFixOutdoor,
  firstFixGreenhouse,
  classificationGpsOutdoor,
  classificationGpsGreenhouse,
  classificationManualGreenhouse,
  offlineSync,
}

class GeoTaggingPlanStep {
  final GeoTaggingPlanStepType type;
  final String title;
  final String instruction;
  final int target;

  const GeoTaggingPlanStep({
    required this.type,
    required this.title,
    required this.instruction,
    required this.target,
  });

  bool get requiresGpsMeasurement =>
      type == GeoTaggingPlanStepType.firstFixOutdoor ||
      type == GeoTaggingPlanStepType.firstFixGreenhouse;

  bool get opensClassification => !requiresGpsMeasurement;
}

const geoTaggingDefaultPlan = <GeoTaggingPlanStep>[
  GeoTaggingPlanStep(
    type: GeoTaggingPlanStepType.firstFixOutdoor,
    title: 'First GPS fix — luar ruangan',
    instruction:
        'Berada di area terbuka, pilih Luar ruangan, lalu mulai pengukuran. Ulangi 5 kali.',
    target: 5,
  ),
  GeoTaggingPlanStep(
    type: GeoTaggingPlanStepType.firstFixGreenhouse,
    title: 'First GPS fix — kanopi/rumah kaca',
    instruction:
        'Pindah ke bawah kanopi atau rumah kaca, lalu jalankan pengukuran 5 kali.',
    target: 5,
  ),
  GeoTaggingPlanStep(
    type: GeoTaggingPlanStepType.classificationGpsOutdoor,
    title: 'Klasifikasi GPS — luar ruangan',
    instruction:
        'Simpan 5 klasifikasi saat koordinat GPS otomatis tampil. Pastikan sumber lokasi adalah GPS. Setelah tersimpan, buka lagi panduan ini dan konfirmasikan satu rekaman.',
    target: 5,
  ),
  GeoTaggingPlanStep(
    type: GeoTaggingPlanStepType.classificationGpsGreenhouse,
    title: 'Klasifikasi GPS — kanopi/rumah kaca',
    instruction:
        'Di bawah kanopi, simpan 3 klasifikasi yang masih memperoleh koordinat GPS. Setelah tersimpan, buka lagi panduan ini dan konfirmasikan satu rekaman.',
    target: 3,
  ),
  GeoTaggingPlanStep(
    type: GeoTaggingPlanStepType.classificationManualGreenhouse,
    title: 'Koordinat manual — kanopi/rumah kaca',
    instruction:
        'Di bawah kanopi, simpan 2 klasifikasi memakai tombol lokasi/pin manual. Setelah tersimpan, buka lagi panduan ini dan konfirmasikan satu rekaman.',
    target: 2,
  ),
  GeoTaggingPlanStep(
    type: GeoTaggingPlanStepType.offlineSync,
    title: 'Sinkronisasi offline → online',
    instruction:
        'Matikan internet, simpan klasifikasi offline, aktifkan internet, lalu tekan Sync. Setelah notifikasi berhasil muncul, buka lagi panduan ini dan konfirmasikan satu rekaman. Ulangi 5 kali.',
    target: 5,
  ),
];

class GeoTaggingTestPlanProgress {
  final Map<String, int> completed;

  const GeoTaggingTestPlanProgress({required this.completed});

  factory GeoTaggingTestPlanProgress.empty() =>
      const GeoTaggingTestPlanProgress(completed: {});

  int countFor(GeoTaggingPlanStep step) => completed[step.type.name] ?? 0;

  bool isComplete(GeoTaggingPlanStep step) => countFor(step) >= step.target;

  int get totalCompleted =>
      completed.values.fold(0, (sum, value) => sum + value);

  int get totalTarget =>
      geoTaggingDefaultPlan.fold(0, (sum, step) => sum + step.target);

  GeoTaggingPlanStep? get currentStep {
    for (final step in geoTaggingDefaultPlan) {
      if (!isComplete(step)) return step;
    }
    return null;
  }

  GeoTaggingTestPlanProgress increment(GeoTaggingPlanStep step) {
    final next = Map<String, int>.from(completed);
    final current = countFor(step);
    next[step.type.name] = current >= step.target ? current : current + 1;
    return GeoTaggingTestPlanProgress(completed: next);
  }

  Map<String, dynamic> toMap() => {'completed': completed};

  factory GeoTaggingTestPlanProgress.fromMap(Map<String, dynamic> map) {
    final source = Map<String, dynamic>.from(map['completed'] as Map? ?? {});
    return GeoTaggingTestPlanProgress(
      completed: source.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
    );
  }
}

class GeoTaggingTestPlanStore {
  static const _key = 'geo_tagging_test_plan_progress_v1';

  Future<GeoTaggingTestPlanProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return GeoTaggingTestPlanProgress.empty();
    try {
      return GeoTaggingTestPlanProgress.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return GeoTaggingTestPlanProgress.empty();
    }
  }

  Future<void> save(GeoTaggingTestPlanProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(progress.toMap()));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
