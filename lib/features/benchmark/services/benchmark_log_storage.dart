import 'dart:io';

import 'package:hoyaid/features/benchmark/models/on_device_benchmark_models.dart';
import 'package:path_provider/path_provider.dart';

class BenchmarkLogStorage {
  static const _fileName = 'ihoya_on_device_benchmark.csv';

  static const _headers = [
    'timestamp',
    'manufacturer',
    'model',
    'android_version',
    'android_api',
    'chipset',
    'logical_cores',
    'device_ram_mb',
    'model_version',
    'model_size_bytes',
    'source_image',
    'warmup_runs',
    'measured_runs',
    'model_load_ms',
    'image_quality_ms',
    'preprocess_mean_ms',
    'preprocess_std_ms',
    'preprocess_p50_ms',
    'preprocess_p95_ms',
    'inference_mean_ms',
    'inference_std_ms',
    'inference_p50_ms',
    'inference_p95_ms',
    'core_mean_ms',
    'core_std_ms',
    'core_p95_ms',
    'cpu_mean_percent_total_cores',
    'cpu_peak_percent_total_cores',
    'pss_initial_mb',
    'pss_peak_mb',
    'pss_final_mb',
    'native_pss_peak_mb',
    'top_prediction',
    'confidence',
  ];

  Future<File> append(OnDeviceBenchmarkResult result) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    if (!await file.exists()) {
      await file.writeAsString('${_csvLine(_headers)}\n');
    }
    await file.writeAsString(
      '${_csvLine(result.csvValues)}\n',
      mode: FileMode.append,
      flush: true,
    );
    return file;
  }

  String _csvLine(List<String> values) => values
      .map((value) => '"${value.replaceAll('"', '""')}"')
      .join(',');
}
