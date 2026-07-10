import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';
import 'package:hoyaid/features/classification/services/classification_service.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/shared/widgets/interactive.dart';

class ClassificationResultScreen extends ConsumerStatefulWidget {
  final ClassificationDraft? draft;

  const ClassificationResultScreen({
    super.key,
    required this.draft,
  });

  @override
  ConsumerState<ClassificationResultScreen> createState() =>
      _ClassificationResultScreenState();
}

class _ClassificationResultScreenState
    extends ConsumerState<ClassificationResultScreen> {
  ClassificationLocation? _location;
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  bool _isSaving = false;
  bool _isGettingGps = false;
  String? _saveFailureMessage;
  String? _pendingClassificationId;
  ClassificationSaveStage? _failedSaveStage;

  ClassificationDraft? get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _location = widget.draft?.initialLocation;
    _syncCoordinateFields(_location);
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _setLocation(ClassificationLocation? location) {
    setState(() {
      _location = location;
      _syncCoordinateFields(location);
    });
  }

  void _syncCoordinateFields(ClassificationLocation? location) {
    _latitudeController.text = location?.latitude.toStringAsFixed(6) ?? '';
    _longitudeController.text = location?.longitude.toStringAsFixed(6) ?? '';
  }

  bool _applyTypedCoordinates() {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    if (latitude == null || longitude == null) {
      _showLocationError('Latitude dan Longitude wajib diisi angka valid.');
      return false;
    }
    if (latitude < -90 || latitude > 90) {
      _showLocationError('Latitude harus berada di rentang -90 sampai 90.');
      return false;
    }
    if (longitude < -180 || longitude > 180) {
      _showLocationError('Longitude harus berada di rentang -180 sampai 180.');
      return false;
    }

    _location = ClassificationLocation(
      latitude: latitude,
      longitude: longitude,
      source: ClassificationLocationSource.manual,
    );
    return true;
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _useGpsLocation() async {
    setState(() => _isGettingGps = true);
    try {
      final location =
          await ref.read(locationServiceProvider).getCurrentLocation();
      if (!mounted) return;
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lokasi GPS belum tersedia.'),
            action: SnackBarAction(
              label: 'Pengaturan',
              onPressed: ref.read(locationServiceProvider).openLocationSettings,
            ),
          ),
        );
        return;
      }
      _setLocation(location);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              readableErrorMessage(
                error,
                fallback:
                    'Gagal membaca lokasi. Anda bisa memasang pin manual.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingGps = false);
    }
  }

  Future<void> _pickManualLocation() async {
    final location = await context
        .push<ClassificationLocation>('/classification/location-picker');
    if (location != null && mounted) {
      _setLocation(location);
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _isSaving) return;

    final user = ref.read(currentUserProvider);
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login untuk menyimpan hasil.')),
      );
      return;
    }

    final userData = ref.read(userDataProvider).valueOrNull;
    final uploadUsed = (userData?['uploadUsed'] as num?)?.toInt() ?? 0;
    final uploadLimit = (userData?['uploadLimit'] as num?)?.toInt() ?? 5;
    if (uploadUsed >= uploadLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kuota unggah penuh. Server akan menolak penyimpanan.'),
        ),
      );
      return;
    }

    if (!_applyTypedCoordinates()) return;

    if (draft.prediction.ood.isLikelyOod) {
      final shouldContinue = await _confirmOodSave();
      if (shouldContinue != true) return;
    }

    setState(() {
      _isSaving = true;
      _saveFailureMessage = null;
      _pendingClassificationId = null;
      _failedSaveStage = null;
    });
    try {
      final saved =
          await ref.read(classificationServiceProvider).saveClassification(
                prediction: draft.prediction,
                displayJpegBytes: draft.displayJpegBytes,
                displayImageSize: draft.displayImageSize,
                modelImageSize: draft.modelImageSize,
                location: _location,
              );
      await _cleanupSourceIfCache(draft.sourceImagePath);

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tersimpan'),
          content: Text(
            'Data klasifikasi berhasil disimpan dengan ID ${saved.classificationId}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/home');
    } on ClassificationSaveException catch (error) {
      if (!error.hasPendingDocument) {
        await _saveOffline(draft, user.uid);
        return;
      }
      final message = readableErrorMessage(error.cause);
      if (mounted) {
        setState(() {
          _saveFailureMessage = message;
          _pendingClassificationId = error.classificationId;
          _failedSaveStage = error.stage;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Coba Lagi',
              onPressed: _save,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = readableErrorMessage(error);
        setState(() => _saveFailureMessage = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Coba Lagi',
              onPressed: _save,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveOffline(
    ClassificationDraft draft,
    String userId,
  ) async {
    final item =
        await ref.read(offlineClassificationQueueServiceProvider).enqueue(
              userId: userId,
              prediction: draft.prediction,
              displayJpegBytes: draft.displayJpegBytes,
              displayImageSize: draft.displayImageSize,
              modelImageSize: draft.modelImageSize,
              location: _location,
            );
    ref.invalidate(pendingOfflineClassificationsProvider);
    await _cleanupSourceIfCache(draft.sourceImagePath);
    if (!mounted) return;
    setState(() {
      _saveFailureMessage = null;
      _pendingClassificationId = item.id;
      _failedSaveStage = null;
    });
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tersimpan Offline'),
        content: const Text(
          'Data klasifikasi disimpan di perangkat dan akan otomatis diupload saat internet kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) context.go('/home');
  }

  Future<bool?> _confirmOodSave() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prediksi Meragukan'),
        content: const Text(
          'Model memberi sinyal confidence rendah atau kemungkinan non-Hoya. '
          'Data tetap akan berstatus unverified jika disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tetap Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _cleanupSourceIfCache(String path) async {
    if (kIsWeb) return;
    final normalized = path.toLowerCase();
    if (!normalized.contains('cache')) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Cache cleanup should never block a successful save.
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hasil Klasifikasi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text('Draft klasifikasi tidak tersedia.'),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/classification'),
                  child: const Text('Ulangi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final speciesAsync =
        ref.watch(speciesDetailProvider(draft.prediction.speciesId));
    final userData = ref.watch(userDataProvider).valueOrNull;
    final uploadUsed = (userData?['uploadUsed'] as num?)?.toInt() ?? 0;
    final uploadLimit = (userData?['uploadLimit'] as num?)?.toInt() ?? 5;
    final quotaFull = uploadUsed >= uploadLimit;

    // Tentukan level OOD untuk mengontrol tampilan
    final oodLevel = draft.prediction.ood.level;
    final isRejected = oodLevel == OodLevel.rejected;

    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Klasifikasi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FadeSlideIn(
              child: _HeroImage(
                bytes: draft.displayJpegBytes,
                isRejected: isRejected,
              ),
            ),
            const SizedBox(height: 16),

            if (draft.imageQuality.hasWarning || draft.enhancementApplied) ...[
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _ImageQualityPanel(draft: draft),
              ),
              const SizedBox(height: 12),
            ],

            // Banner rejected — tampil sebelum header prediksi
            if (isRejected) ...[
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _RejectedBanner(prediction: draft.prediction),
              ),
              const SizedBox(height: 12),
            ],

            FadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: _PredictionHeader(draft: draft),
            ),

            // Warning uncertain (hanya bila bukan rejected)
            if (!isRejected &&
                (draft.prediction.ood.isLowConfidence ||
                    draft.prediction.ood.isLikelyOod)) ...[
              const SizedBox(height: 12),
              _WarningPanel(prediction: draft.prediction),
            ],
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 180),
              child: speciesAsync.when(
                data: (species) => _SpeciesInfoPanel(
                  speciesName:
                      species?.displayName ?? draft.prediction.speciesId,
                  description: species?.description,
                  distribution: species?.distribution,
                  medicalUse: species?.medicalUseDescription,
                ),
                loading: () => const SectionCard(
                  icon: Icons.local_florist_rounded,
                  title: 'Info Spesies',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 160, height: 18),
                      SizedBox(height: 10),
                      ShimmerBox(height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 220, height: 14),
                    ],
                  ),
                ),
                error: (_, __) => _SpeciesInfoPanel(
                  speciesName: draft.prediction.speciesId,
                  description: 'Info spesies belum tersedia.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: _TopPredictionsPanel(
                predictions: draft.prediction.topPredictions,
              ),
            ),
            const SizedBox(height: 16),
            // Panel lokasi hanya tampil jika bukan rejected
            if (!isRejected) ...[
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _LocationPanel(
                  location: _location,
                  latitudeController: _latitudeController,
                  longitudeController: _longitudeController,
                  isGettingGps: _isGettingGps,
                  onUseGps: _useGpsLocation,
                  onPickManual: _pickManualLocation,
                  onApplyCoordinates: () {
                    if (_applyTypedCoordinates()) setState(() {});
                  },
                  onClear: () => _setLocation(null),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _SavePanel(
              isSaving: _isSaving,
              quotaFull: quotaFull,
              isRejected: isRejected,
              uploadUsed: uploadUsed,
              uploadLimit: uploadLimit,
              failureMessage: _saveFailureMessage,
              pendingClassificationId: _pendingClassificationId,
              failedStage: _failedSaveStage,
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gambar hasil klasifikasi dengan sudut membulat besar + bayangan.
class _HeroImage extends StatelessWidget {
  final Uint8List bytes;
  final bool isRejected;

  const _HeroImage({required this.bytes, required this.isRejected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            // Greyed-out jika rejected agar user tahu ini hasil sangat meragukan
            color: isRejected ? Colors.grey.withValues(alpha: 0.55) : null,
            colorBlendMode: isRejected ? BlendMode.saturation : null,
          ),
        ),
      ),
    );
  }
}

/// Warna berdasarkan level confidence.
Color _confidenceColor(double confidence) {
  if (confidence >= 0.8) return const Color(0xFF2E9E5B);
  if (confidence >= 0.6) return const Color(0xFFE08B2D);
  return const Color(0xFFD64545);
}

String _confidenceLabel(double confidence) {
  if (confidence >= 0.8) return 'Keyakinan tinggi';
  if (confidence >= 0.6) return 'Keyakinan sedang';
  return 'Keyakinan rendah';
}

class _PredictionHeader extends StatelessWidget {
  final ClassificationDraft draft;

  const _PredictionHeader({required this.draft});

  @override
  Widget build(BuildContext context) {
    final prediction = draft.prediction;
    final confidence = prediction.confidence;
    final color = _confidenceColor(confidence);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.local_florist_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prediksi teratas',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prediction.speciesId,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _confidenceLabel(confidence),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              AnimatedCountUp(
                value: (confidence * 100).round(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedProgressBar(value: confidence, color: color, height: 12),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatChip(
                icon: Icons.memory_rounded,
                label: 'Model ${prediction.modelVersion}',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              StatChip(
                icon: Icons.analytics_outlined,
                label: 'OOD ${prediction.ood.score.toStringAsFixed(2)}',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              StatChip(
                icon: Icons.compare_arrows_rounded,
                label: 'Margin ${prediction.ood.topMargin.toStringAsFixed(2)}',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageQualityPanel extends StatelessWidget {
  final ClassificationDraft draft;

  const _ImageQualityPanel({required this.draft});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final report = draft.imageQuality;
    final metrics = [
      'Blur ${report.blurScore.toStringAsFixed(0)}',
      'Brightness ${report.brightness.toStringAsFixed(0)}',
      'Frame ${(report.contentFrameRatio * 100).toStringAsFixed(0)}%',
    ].join(' • ');

    return Material(
      color: Colors.amber.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.photo_camera_back_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pemeriksaan kualitas foto',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(report.userMessage),
                  if (draft.enhancementApplied) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Enhancement ringan diterapkan: brightness dan contrast dinaikkan secukupnya.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    metrics,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  final ClassificationPrediction prediction;

  const _WarningPanel({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final text = prediction.ood.isLikelyOod
        ? 'Foto ini terindikasi meragukan atau mungkin bukan Hoya. Verifikasi manual diperlukan.'
        : 'Confidence rendah. Hasil perlu diperiksa kembali.';

    return Material(
      color: Colors.orange.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _SpeciesInfoPanel extends StatelessWidget {
  final String speciesName;
  final String? description;
  final String? distribution;
  final String? medicalUse;

  const _SpeciesInfoPanel({
    required this.speciesName,
    this.description,
    this.distribution,
    this.medicalUse,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.local_florist_rounded,
      title: 'Info Spesies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            speciesName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
          if (distribution?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            const _MiniLabel(icon: Icons.public_rounded, text: 'Persebaran'),
            const SizedBox(height: 4),
            Text(distribution!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (medicalUse?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            const _MiniLabel(
                icon: Icons.medical_services_outlined,
                text: 'Pemanfaatan medis'),
            const SizedBox(height: 4),
            Text(medicalUse!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _TopPredictionsPanel extends StatelessWidget {
  final List<TopPrediction> predictions;

  const _TopPredictionsPanel({required this.predictions});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      icon: Icons.leaderboard_rounded,
      title: 'Kandidat Teratas',
      accent: const Color(0xFF0E9F9A),
      child: Column(
        children: [
          for (final (index, prediction) in predictions.indexed) ...[
            if (index > 0) const SizedBox(height: 14),
            _PredictionRow(
              rank: index + 1,
              prediction: prediction,
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  final int rank;
  final TopPrediction prediction;

  const _PredictionRow({required this.rank, required this.prediction});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final confidence = prediction.confidence.clamp(0.0, 1.0).toDouble();
    // Peringkat 1 memakai warna primer, sisanya lebih netral.
    final barColor = rank == 1 ? colorScheme.primary : colorScheme.tertiary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: barColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$rank',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      prediction.speciesId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(confidence * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: barColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedProgressBar(
                value: confidence,
                color: barColor,
                height: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationPanel extends StatelessWidget {
  final ClassificationLocation? location;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final bool isGettingGps;
  final VoidCallback onUseGps;
  final VoidCallback onPickManual;
  final VoidCallback onApplyCoordinates;
  final VoidCallback onClear;

  const _LocationPanel({
    required this.location,
    required this.latitudeController,
    required this.longitudeController,
    required this.isGettingGps,
    required this.onUseGps,
    required this.onPickManual,
    required this.onApplyCoordinates,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Lokasi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (location != null)
                  IconButton(
                    tooltip: 'Hapus lokasi',
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                location?.label ?? 'Lokasi wajib diisi sebelum data disimpan.'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '-6.200000',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '106.816666',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: isGettingGps ? null : onUseGps,
                  icon: isGettingGps
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('GPS'),
                ),
                OutlinedButton.icon(
                  onPressed: onPickManual,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Pilih di Map'),
                ),
                OutlinedButton.icon(
                  onPressed: onApplyCoordinates,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Gunakan Koordinat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavePanel extends StatelessWidget {
  final bool isSaving;
  final bool quotaFull;
  final bool isRejected;
  final int uploadUsed;
  final int uploadLimit;
  final String? failureMessage;
  final String? pendingClassificationId;
  final ClassificationSaveStage? failedStage;
  final VoidCallback onSave;

  const _SavePanel({
    required this.isSaving,
    required this.quotaFull,
    this.isRejected = false,
    required this.uploadUsed,
    required this.uploadLimit,
    this.failureMessage,
    this.pendingClassificationId,
    this.failedStage,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = isSaving || quotaFull || isRejected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: blocked ? null : onSave,
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: Text(isSaving ? 'Menyimpan...' : 'Simpan Hasil'),
        ),
        const SizedBox(height: 8),
        Text(
          isRejected
              ? 'Tidak dapat disimpan: prediksi tidak cukup yakin untuk data ini.'
              : failureMessage != null
                  ? 'Status: belum tersimpan. Tekan simpan untuk mencoba lagi.'
                  : quotaFull
                      ? 'Kuota penuh: $uploadUsed / $uploadLimit.'
                      : 'Status: belum tersimpan. Klasifikasi tetap bisa dilihat di layar ini sebelum disimpan.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isRejected ? Theme.of(context).colorScheme.error : null,
              ),
        ),
        if (failureMessage != null) ...[
          const SizedBox(height: 12),
          _SaveFailurePanel(
            message: failureMessage!,
            pendingClassificationId: pendingClassificationId,
            failedStage: failedStage,
          ),
        ],
      ],
    );
  }
}

class _SaveFailurePanel extends StatelessWidget {
  final String message;
  final String? pendingClassificationId;
  final ClassificationSaveStage? failedStage;

  const _SaveFailurePanel({
    required this.message,
    this.pendingClassificationId,
    this.failedStage,
  });

  @override
  Widget build(BuildContext context) {
    final hasPendingDocument =
        failedStage == ClassificationSaveStage.uploadImage ||
            failedStage == ClassificationSaveStage.finalize;

    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  if (hasPendingDocument) ...[
                    const SizedBox(height: 8),
                    Text(
                      pendingClassificationId == null
                          ? 'Metadata pending akan dibersihkan otomatis bila tidak selesai.'
                          : 'Dokumen pending $pendingClassificationId akan dibersihkan otomatis bila tidak selesai.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner: prediksi rejected (bukan spesies Hoya yang dikenal)
// ─────────────────────────────────────────────────────────────────────────────

class _RejectedBanner extends StatelessWidget {
  final ClassificationPrediction prediction;

  const _RejectedBanner({required this.prediction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF6A0000), Color(0xFFB71C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sentiment_dissatisfied_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bukan Spesies Hoya yang Dikenal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Model sangat tidak yakin dengan foto ini '
                  '(confidence ${(prediction.confidence * 100).toStringAsFixed(1)}%, '
                  'OOD score ${prediction.ood.score.toStringAsFixed(2)}). '
                  'Kemungkinan foto bukan Hoya atau kualitas gambar terlalu rendah.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.90),
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '💡 Kembali dan ambil foto ulang dengan pencahayaan lebih baik, fokus pada bagian tanaman.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.80),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
