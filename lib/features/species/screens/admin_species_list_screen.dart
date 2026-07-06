import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';
import 'package:hoyaid/features/species/widgets/species_reference_image.dart';
import 'package:hoyaid/shared/widgets/loading_widget.dart' as shared;

class AdminSpeciesListScreen extends ConsumerWidget {
  const AdminSpeciesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Spesies'),
          actions: [
            IconButton(
              tooltip: 'Kelola label map',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () => context.push('/admin/label-map'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/admin/species/new'),
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),
        ),
        body: const _AdminSpeciesListBody(),
      ),
    );
  }
}

class _AdminSpeciesListBody extends ConsumerWidget {
  const _AdminSpeciesListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesAsync = ref.watch(allSpeciesProvider);

    return speciesAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const shared.EmptyStateWidget(
            title: 'Belum ada data spesies',
            subtitle: 'Jalankan seed Firestore atau tambah spesies baru.',
            icon: Icons.local_florist_outlined,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allSpeciesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AdminSpeciesTile(species: items[index]),
              );
            },
          ),
        );
      },
      loading: () =>
          const shared.LoadingWidget(message: 'Memuat data spesies...'),
      error: (error, stackTrace) => shared.ErrorWidget(
        message: readableErrorMessage(
          error,
          fallback: 'Gagal memuat spesies.',
        ),
        onRetry: () => ref.invalidate(allSpeciesProvider),
      ),
    );
  }
}

class _AdminSpeciesTile extends ConsumerWidget {
  final HoyaSpecies species;

  const _AdminSpeciesTile({required this.species});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SpeciesReferenceImage(
              imageUrl: species.referenceImageUrl,
              width: 64,
              height: 64,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    species.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    species.speciesId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        species.isActive
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(species.isActive ? 'Aktif' : 'Nonaktif'),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: species.isActive,
              onChanged: (value) async {
                try {
                  await ref.read(speciesServiceProvider).setSpeciesActive(
                        species.speciesId,
                        value,
                        actorId: user?.uid,
                      );
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(readableErrorMessage(error))),
                    );
                  }
                }
              },
            ),
            IconButton(
              tooltip: 'Edit spesies',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                context.push('/admin/species/${species.speciesId}/edit');
              },
            ),
          ],
        ),
      ),
    );
  }
}
