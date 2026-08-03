import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/benchmark/services/geo_tagging_evaluation_service.dart';
import 'package:hoyaid/features/benchmark/services/geo_tagging_test_plan_store.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';

class GeoTaggingTestGuideScreen extends ConsumerStatefulWidget {
  const GeoTaggingTestGuideScreen({super.key});

  @override
  ConsumerState<GeoTaggingTestGuideScreen> createState() =>
      _GeoTaggingTestGuideScreenState();
}

class _GeoTaggingTestGuideScreenState
    extends ConsumerState<GeoTaggingTestGuideScreen> {
  final _store = GeoTaggingTestPlanStore();
  GeoTaggingTestPlanProgress? _progress;
  bool _isRunning = false;

  GeoTaggingEvaluationService get _evaluationService =>
      GeoTaggingEvaluationService(
        firestore: ref.read(activeFirestoreProvider),
        locationService: ref.read(locationServiceProvider),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await _store.load();
    if (mounted) setState(() => _progress = progress);
  }

  Future<bool> _confirm(
      {required String title, required String message}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Belum'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ya, lanjutkan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _markComplete(GeoTaggingPlanStep step) async {
    final current = _progress;
    if (current == null) return;
    final next = current.increment(step);
    await _store.save(next);
    if (mounted) setState(() => _progress = next);
  }

  Future<void> _runGpsStep(GeoTaggingPlanStep step) async {
    final allowed = await _confirm(
      title: 'Mulai ulangan GPS?',
      message: '${step.instruction}\n\nPastikan GPS dan lokasi presisi aktif.',
    );
    if (!allowed || _isRunning) return;
    setState(() => _isRunning = true);
    try {
      final condition = step.type == GeoTaggingPlanStepType.firstFixOutdoor
          ? GeoTagTestCondition.outdoor
          : GeoTagTestCondition.greenhouse;
      final sample = await _evaluationService.measureFirstFix(condition);
      if (sample == null) {
        throw StateError('GPS/izin lokasi belum aktif.');
      }
      await _markComplete(step);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ulangan tersimpan: ${(sample.durationMs / 1000).toStringAsFixed(1)} detik.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pengukuran gagal: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _openClassificationStep(GeoTaggingPlanStep step) async {
    final allowed = await _confirm(
      title: 'Mulai ${step.title}?',
      message:
          '${step.instruction}\n\nAplikasi akan membuka halaman klasifikasi.',
    );
    if (!allowed || !mounted) return;
    await context.push('/classification');
  }

  Future<void> _confirmClassificationStep(GeoTaggingPlanStep step) async {
    final saved = await _confirm(
      title: 'Konfirmasi ulangan',
      message:
          'Apakah satu rekaman sudah tersimpan sesuai petunjuk tahap ini? Pilih Ya hanya jika berhasil.',
    );
    if (saved) await _markComplete(step);
  }

  Future<void> _reset() async {
    final allowed = await _confirm(
      title: 'Ulang dari awal?',
      message:
          'Progres panduan akan dikosongkan. Rekaman Firestore tidak dihapus.',
    );
    if (!allowed) return;
    await _store.reset();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final step = progress.currentStep;
    final isFinished = step == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan Uji Geo-tagging'),
        actions: [
          IconButton(
            tooltip: 'Ulangi panduan dari awal',
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${progress.totalCompleted} dari ${progress.totalTarget} ulangan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.totalCompleted / progress.totalTarget,
              ),
              const SizedBox(height: 24),
              if (isFinished)
                _FinishCard(onViewReport: () => context.pop())
              else
                _CurrentStepCard(
                  step: step,
                  completed: progress.countFor(step),
                  isRunning: _isRunning,
                  onRun: step.requiresGpsMeasurement
                      ? () => _runGpsStep(step)
                      : null,
                  onOpenClassification: step.opensClassification
                      ? () => _openClassificationStep(step)
                      : null,
                  onConfirmClassification: step.opensClassification
                      ? () => _confirmClassificationStep(step)
                      : null,
                ),
              const Spacer(),
              Text(
                'Progres panduan tersimpan di perangkat. Angka hasil akhir tetap dihitung otomatis pada halaman Uji Geo-tagging.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentStepCard extends StatelessWidget {
  final GeoTaggingPlanStep step;
  final int completed;
  final bool isRunning;
  final VoidCallback? onRun;
  final VoidCallback? onOpenClassification;
  final VoidCallback? onConfirmClassification;

  const _CurrentStepCard({
    required this.step,
    required this.completed,
    required this.isRunning,
    this.onRun,
    this.onOpenClassification,
    this.onConfirmClassification,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = step.target - completed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tahap berikutnya',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(step.instruction),
            const SizedBox(height: 20),
            Text('Progres tahap: $completed/${step.target} • sisa $remaining'),
            const SizedBox(height: 14),
            if (step.requiresGpsMeasurement)
              FilledButton.icon(
                onPressed: isRunning ? null : onRun,
                icon: isRunning
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed_rounded),
                label: Text(isRunning ? 'Mengukur...' : 'Mulai 1 ulangan'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              )
            else ...[
              FilledButton.icon(
                onPressed: onOpenClassification,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Buka klasifikasi'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onConfirmClassification,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Konfirmasi 1 rekaman berhasil'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  final VoidCallback onViewReport;
  const _FinishCard({required this.onViewReport});

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded, size: 48),
              const SizedBox(height: 12),
              Text('Semua tahap selesai',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Kembali ke halaman Uji Geo-tagging untuk memuat ulang dan menyalin ringkasan laporan.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onViewReport,
                child: const Text('Lihat ringkasan'),
              ),
            ],
          ),
        ),
      );
}
