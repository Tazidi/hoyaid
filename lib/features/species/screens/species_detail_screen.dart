import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/features/species/widgets/species_reference_image.dart';
import 'package:hoyaid/shared/widgets/loading_widget.dart';

class SpeciesDetailScreen extends ConsumerWidget {
  final String speciesId;

  const SpeciesDetailScreen({
    super.key,
    required this.speciesId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesAsync = ref.watch(speciesDetailProvider(speciesId));
    final userData = ref.watch(userDataProvider).valueOrNull;
    final isAdmin = userData?['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Spesies'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Edit spesies',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/admin/species/$speciesId/edit'),
            ),
        ],
      ),
      body: speciesAsync.when(
        data: (species) {
          if (species == null) {
            return const Center(child: Text('Spesies tidak ditemukan.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: SpeciesReferenceImage(
                  imageUrl: species.referenceImageUrl,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                species.displayName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(species.localName ?? '-'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(label: species.speciesId),
                  if (species.isRare) const _Badge(label: 'Langka'),
                  _Badge(label: species.isActive ? 'Aktif' : 'Nonaktif'),
                ],
              ),
              const SizedBox(height: 24),
              _InfoSection(
                title: 'Persebaran',
                icon: Icons.public,
                content: species.distribution,
              ),
              _InfoSection(
                title: 'Deskripsi',
                icon: Icons.description_outlined,
                content: species.description,
              ),
              _InfoSection(
                title: 'Pemanfaatan Medis',
                icon: Icons.medical_services_outlined,
                content: species.hasMedicalUse
                    ? species.medicalUseDescription
                    : 'Belum ada data pemanfaatan medis.',
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(message: 'Memuat detail spesies...'),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Gagal memuat detail spesies: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content.trim().isEmpty ? '-' : content),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
