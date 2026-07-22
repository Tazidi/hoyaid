import 'dart:math' as math;

class LatencyStatistics {
  final int sampleCount;
  final double meanMs;
  final double standardDeviationMs;
  final double medianMs;
  final double p95Ms;
  final double minimumMs;
  final double maximumMs;

  const LatencyStatistics({
    required this.sampleCount,
    required this.meanMs,
    required this.standardDeviationMs,
    required this.medianMs,
    required this.p95Ms,
    required this.minimumMs,
    required this.maximumMs,
  });

  factory LatencyStatistics.fromSamples(List<double> samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'Tidak boleh kosong.');
    }

    final sorted = List<double>.from(samples)..sort();
    final count = sorted.length;
    final mean = sorted.reduce((a, b) => a + b) / count;
    final variance = sorted
            .map((sample) => math.pow(sample - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        count;
    final middle = count ~/ 2;
    final median = count.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
    final p95Index = ((count * 0.95).ceil() - 1).clamp(0, count - 1);

    return LatencyStatistics(
      sampleCount: count,
      meanMs: mean,
      standardDeviationMs: math.sqrt(variance),
      medianMs: median,
      p95Ms: sorted[p95Index],
      minimumMs: sorted.first,
      maximumMs: sorted.last,
    );
  }
}

class BenchmarkDeviceInfo {
  final String manufacturer;
  final String model;
  final String androidVersion;
  final int androidApiLevel;
  final String chipset;
  final int processorCount;
  final double totalRamMb;

  const BenchmarkDeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.androidApiLevel,
    required this.chipset,
    required this.processorCount,
    required this.totalRamMb,
  });

  String get deviceLabel => '$manufacturer $model';

  factory BenchmarkDeviceInfo.fromMap(Map<Object?, Object?> data) {
    String readString(String key, [String fallback = '-']) =>
        data[key]?.toString() ?? fallback;
    int readInt(String key) => (data[key] as num?)?.toInt() ?? 0;
    double readDouble(String key) => (data[key] as num?)?.toDouble() ?? 0;

    return BenchmarkDeviceInfo(
      manufacturer: readString('manufacturer'),
      model: readString('model'),
      androidVersion: readString('androidVersion'),
      androidApiLevel: readInt('androidApiLevel'),
      chipset: readString('chipset'),
      processorCount: readInt('processorCount'),
      totalRamMb: readDouble('totalRamMb'),
    );
  }
}

class ProcessResourceUsage {
  final double meanCpuPercent;
  final double peakCpuPercent;
  final double initialPssMb;
  final double peakPssMb;
  final double finalPssMb;
  final double peakNativePssMb;
  final int sampleCount;

  const ProcessResourceUsage({
    required this.meanCpuPercent,
    required this.peakCpuPercent,
    required this.initialPssMb,
    required this.peakPssMb,
    required this.finalPssMb,
    required this.peakNativePssMb,
    required this.sampleCount,
  });

