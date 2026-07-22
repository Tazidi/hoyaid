import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hoyaid/features/benchmark/models/d4_accuracy_evaluation_models.dart';
import 'package:hoyaid/features/benchmark/services/d4_accuracy_evaluation_service.dart';
import 'package:hoyaid/features/benchmark/services/d4_accuracy_log_storage.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';

class D4AccuracyEvaluationScreen extends ConsumerStatefulWidget {
  const D4AccuracyEvaluationScreen({super.key});

  @override
  ConsumerState<D4AccuracyEvaluationScreen> createState() =>
      _D4AccuracyEvaluationScreenState();
}

class _D4AccuracyEvaluationScreenState
    extends ConsumerState<D4AccuracyEvaluationScreen> {
  String? _datasetRoot;
  D4AccuracyEvaluationResult? _result;
  D4AccuracyLogFiles? _logFiles;
  String? _error;
  bool _isRunning = false;
  int _completed = 0;
  int _total = 355;
  String? _currentFile;

  @override
  void initState() {
    super.initState();
    _useAppDatasetRoot();
  }

  Future<void> _useAppDatasetRoot() async {
    final external = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    if (external == null) {
      setState(() => _error = 'Penyimpanan eksternal aplikasi tidak tersedia.');
      return;
    }
    setState(() {
      _datasetRoot =
          '${external.path}${Platform.pathSeparator}mobile_d4_test';
      _result = null;
      _logFiles = null;
      _error = null;
    });
  }

  Future<void> _pickDatasetRoot() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih folder mobile_d4_test',
      );
      if (!mounted || path == null) return;
      setState(() {
        _datasetRoot = path;
        _result = null;
        _logFiles = null;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Gagal memilih folder data uji: $error');
      }
    }
  }

  Future<void> _run() async {
    final datasetRoot = _datasetRoot;
    if (datasetRoot == null || _isRunning) return;
    if (!Platform.isAndroid) {
      setState(() => _error = 'Evaluasi ini hanya dapat dijalankan di HP Android fisik.');
      return;
    }

    setState(() {
      _isRunning = true;
      _result = null;
      _logFiles = null;
      _error = null;
      _completed = 0;
      _total = 355;
      _currentFile = null;
    });
    try {
      final evaluator = D4AccuracyEvaluationService(
        preprocessService: ref.read(imagePreprocessServiceProvider),
        tfliteService: ref.read(tfliteServiceProvider),
      );
      final result = await evaluator.run(
        mobileDatasetRoot: datasetRoot,
        onProgress: ({required completed, required total, required currentFile}) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
            _currentFile = currentFile;
          });
        },
      );
      final logs = await D4AccuracyLogStorage().save(result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _logFiles = logs;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Evaluasi D4 gagal: $error');
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
        const SnackBar(content: Text('Ringkasan evaluasi berhasil disalin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Uji Akurasi D4')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const _ProtocolCard(),
            const SizedBox(height: 16),
            _DatasetSelector(
              rootPath: _datasetRoot,
              isRunning: _isRunning,
              onTap: _useAppDatasetRoot,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _datasetRoot == null || _isRunning ? null : _run,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _isRunning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _isRunning
                    ? 'Menguji $_completed/$_total citra...'
                    : 'Mulai evaluasi 355 citra D4',
              ),
            ),
            if (_isRunning) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _total == 0 ? null : _completed / _total,
              ),
              const SizedBox(height: 8),
              Text(
                _currentFile == null
                    ? 'Menyiapkan model lokal...'
                    : 'Memproses: $_currentFile',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Biarkan aplikasi tetap terbuka sampai seluruh 355 citra selesai.',
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
              _ResultCard(result: _result!, logFiles: _logFiles),
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

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Evaluasi TFLite on-device — D4',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Gunakan folder mobile_d4_test hasil script desktop. Mode ini '
              'memakai model aset lokal dan preprocessing kanonik: EXIF transpose, '
              'RGB, resize-with-pad 224×224, nilai piksel 0–255.',
            ),
            SizedBox(height: 8),
            Text(
              'GPS, Firebase, riwayat, upload, dan pemeriksa kualitas gambar '
              'tidak dijalankan. Nilai ini khusus untuk membandingkan FP32 desktop '
              'dengan TFLite Android secara terkendali.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatasetSelector extends StatelessWidget {
  final String? rootPath;
  final bool isRunning;
  final VoidCallback onTap;

  const _DatasetSelector({
    required this.rootPath,
    required this.isRunning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedPath = rootPath;
    return Card(
      child: InkWell(
        onTap: isRunning ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.folder_copy_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedPath == null
                          ? 'Pilih folder mobile_d4_test'
                          : _lastSegment(selectedPath),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedPath == null
                          ? 'Di dalamnya harus ada d4_test_manifest.csv dan folder images/.'
                          : selectedPath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  String _lastSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').where((part) => part.isNotEmpty).last;
  }
}

class _ResultCard extends StatelessWidget {
  final D4AccuracyEvaluationResult result;
  final D4AccuracyLogFiles? logFiles;

  const _ResultCard({required this.result, required this.logFiles});

  @override
  Widget build(BuildContext context) {
    final metrics = result.metrics;
    final isComplete = metrics.evaluatedSamples == result.expectedSamples;
    final rows = [
      _Metric('Model TFLite', '${result.modelVersion} · ${(result.modelSizeBytes / 1000000).toStringAsFixed(2)} MB'),
      _Metric('Data diproses', '${metrics.evaluatedSamples}/${result.expectedSamples} · gagal ${result.failedSamples}'),
      _Metric('Accuracy top-1', '${metrics.accuracy.toStringAsFixed(4)} (${metrics.correctTop1}/${metrics.evaluatedSamples})'),
      _Metric('Macro precision', metrics.macroPrecision.toStringAsFixed(4)),
      _Metric('Macro recall', metrics.macroRecall.toStringAsFixed(4)),
      _Metric('Macro-F1', metrics.macroF1.toStringAsFixed(4)),
      _Metric('Top-3 accuracy', '${metrics.top3Accuracy.toStringAsFixed(4)} (${metrics.correctTop3}/${metrics.evaluatedSamples})'),
      _Metric('Rata-rata preprocessing', '${result.meanPreprocessingMs.toStringAsFixed(2)} ms/citra'),
      _Metric('Rata-rata inferensi', '${result.meanInferenceMs.toStringAsFixed(2)} ms/citra'),
      _Metric('Durasi keseluruhan', '${result.elapsed.inMinutes} m ${result.elapsed.inSeconds.remainder(60)} d'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil evaluasi on-device',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            if (!isComplete)
              Text(
                'Jangan bandingkan metrik ini dengan desktop sebelum semua 355 citra berhasil diproses.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!isComplete) const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(0.92),
                1: FlexColumnWidth(1.35),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
            if (logFiles != null) ...[
              const SizedBox(height: 12),
              Text(
                'CSV: ${logFiles!.predictionsCsv.path}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'JSON: ${logFiles!.summaryJson.path}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;

  const _Metric(this.label, this.value);
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
