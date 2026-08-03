import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/benchmark/services/geo_tagging_evaluation_service.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';

class GeoTaggingEvaluationScreen extends ConsumerStatefulWidget {
  const GeoTaggingEvaluationScreen({super.key});

  @override
  ConsumerState<GeoTaggingEvaluationScreen> createState() =>
      _GeoTaggingEvaluationScreenState();
}

class _GeoTaggingEvaluationScreenState
    extends ConsumerState<GeoTaggingEvaluationScreen> {
  GeoTagTestCondition _condition = GeoTagTestCondition.outdoor;
  GeoTaggingReport? _report;
  bool _isLoading = true;
  bool _isMeasuring = false;
  String? _error;

  GeoTaggingEvaluationService get _service => GeoTaggingEvaluationService(
        firestore: ref.read(activeFirestoreProvider),
        locationService: ref.read(locationServiceProvider),
      );

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final report = await _service.buildReport();
      if (mounted) setState(() => _report = report);
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Gagal membaca data Firestore: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _measure() async {
    if (_isMeasuring) return;
    setState(() {
      _isMeasuring = true;
      _error = null;
    });
    try {
      final sample = await _service.measureFirstFix(_condition);
      if (sample == null) {
        throw StateError(
            'Izin/layanan lokasi belum aktif. Aktifkan GPS lalu ulangi.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Koordinat pertama diterima dalam '
            '${(sample.durationMs / 1000).toStringAsFixed(1)} detik '
            '(akurasi ${sample.accuracyMeters?.toStringAsFixed(1) ?? '-'} m).',
          ),
        ),
      );
      await _loadReport();
    } catch (error) {
      if (mounted) setState(() => _error = 'Pengujian GPS gagal: $error');
    } finally {
      if (mounted) setState(() => _isMeasuring = false);
    }
  }

  Future<void> _copyReport() async {
    final report = _report;
    if (report == null) return;
    await Clipboard.setData(ClipboardData(text: report.clipboardText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ringkasan berhasil disalin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uji Geo-tagging'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang statistik',
            onPressed: _isLoading ? null : _loadReport,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _InfoCard(),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () async {
                await context.push('/benchmark/geo-tagging/guide');
                if (mounted) _loadReport();
              },
              icon: const Icon(Icons.format_list_numbered_rounded),
              label:
                  const Text('Ikuti panduan pengujian (6 tahap, 25 ulangan)'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 20),
            Text('Kondisi pengambilan',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final condition in GeoTagTestCondition.values)
                  ChoiceChip(
                    label: Text(condition.label),
                    selected: _condition == condition,
                    onSelected: _isMeasuring
                        ? null
                        : (_) => setState(() => _condition = condition),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isMeasuring ? null : _measure,
              icon: _isMeasuring
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed_rounded),
              label: Text(_isMeasuring
                  ? 'Menunggu koordinat pertama...'
                  : 'Mulai uji first GPS fix'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_isMeasuring) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _MessageCard(message: _error!, isError: true),
            ],
            const SizedBox(height: 22),
            if (_isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (report != null) ...[
              Text('Ringkasan untuk laporan',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              _ResultCard(
                title: 'a. Rekaman ber-geo-tag',
                value: 'n = ${report.geoTaggedCount} rekaman',
                detail:
                    'Dokumen aktif dengan latitude dan longitude lengkap di Cloud Firestore.',
              ),
              _ResultCard(
                title: 'b. Waktu first GPS fix',
                value: GeoTagTestCondition.values
                    .map((condition) =>
                        '${condition.label}:\n${report.firstFixByCondition[condition]!.format(unit: 'detik')}')
                    .join('\n\n'),
                detail: 'Jalankan tombol pengujian berulang pada tiap kondisi.',
              ),
              _ResultCard(
                title: 'c. Akurasi horizontal GPS',
                value: report.gpsAccuracy.format(unit: 'm'),
                detail:
                    'Dihitung dari field locationAccuracy pada rekaman GPS.',
              ),
              _ResultCard(
                title: 'd. Koordinat manual',
                value:
                    '${report.manualCount} dari ${report.geoTaggedCount} rekaman '
                    '(${report.manualPercentage.toStringAsFixed(1)}%)',
                detail: 'Berdasarkan field locationSource = manual.',
              ),
              _ResultCard(
                title: 'e. Sinkronisasi offline → online',
                value:
                    '${report.offlineSynced} dari ${report.offlineTotal} rekaman '
                    '(${report.offlineSuccessPercentage.toStringAsFixed(1)}%)',
                detail:
                    'Waktu sinkronisasi: ${report.offlineSyncDuration.format(unit: 'detik')}. '
                    'Keberhasilan dicatat sesudah dokumen dan citra diverifikasi.',
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _copyReport,
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Salin ringkasan untuk laporan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Pilih kondisi, lalu tekan tombol setiap kali melakukan satu ulangan. '
          'Waktu dihitung sejak aplikasi mengirim permintaan lokasi berakurasi tinggi '
          'hingga koordinat pertama diterima; dialog izin tidak dihitung. Untuk uji offline, '
          'matikan internet, simpan klasifikasi, lalu aktifkan internet kembali—hasil sinkronisasi '
          'akan masuk otomatis ke ringkasan ini.',
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final bool isError;
  const _MessageCard({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) => Card(
        color: isError ? Theme.of(context).colorScheme.errorContainer : null,
        child: Padding(padding: const EdgeInsets.all(14), child: Text(message)),
      );
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String value;
  final String detail;
  const _ResultCard({
    required this.title,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
