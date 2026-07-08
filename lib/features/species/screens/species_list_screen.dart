import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/features/species/widgets/species_reference_image.dart';
import 'package:hoyaid/shared/widgets/interactive.dart';

class SpeciesListScreen extends ConsumerStatefulWidget {
  const SpeciesListScreen({super.key});

  @override
  ConsumerState<SpeciesListScreen> createState() => _SpeciesListScreenState();
}

class _SpeciesListScreenState extends ConsumerState<SpeciesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _alphabetFilter = 'Semua';

  static const _alphabetFilters = ['Semua', 'A-F', 'G-L', 'M-R', 'S-Z'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speciesAsync = ref.watch(activeSpeciesProvider);
    final userData = ref.watch(userDataProvider).valueOrNull;
    final isAdmin = userData?['role'] == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Spesies'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Kelola spesies',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => context.push('/admin/species'),
            ),
        ],
      ),
      body: speciesAsync.when(
        data: (species) {
          final filtered = _filterSpecies(species);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeSpeciesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari spesies',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Bersihkan pencarian',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _query = value.trim().toLowerCase());
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _alphabetFilters) ...[
                        ChoiceChip(
                          label: Text(filter),
                          selected: _alphabetFilter == filter,
                          onSelected: (_) {
                            setState(() => _alphabetFilter = filter);
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${filtered.length} dari ${species.length} spesies aktif',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  const _EmptySpeciesState()
                else
                  for (final (index, item) in filtered.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeSlideIn(
                        // Batasi delay agar item paling bawah tak menunggu lama.
                        delay: Duration(milliseconds: (index * 45).clamp(0, 400)),
                        offsetY: 16,
                        child: _SpeciesListItem(species: item),
                      ),
                    ),
              ],
            ),
          );
        },
        loading: () => const _SpeciesLoadingSkeleton(),
        error: (error, stackTrace) => _ErrorState(
          message: 'Gagal memuat data spesies',
          detail: readableErrorMessage(
            error,
            fallback: 'Periksa koneksi lalu coba lagi.',
          ),
          onRetry: () => ref.invalidate(activeSpeciesProvider),
        ),
      ),
    );
  }

  List<HoyaSpecies> _filterSpecies(List<HoyaSpecies> species) {
    return species.where((item) {
      final matchesSearch = _query.isEmpty || item.searchText.contains(_query);
      final matchesAlphabet = _alphabetFilter == 'Semua' ||
          _matchesAlphabetFilter(item.sortKey, _alphabetFilter);
      return matchesSearch && matchesAlphabet;
    }).toList();
  }

  bool _matchesAlphabetFilter(String key, String filter) {
    if (key.isEmpty) return false;
    final first = key[0].toUpperCase();
    switch (filter) {
      case 'A-F':
        return first.compareTo('A') >= 0 && first.compareTo('F') <= 0;
      case 'G-L':
        return first.compareTo('G') >= 0 && first.compareTo('L') <= 0;
      case 'M-R':
        return first.compareTo('M') >= 0 && first.compareTo('R') <= 0;
      case 'S-Z':
        return first.compareTo('S') >= 0 && first.compareTo('Z') <= 0;
      default:
        return true;
    }
  }
}

class _SpeciesListItem extends StatelessWidget {
  final HoyaSpecies species;

  const _SpeciesListItem({required this.species});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push('/species/${species.speciesId}'),
      pressedScale: 0.97,
      child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/species/${species.speciesId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SpeciesReferenceImage(
                imageUrl: species.referenceImageUrl,
                width: 76,
                height: 76,
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
                    const SizedBox(height: 4),
                    Text(
                      species.localName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _TinyBadge(label: species.speciesId),
                        if (species.isRare) const _TinyBadge(label: 'Langka'),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Placeholder shimmer saat daftar spesies sedang dimuat.
class _SpeciesLoadingSkeleton extends StatelessWidget {
  const _SpeciesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const ShimmerBox(height: 52),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, __) => const ShimmerBox(
              width: 64,
              height: 34,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < 6; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: ShimmerBox(
              height: 100,
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
          ),
      ],
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String label;

  const _TinyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
        ),
      ),
    );
  }
}

class _EmptySpeciesState extends StatelessWidget {
  const _EmptySpeciesState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada spesies yang cocok',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String detail;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
