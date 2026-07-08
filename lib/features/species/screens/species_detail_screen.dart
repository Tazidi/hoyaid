import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/features/species/widgets/species_reference_image.dart';
import 'package:hoyaid/shared/widgets/interactive.dart';

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
      body: speciesAsync.when(
        data: (species) {
          if (species == null) {
            return _MessageState(
              icon: Icons.search_off_rounded,
              title: 'Spesies tidak ditemukan',
              message: 'Data untuk "$speciesId" tidak tersedia.',
            );
          }
          return _SpeciesDetailBody(species: species, isAdmin: isAdmin);
        },
        loading: () => const _DetailLoadingSkeleton(),
        error: (error, stackTrace) => _MessageState(
          icon: Icons.cloud_off_rounded,
          title: 'Gagal memuat detail',
          message: '$error',
        ),
      ),
    );
  }
}

class _SpeciesDetailBody extends StatelessWidget {
  final HoyaSpecies species;
  final bool isAdmin;

  const _SpeciesDetailBody({required this.species, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          stretch: true,
          foregroundColor: Colors.white,
          backgroundColor: colorScheme.primary,
          actions: [
            if (isAdmin)
              IconButton(
                tooltip: 'Edit spesies',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/admin/species/${species.speciesId}/edit'),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.fadeTitle,
            ],
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
            title: Text(
              species.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            background: _HeroBackground(species: species),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(
                  child: _HeaderBlock(species: species),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 90),
                  child: SectionCard(
                    icon: Icons.public_rounded,
                    title: 'Persebaran',
                    accent: const Color(0xFF0E9F9A),
                    child: _SectionText(species.distribution),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 160),
                  child: SectionCard(
                    icon: Icons.description_outlined,
                    title: 'Deskripsi',
                    child: _SectionText(species.description),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 230),
                  child: SectionCard(
                    icon: Icons.medical_services_outlined,
                    title: 'Pemanfaatan Medis',
                    accent: const Color(0xFFB9772A),
                    child: _MedicalContent(species: species),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Latar hero: gambar referensi + overlay gradien agar teks terbaca.
class _HeroBackground extends StatelessWidget {
  final HoyaSpecies species;

  const _HeroBackground({required this.species});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SpeciesReferenceImage(
          imageUrl: species.referenceImageUrl,
          borderRadius: BorderRadius.zero,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black26,
                Colors.transparent,
                Colors.black87,
              ],
              stops: [0, 0.45, 1],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 56,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (species.isRare)
                const StatChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Langka',
                  color: Color(0xFFFFB74D),
                ),
              if (species.hasMedicalUse)
                const StatChip(
                  icon: Icons.healing_rounded,
                  label: 'Manfaat medis',
                  color: Color(0xFF81C784),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Blok judul + nama lokal + badge status di bawah hero.
class _HeaderBlock extends StatelessWidget {
  final HoyaSpecies species;

  const _HeaderBlock({required this.species});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          species.displayName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
        ),
        if ((species.localName ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            species.localName!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatChip(
              icon: Icons.tag_rounded,
              label: species.speciesId,
              color: colorScheme.primary,
            ),
            StatChip(
              icon: species.isActive
                  ? Icons.check_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              label: species.isActive ? 'Aktif' : 'Nonaktif',
              color: species.isActive ? Colors.green : Colors.grey,
            ),
            if (species.isRare)
              const StatChip(
                icon: Icons.auto_awesome_rounded,
                label: 'Langka',
                color: Color(0xFFE08B2D),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionText extends StatelessWidget {
  final String content;

  const _SectionText(this.content);

  @override
  Widget build(BuildContext context) {
    final text = content.trim().isEmpty ? '-' : content.trim();
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
    );
  }
}

class _MedicalContent extends StatelessWidget {
  final HoyaSpecies species;

  const _MedicalContent({required this.species});

  @override
  Widget build(BuildContext context) {
    if (!species.hasMedicalUse) {
      final colorScheme = Theme.of(context).colorScheme;
      return Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Belum ada data pemanfaatan medis.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      );
    }
    return _SectionText(species.medicalUseDescription);
  }
}

/// Skeleton shimmer saat detail sedang dimuat.
class _DetailLoadingSkeleton extends StatelessWidget {
  const _DetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: ShimmerBox(
              height: 300,
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(width: 220, height: 28),
                const SizedBox(height: 10),
                const ShimmerBox(width: 140, height: 18),
                const SizedBox(height: 18),
                for (int i = 0; i < 3; i++) ...[
                  const ShimmerBox(
                    height: 120,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: BackButton(onPressed: () => Navigator.maybePop(context)),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 64, color: colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
