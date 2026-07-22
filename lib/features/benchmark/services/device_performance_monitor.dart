import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hoyaid/features/benchmark/models/on_device_benchmark_models.dart';

class DevicePerformanceMonitor {
  static const MethodChannel _channel = MethodChannel(
    'com.tazidi.hoyaid/performance_monitor',
  );

  Future<BenchmarkDeviceInfo> getDeviceInfo() async {
    _ensureAndroid();
    final data = await _channel.invokeMapMethod<Object?, Object?>('deviceInfo');
    if (data == null) {
      throw StateError('Informasi perangkat tidak dapat dibaca.');
    }
    return BenchmarkDeviceInfo.fromMap(data);
  }

  Future<void> start({int sampleIntervalMs = 100}) async {
    _ensureAndroid();
    await _channel.invokeMethod<void>('start', {
      'sampleIntervalMs': sampleIntervalMs,
    });
  }

  Future<ProcessResourceUsage> stop() async {
    _ensureAndroid();
    final data = await _channel.invokeMapMethod<Object?, Object?>('stop');
    if (data == null) {
      throw StateError('Data penggunaan sumber daya tidak tersedia.');
    }
    return ProcessResourceUsage.fromMap(data);
  }

  void _ensureAndroid() {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Pengujian sumber daya ini hanya tersedia pada perangkat Android.',
      );
    }
  }
}