  factory ProcessResourceUsage.fromMap(Map<Object?, Object?> data) {
    double readDouble(String key) => (data[key] as num?)?.toDouble() ?? 0;
    return ProcessResourceUsage(
      meanCpuPercent: readDouble('meanCpuPercent'),
      peakCpuPercent: readDouble('peakCpuPercent'),
      initialPssMb: readDouble('initialPssMb'),
      peakPssMb: readDouble('peakPssMb'),
      finalPssMb: readDouble('finalPssMb'),
      peakNativePssMb: readDouble('peakNativePssMb'),
      sampleCount: (data['sampleCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class OnDeviceBenchmarkResult {
  final DateTime createdAt;
  final String sourceImageName;
  final String modelVersion;
  final int modelSizeBytes;
  final int warmupRuns;
  final int measuredRuns;
  final double modelLoadMs;
  final double imageQualityMs;
  final LatencyStatistics preprocessing;
  final LatencyStatistics inference;
  final LatencyStatistics coreProcessing;
  final ProcessResourceUsage resources;
  final BenchmarkDeviceInfo device;
  final String topPrediction;
  final double confidence;

  const OnDeviceBenchmarkResult({
    required this.createdAt,
    required this.sourceImageName,
    required this.modelVersion,
    required this.modelSizeBytes,
    required this.warmupRuns,
    required this.measuredRuns,
    required this.modelLoadMs,
    required this.imageQualityMs,
    required this.preprocessing,
    required this.inference,
    required this.coreProcessing,
    required this.resources,
    required this.device,
    required this.topPrediction,
    required this.confidence,
  });

  double get modelSizeMb => modelSizeBytes / 1000 / 1000;
  double get modelSizeMib => modelSizeBytes / 1024 / 1024;

  String get clipboardText => '''Pengujian on-device iHoya
Waktu: ${createdAt.toIso8601String()}
Perangkat: ${device.deviceLabel}; Android ${device.androidVersion} (API ${device.androidApiLevel})
Chipset: ${device.chipset}; CPU logis: ${device.processorCount}; RAM perangkat: ${device.totalRamMb.toStringAsFixed(0)} MB
Model: $modelVersion; ${modelSizeMb.toStringAsFixed(2)} MB (${modelSizeMib.toStringAsFixed(2)} MiB)
Foto uji: $sourceImageName
Warm-up / pengukuran: $warmupRuns / $measuredRuns
Load model (cold): ${modelLoadMs.toStringAsFixed(1)} ms
Analisis kualitas (sekali): ${imageQualityMs.toStringAsFixed(1)} ms
Preprocessing: mean ${preprocessing.meanMs.toStringAsFixed(1)} ± ${preprocessing.standardDeviationMs.toStringAsFixed(1)} ms; P50 ${preprocessing.medianMs.toStringAsFixed(1)} ms; P95 ${preprocessing.p95Ms.toStringAsFixed(1)} ms
Inferensi TFLite: mean ${inference.meanMs.toStringAsFixed(1)} ± ${inference.standardDeviationMs.toStringAsFixed(1)} ms; P50 ${inference.medianMs.toStringAsFixed(1)} ms; P95 ${inference.p95Ms.toStringAsFixed(1)} ms
Total inti (preprocess + inferensi): mean ${coreProcessing.meanMs.toStringAsFixed(1)} ± ${coreProcessing.standardDeviationMs.toStringAsFixed(1)} ms; P95 ${coreProcessing.p95Ms.toStringAsFixed(1)} ms
CPU aplikasi (% seluruh inti): mean ${resources.meanCpuPercent.toStringAsFixed(1)}%; puncak ${resources.peakCpuPercent.toStringAsFixed(1)}%
RAM PSS aplikasi: awal ${resources.initialPssMb.toStringAsFixed(1)} MB; puncak ${resources.peakPssMb.toStringAsFixed(1)} MB; akhir ${resources.finalPssMb.toStringAsFixed(1)} MB
Prediksi akhir: $topPrediction (${(confidence * 100).toStringAsFixed(1)}%)
Catatan: GPS, Firestore, unggah, dan penyimpanan hasil tidak termasuk pengukuran inti.''';

  List<String> get csvValues => [
        createdAt.toIso8601String(),
        device.manufacturer,
        device.model,
        device.androidVersion,
        device.androidApiLevel.toString(),
        device.chipset,
        device.processorCount.toString(),
        device.totalRamMb.toStringAsFixed(1),
        modelVersion,
        modelSizeBytes.toString(),
        sourceImageName,
        warmupRuns.toString(),
        measuredRuns.toString(),
        modelLoadMs.toStringAsFixed(3),
        imageQualityMs.toStringAsFixed(3),
        preprocessing.meanMs.toStringAsFixed(3),
        preprocessing.standardDeviationMs.toStringAsFixed(3),
        preprocessing.medianMs.toStringAsFixed(3),
        preprocessing.p95Ms.toStringAsFixed(3),
        inference.meanMs.toStringAsFixed(3),
        inference.standardDeviationMs.toStringAsFixed(3),
        inference.medianMs.toStringAsFixed(3),
        inference.p95Ms.toStringAsFixed(3),
        coreProcessing.meanMs.toStringAsFixed(3),
        coreProcessing.standardDeviationMs.toStringAsFixed(3),
        coreProcessing.p95Ms.toStringAsFixed(3),
        resources.meanCpuPercent.toStringAsFixed(3),
        resources.peakCpuPercent.toStringAsFixed(3),
        resources.initialPssMb.toStringAsFixed(3),
        resources.peakPssMb.toStringAsFixed(3),
        resources.finalPssMb.toStringAsFixed(3),
        resources.peakNativePssMb.toStringAsFixed(3),
        topPrediction,
        confidence.toStringAsFixed(5),
      ];
}
