import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/admin/providers/admin_provider.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';
import 'package:hoyaid/features/history/providers/history_provider.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/shared/widgets/interactive.dart';
import 'package:intl/intl.dart';

class ClassificationDetailScreen extends ConsumerWidget {
  final String classificationId;

  const ClassificationDetailScreen({
    super.key,
    required this.classificationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync =
        ref.watch(classificationDetailProvider(classificationId));
    final species = ref.watch(activeSpeciesProvider).valueOrNull ?? [];
    final speciesById = {
      for (final item in species) item.speciesId: item,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Riwayat')),
      body: detailAsync.when(
        data: (record) {
          if (record == null) {
            return const _DetailEmptyState(
              icon: Icons.search_off_outlined,
              title: 'Data tidak ditemukan',
              message: 'Riwayat ini mungkin sudah dihapus atau diarsipkan.',
            );
          }

          return _DetailBody(
            record: record,
            species: species,
            speciesById: speciesById,
          );
        },
        loading: () => const _DetailLoadingSkeleton(),
        error: (error, _) => _DetailEmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat detail',
          message: readableErrorMessage(
            error,
            fallback: 'Gagal memuat detail. Periksa koneksi lalu coba lagi.',
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  final ClassificationRecord record;
  final List<HoyaSpecies> species;
  final Map<String, HoyaSpecies> speciesById;

  const _DetailBody({
    required this.record,
    required this.species,
    required this.speciesById,
  });

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _isWorking = false;

  ClassificationRecord get record => widget.record;

  Future<void> _correctLabel() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CorrectionSheet(
        species: widget.species,
        initialSpeciesId: record.speciesId,
      ),
    );
    if (selected == null || selected == record.speciesId) return;

    await _runAction(
      successMessage: 'Label berhasil dikoreksi.',
      action: () => ref.read(historyServiceProvider).correctClassificationLabel(
            classificationId: record.classificationId,
            speciesId: selected,
          ),
    );
  }

  Future<void> _deleteRecord() async {
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus & Arsipkan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gambar akan dihapus dari Storage, metadata dipindahkan ke arsip, dan kuota aktif dikurangi.',
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => reason = value,
              decoration: const InputDecoration(
                labelText: 'Alasan',
                hintText: 'Opsional',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    reason = reason.trim();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);

    await _runAction(
      successMessage: 'Data sudah diarsipkan dan dihapus.',
      action: () =>
          ref.read(historyServiceProvider).archiveAndDeleteClassification(
                classificationId: record.classificationId,
                reason: reason.isEmpty ? null : reason,
              ),
      onSuccess: () {
        if (route?.isCurrent ?? false) navigator.pop();
      },
    );
  }

  Future<void> _setVerificationStatus(String status) async {
    await _runAction(
      successMessage: 'Status verifikasi diperbarui.',
      action: () => ref.read(adminServiceProvider).setVerificationStatus(
            classificationId: record.classificationId,
            status: status,
          ),
    );
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String successMessage,
    VoidCallback? onSuccess,
  }) async {
    if (_isWorking) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isWorking = true);
    try {
      await action();
      onSuccess?.call();
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(readableErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final userData = ref.watch(userDataProvider).valueOrNull;
    final isAdmin = userData?['role'] == 'admin';
    final isOwner = user?.uid == record.userId;
    final canMutate = isAdmin || (isOwner && user?.isAnonymous != true);
    final speciesName =
        widget.speciesById[record.speciesId]?.displayName ?? record.speciesId;
    final predictedName =
        widget.speciesById[record.modelPredictedSpeciesId]?.displayName ??
            record.modelPredictedSpeciesId;
    final correctedName = record.correctedSpeciesId == null
        ? null
        : widget.speciesById[record.correctedSpeciesId]?.displayName ??
            record.correctedSpeciesId;
    final createdAt = record.createdAt == null
        ? '-'
        : DateFormat('dd MMM yyyy HH:mm').format(record.createdAt!);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FadeSlideIn(
          child: _DetailHeroImage(imageUrl: record.imageUrl),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 70),
          child: _VerificationBadge(record: record),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 130),
          child: _InfoCard(
            title: speciesName,
            rows: [
              _InfoRow('Dibuat', createdAt),
              _InfoRow('Status data', record.status),
              _InfoRow('Verifikasi', record.verificationLabel),
              _InfoRow('Confidence', record.confidencePercent),
              _InfoRow('Bucket', record.confidenceBucket),
              if (record.oodScore != null)
                _InfoRow('OOD score', record.oodScore!.toStringAsFixed(2)),
              _InfoRow('Model', record.modelVersion),
              _InfoRow('Prediksi model', predictedName),
              if (correctedName != null)
                _InfoRow('Koreksi label', correctedName),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 190),
          child: _LocationCard(record: record),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 250),
          child: _PredictionCard(
            predictions: record.topPredictions,
            speciesById: widget.speciesById,
          ),
        ),
        const SizedBox(height: 12),
        if (isAdmin) ...[
          _InfoCard(
            title: 'Audit',
            rows: [
              _InfoRow('ID klasifikasi', record.classificationId),
              _InfoRow('User ID', record.userId),
              _InfoRow('Path gambar', record.imageStoragePath ?? '-'),
              _InfoRow('Date bucket', record.dateBucket ?? '-'),
              _InfoRow('Ukuran model', record.imageSizeForModel),
              _InfoRow('Ukuran display', record.imageSizeForDisplay),
            ],
          ),
        ],
        if (canMutate) ...[
          const SizedBox(height: 16),
          _ActionPanel(
            isWorking: _isWorking,
            isAdmin: isAdmin,
            verificationStatus: record.verificationStatus,
            onCorrect: _correctLabel,
            onDelete: _deleteRecord,
            onVerify: () => _setVerificationStatus('verified'),
            onReject: () => _setVerificationStatus('rejected'),
            onUnverify: () => _setVerificationStatus('unverified'),
          ),
        ],
      ],
    );
  }
}

