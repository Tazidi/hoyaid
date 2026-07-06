import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/admin/models/admin_models.dart';
import 'package:hoyaid/features/admin/providers/admin_provider.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              tooltip: 'Recalculate stats',
              onPressed: () => _recalculateStats(context, ref),
              icon: const Icon(Icons.calculate_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            ref.invalidate(adminVerificationQueueProvider);
            ref.invalidate(adminRecentClassificationsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatsSection(statsAsync: ref.watch(adminStatsProvider)),
              const SizedBox(height: 16),
              _AdminActionsGrid(
                onUsers: () => context.push('/admin/users'),
                onVerification: () => context.push('/admin/verification'),
                onExport: () => context.push('/admin/export'),
                onSpecies: () => context.push('/admin/species'),
                onLabelMap: () => context.push('/admin/label-map'),
                onModelUpload: () => context.push('/admin/model-upload'),
                onHistory: () => context.push('/history'),
              ),
              const SizedBox(height: 16),
              _QueuePreview(
                title: 'Antrian Verifikasi',
                recordsAsync: ref.watch(adminVerificationQueueProvider),
                emptyText: 'Tidak ada data unverified.',
                onOpenAll: () => context.push('/admin/verification'),
              ),
              const SizedBox(height: 16),
              _QueuePreview(
                title: 'Data Terbaru',
                recordsAsync: ref.watch(adminRecentClassificationsProvider),
                emptyText: 'Belum ada klasifikasi aktif.',
                onOpenAll: () => context.push('/history'),
              ),
              const SizedBox(height: 16),
              _QueuePreview(
                title: 'Confidence Rendah',
                recordsAsync: ref.watch(adminLowConfidenceProvider),
                emptyText: 'Tidak ada data low confidence.',
                onOpenAll: () => context.push('/history'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recalculateStats(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminServiceProvider).recalculateGlobalStats();
      ref.invalidate(adminStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stats berhasil dihitung ulang.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(readableErrorMessage(error))),
        );
      }
    }
  }
}

class _StatsSection extends StatelessWidget {
  final AsyncValue<AdminStats> statsAsync;

  const _StatsSection({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return statsAsync.when(
      data: (stats) {
        final updatedAt = stats.updatedAt == null
            ? 'Belum pernah dihitung'
            : DateFormat('dd MMM yyyy HH:mm').format(stats.updatedAt!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.55,
              children: [
                _StatCard(
                  icon: Icons.people_outline,
                  label: 'User',
                  value: '${stats.activeUsers}/${stats.totalUsers}',
                ),
                _StatCard(
                  icon: Icons.image_search_outlined,
                  label: 'Klasifikasi',
                  value: stats.activeClassifications.toString(),
                ),
                _StatCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Arsip',
                  value: stats.archivedClassifications.toString(),
                ),
                _StatCard(
                  icon: Icons.grass_outlined,
                  label: 'Spesies',
                  value: stats.speciesCount.toString(),
                ),
                _StatCard(
                  icon: Icons.pending_actions_outlined,
                  label: 'Unverified',
                  value: stats.unverifiedClassifications.toString(),
                ),
                _StatCard(
                  icon: Icons.warning_amber_outlined,
                  label: 'Confidence low',
                  value: stats.lowConfidenceClassifications.toString(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Updated: $updatedAt',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            readableErrorMessage(
              error,
              fallback: 'Gagal memuat statistik admin.',
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminActionsGrid extends StatelessWidget {
  final VoidCallback onUsers;
  final VoidCallback onVerification;
  final VoidCallback onExport;
  final VoidCallback onSpecies;
  final VoidCallback onLabelMap;
  final VoidCallback onModelUpload;
  final VoidCallback onHistory;

  const _AdminActionsGrid({
    required this.onUsers,
    required this.onVerification,
    required this.onExport,
    required this.onSpecies,
    required this.onLabelMap,
    required this.onModelUpload,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminAction(Icons.people_alt_outlined, 'User', onUsers),
      _AdminAction(Icons.fact_check_outlined, 'Verifikasi', onVerification),
      _AdminAction(Icons.download_outlined, 'Ekspor', onExport),
      _AdminAction(Icons.grass_outlined, 'Spesies', onSpecies),
      _AdminAction(Icons.account_tree_outlined, 'Label Map', onLabelMap),
      _AdminAction(Icons.model_training_outlined, 'Model', onModelUpload),
      _AdminAction(Icons.manage_search_outlined, 'Riwayat', onHistory),
    ];

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final item in items)
          Card(
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QueuePreview extends StatelessWidget {
  final String title;
  final AsyncValue<List<ClassificationRecord>> recordsAsync;
  final String emptyText;
  final VoidCallback onOpenAll;

  const _QueuePreview({
    required this.title,
    required this.recordsAsync,
    required this.emptyText,
    required this.onOpenAll,
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: onOpenAll,
                  child: const Text('Buka'),
                ),
              ],
            ),
            recordsAsync.when(
              data: (records) {
                if (records.isEmpty) return Text(emptyText);
                return Column(
                  children: [
                    for (final record in records.take(5))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.image_search_outlined),
                        title: Text(record.speciesId),
                        subtitle: Text(record.confidencePercent),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/history/${record.classificationId}',
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                readableErrorMessage(
                  error,
                  fallback: 'Gagal memuat data ringkas.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _AdminAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AdminAction(this.icon, this.label, this.onTap);
}
