import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/features/benchmark/models/on_device_benchmark_models.dart';
import 'package:hoyaid/features/benchmark/services/benchmark_log_storage.dart';
import 'package:hoyaid/features/benchmark/services/on_device_benchmark_service.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';
import 'package:image_picker/image_picker.dart';

class OnDeviceBenchmarkScreen extends ConsumerStatefulWidget {
  const OnDeviceBenchmarkScreen({super.key});

  @override
  ConsumerState<OnDeviceBenchmarkScreen> createState() =>
      _OnDeviceBenchmarkScreenState();
}

class _OnDeviceBenchmarkScreenState
    extends ConsumerState<OnDeviceBenchmarkScreen> {
  static const _warmupRuns = 5;
  static const _measuredRuns = 30;

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  OnDeviceBenchmarkResult? _result;
  String? _logPath;
  String? _error;
  bool _isRunning = false;

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
        maxWidth: 2400,
      );
      if (!mounted || image == null) return;
      setState(() {
        _selectedImage = image;
        _result = null;
        _logPath = null;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Gagal memilih foto: $error');
    }
  }

  Future<void> _runBenchmark() async {
    final image = _selectedImage;
    if (image == null || _isRunning) return;
    if (!Platform.isAndroid) {
      setState(() => _error = 'Pengujian ini hanya dapat dijalankan di Android.');
      return;
    }

    setState(() {
      _isRunning = true;
      _result = null;
      _logPath = null;
      _error = null;
    });

    try {
      final benchmark = OnDeviceBenchmarkService(
        configService: ref.read(classificationConfigServiceProvider),
        labelMapService: ref.read(labelMapServiceProvider),
        imagePreprocessService: ref.read(imagePreprocessServiceProvider),
        imageQualityService: ref.read(imageQualityServiceProvider),
        tfliteService: ref.read(tfliteServiceProvider),
      );
      final result = await benchmark.run(
        imagePath: image.path,
        warmupRuns: _warmupRuns,
        measuredRuns: _measuredRuns,
      );
      final log = await BenchmarkLogStorage().append(result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _logPath = log.path;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Pengujian gagal: $error');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _copyResult() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.clipboardText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ringkasan berhasil disalin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengujian Perangkat')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _InfoCard(colorScheme: colorScheme),
            const SizedBox(height: 16),
            _ImageSelector(
              image: _selectedImage,
              isRunning: _isRunning,
              onPick: _pickImage,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _selectedImage == null || _isRunning
                  ? null
                  : _runBenchmark,
              icon: _isRunning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _isRunning
                    ? 'Mengukur $_measuredRuns kali...'
                    : 'Mulai uji ($_warmupRuns warm-up + $_measuredRuns pengukuran)',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_isRunning) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Jangan pindah aplikasi sampai pengukuran selesai.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultPanel(result: _result!, logPath: _logPath),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copyResult,
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Salin ringkasan untuk tabel laporan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _InfoCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: colorScheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Text(
                  'Benchmark TFLite lokal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pilih satu foto. Aplikasi memanaskan model 5 kali lalu mengukur '
              'preprocessing dan inferensi 30 kali. GPS, Firestore, unggah, dan '
              'penyimpanan hasil tidak dihitung.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSelector extends StatelessWidget {
  final XFile? image;
  final bool isRunning;
  final VoidCallback onPick;

  const _ImageSelector({
    required this.image,
    required this.isRunning,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final selected = image;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isRunning ? null : onPick,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (selected != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(selected.path),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected == null ? 'Pilih foto uji' : _fileName(selected.path),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected == null
                          ? 'Gunakan foto Hoya yang sama untuk seluruh perangkat.'
                          : 'Ketuk untuk mengganti foto.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.photo_library_outlined),
            ],
          ),
        ),
      ),
    );
  }

  String _fileName(String path) => path.split(Platform.pathSeparator).last;
}

class _ResultPanel extends StatelessWidget {
  final OnDeviceBenchmarkResult result;
  final String? logPath;

  const _ResultPanel({required this.result, required this.logPath});

  @override
  Widget build(BuildContext context) {
    final rows = <_MetricRowData>[
      _MetricRowData('Perangkat', result.device.deviceLabel),
      _MetricRowData(
        'Android / chipset',
        '${result.device.androidVersion} (API ${result.device.androidApiLevel}) · '
            '${result.device.chipset}',
      ),
      _MetricRowData(
        'Model TFLite',
        '${result.modelVersion} · ${result.modelSizeMb.toStringAsFixed(2)} MB '
            '(${result.modelSizeMib.toStringAsFixed(2)} MiB)',
      ),
      _MetricRowData('Load model dingin', _ms(result.modelLoadMs)),
      _MetricRowData('Analisis kualitas (1×)', _ms(result.imageQualityMs)),
      _MetricRowData(
        'Preprocessing ($_runs)',
        _latency(result.preprocessing),
      ),
      _MetricRowData('Inferensi TFLite ($_runs)', _latency(result.inference)),
      _MetricRowData('Total inti ($_runs)', _latency(result.coreProcessing)),
      _MetricRowData(
        'CPU aplikasi',
        '${result.resources.meanCpuPercent.toStringAsFixed(1)}% rata-rata · '
            '${result.resources.peakCpuPercent.toStringAsFixed(1)}% puncak',
      ),
      _MetricRowData(
        'RAM aplikasi (PSS)',
        '${result.resources.initialPssMb.toStringAsFixed(1)} → '
            '${result.resources.peakPssMb.toStringAsFixed(1)} → '
            '${result.resources.finalPssMb.toStringAsFixed(1)} MB',
      ),
      _MetricRowData(
        'Prediksi uji',
        '${result.topPrediction} (${(result.confidence * 100).toStringAsFixed(1)}%)',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil pengujian on-device',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Format latency: mean ± std; P50; P95. CPU adalah penggunaan '
              'proses aplikasi terhadap seluruh inti logis perangkat.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {0: FlexColumnWidth(0.9), 1: FlexColumnWidth(1.3)},
              border: TableBorder.symmetric(
                inside: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              children: [
                for (final row in rows)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          row.label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(row.value),
                      ),
                    ],
                  ),
              ],
            ),
            if (logPath != null) ...[
              const SizedBox(height: 12),
              Text(
                'CSV tersimpan di penyimpanan internal aplikasi. Salin ringkasan '
                'di bawah untuk langsung memindahkan angka ke tabel laporan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _runs => '${result.measuredRuns}×';

  String _ms(double value) => '${value.toStringAsFixed(1)} ms';

  String _latency(LatencyStatistics value) =>
      '${value.meanMs.toStringAsFixed(1)} ± ${value.standardDeviationMs.toStringAsFixed(1)} ms\n'
      'P50 ${value.medianMs.toStringAsFixed(1)} · P95 ${value.p95Ms.toStringAsFixed(1)} ms';
}

class _MetricRowData {
  final String label;
  final String value;

  const _MetricRowData(this.label, this.value);
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