/// Gambar utama riwayat dengan sudut membulat besar, shimmer saat loading,
/// dan fallback rapi bila gambar tidak ada / gagal dimuat.
class _DetailHeroImage extends StatelessWidget {
  final String? imageUrl;

  const _DetailHeroImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget content;
    if (imageUrl?.isNotEmpty == true) {
      content = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const ShimmerBox(
            height: double.infinity,
            borderRadius: BorderRadius.zero,
          );
        },
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: colorScheme.errorContainer,
          child: Icon(Icons.broken_image_outlined,
              size: 56, color: colorScheme.onErrorContainer),
        ),
      );
    } else {
      content = ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(Icons.image_not_supported,
            size: 56, color: colorScheme.onSurfaceVariant),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(aspectRatio: 1, child: content),
      ),
    );
  }
}

/// Skeleton shimmer untuk layar detail riwayat saat memuat.
class _DetailLoadingSkeleton extends StatelessWidget {
  const _DetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AspectRatio(
          aspectRatio: 1,
          child: ShimmerBox(
            height: double.infinity,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        const SizedBox(height: 16),
        const ShimmerBox(
          width: 140,
          height: 36,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < 3; i++) ...[
          const ShimmerBox(
            height: 150,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CorrectionSheet extends StatefulWidget {
  final List<HoyaSpecies> species;
  final String initialSpeciesId;

  const _CorrectionSheet({
    required this.species,
    required this.initialSpeciesId,
  });

  @override
  State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _VerificationBadge extends StatelessWidget {
  final ClassificationRecord record;

  const _VerificationBadge({required this.record});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color backgroundColor;
    final Color foregroundColor;
    final IconData icon;

    if (record.isVerified) {
      backgroundColor = Colors.green.shade50;
      foregroundColor = Colors.green.shade800;
      icon = Icons.verified_outlined;
    } else if (record.isRejected) {
      backgroundColor = colorScheme.errorContainer;
      foregroundColor = colorScheme.onErrorContainer;
      icon = Icons.block_outlined;
    } else {
      backgroundColor = Colors.orange.shade50;
      foregroundColor = Colors.orange.shade900;
      icon = Icons.pending_actions_outlined;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: foregroundColor.withValues(alpha: 0.24)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 6),
              Text(
                record.verificationLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  late String _selectedSpeciesId;

  @override
  void initState() {
    super.initState();
    _selectedSpeciesId = widget.initialSpeciesId;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      if (!widget.species.any((item) => item.speciesId == _selectedSpeciesId))
        DropdownMenuItem(
          value: _selectedSpeciesId,
          child: Text(_selectedSpeciesId),
        ),
      for (final item in widget.species)
        DropdownMenuItem(
          value: item.speciesId,
          child: Text(item.displayName),
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Koreksi Label',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedSpeciesId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Spesies benar',
                prefixIcon: Icon(Icons.grass_outlined),
              ),
              items: items,
              onChanged: (value) {
                if (value != null) setState(() => _selectedSpeciesId = value);
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_selectedSpeciesId),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan Koreksi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final ClassificationRecord record;

  const _LocationCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final precisionLabel = record.privateLocation == null && record.hasLocation
        ? 'Koordinat publik dibulatkan'
        : record.hasLocation
            ? 'Koordinat presisi'
            : 'Tidak ada lokasi';

    return _InfoCard(
      title: 'Lokasi',
      rows: [
        _InfoRow('Koordinat', record.locationLabel),
        _InfoRow('Akses', precisionLabel),
        _InfoRow('Sumber', record.locationSource ?? '-'),
        if (record.locationAccuracy != null)
          _InfoRow('Akurasi', '${record.locationAccuracy!.round()} m'),
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final List<ClassificationTopPrediction> predictions;
  final Map<String, HoyaSpecies> speciesById;

  const _PredictionCard({
    required this.predictions,
    required this.speciesById,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SectionCard(
      icon: Icons.leaderboard_rounded,
      title: 'Kandidat Teratas',
      accent: const Color(0xFF0E9F9A),
      child: predictions.isEmpty
          ? Text(
              'Tidak ada data prediksi.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          : Column(
              children: [
                for (final (index, prediction) in predictions.indexed) ...[
                  if (index > 0) const SizedBox(height: 14),
                  _DetailPredictionRow(
                    rank: index + 1,
                    name: speciesById[prediction.speciesId]?.displayName ??
                        prediction.speciesId,
                    confidence:
                        prediction.confidence.clamp(0.0, 1.0).toDouble(),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DetailPredictionRow extends StatelessWidget {
  final int rank;
  final String name;
  final double confidence;

  const _DetailPredictionRow({
    required this.rank,
    required this.name,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = rank == 1 ? colorScheme.primary : colorScheme.tertiary;

    return Row(
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
                      name,
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

class _ActionPanel extends StatelessWidget {
  final bool isWorking;
  final bool isAdmin;
  final String verificationStatus;
  final VoidCallback onCorrect;
  final VoidCallback onDelete;
  final VoidCallback onVerify;
  final VoidCallback onReject;
  final VoidCallback onUnverify;

  const _ActionPanel({
    required this.isWorking,
    required this.isAdmin,
    required this.verificationStatus,
    required this.onCorrect,
    required this.onDelete,
    required this.onVerify,
    required this.onReject,
    required this.onUnverify,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aksi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isWorking ? null : onCorrect,
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Koreksi Label'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isWorking ? null : onDelete,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Hapus & Arsipkan'),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: isWorking || verificationStatus == 'verified'
                        ? null
                        : onVerify,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Verifikasi'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isWorking || verificationStatus == 'rejected'
                        ? null
                        : onReject,
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Tolak'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isWorking || verificationStatus == 'unverified'
                        ? null
                        : onUnverify,
                    icon: const Icon(Icons.pending_actions_outlined),
                    label: const Text('Unverified'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;

  const _InfoCard({
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Expanded(child: Text(row.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);
}

class _DetailEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DetailEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
