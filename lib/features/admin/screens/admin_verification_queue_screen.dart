import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/admin/providers/admin_provider.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';
import 'package:intl/intl.dart';

class AdminVerificationQueueScreen extends ConsumerWidget {
  const AdminVerificationQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final species = ref.watch(activeSpeciesProvider).valueOrNull ?? [];
    final speciesById = {
      for (final item in species) item.speciesId: item,
    };

    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Antrian Verifikasi')),
        body: ref.watch(adminVerificationQueueProvider).when(
              data: (records) {
                if (records.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined, size: 56),
                          SizedBox(height: 16),
                          Text('Tidak ada data unverified.'),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _VerificationCard(
                      record: record,
                      speciesName: speciesById[record.speciesId]?.displayName ??
                          record.speciesId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    readableErrorMessage(
                      error,
                      fallback: 'Gagal memuat antrian verifikasi.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _VerificationCard extends ConsumerStatefulWidget {
  final ClassificationRecord record;
  final String speciesName;

  const _VerificationCard({
    required this.record,
    required this.speciesName,
  });

  @override
  ConsumerState<_VerificationCard> createState() => _VerificationCardState();
}

class _VerificationCardState extends ConsumerState<_VerificationCard> {
  bool _isWorking = false;

  Future<void> _setStatus(String status) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await ref.read(adminServiceProvider).setVerificationStatus(
            classificationId: widget.record.classificationId,
            status: status,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status diubah menjadi $status.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(readableErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final date = record.createdAt == null
        ? '-'
        : DateFormat('dd MMM yyyy HH:mm').format(record.createdAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 82,
                    child: record.imageUrl?.isNotEmpty == true
                        ? Image.network(
                            record.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder:
                                (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox.square(
                                  dimension: 22,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const ColoredBox(
                                color: Colors.black12,
                                child: Icon(Icons.broken_image_outlined),
                              );
                            },
                          )
                        : const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.image_not_supported),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.speciesName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(date),
                      Text('Confidence ${record.confidencePercent}'),
                      Text(
                        record.hasLocation
                            ? record.locationLabel
                            : 'Tanpa lokasi',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isWorking ? null : () => _setStatus('verified'),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verifikasi'),
                ),
                OutlinedButton.icon(
                  onPressed: _isWorking ? null : () => _setStatus('rejected'),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Tolak'),
                ),
                TextButton.icon(
                  onPressed: _isWorking
                      ? null
                      : () => context.push(
                            '/history/${record.classificationId}',
                          ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Detail'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
