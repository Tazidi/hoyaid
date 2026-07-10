import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';
import 'package:hoyaid/features/classification/services/offline_classification_queue_service.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/shared/widgets/interactive.dart';
import 'package:intl/intl.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final speciesAsync = ref.watch(activeSpeciesProvider);
    final isAdmin = userData?['role'] == 'admin';
    final displayName =
        (userData?['displayName'] ?? userData?['name']) as String?;

    final menuItems = [
      _MenuItem(
        icon: Icons.history_rounded,
        label: 'Riwayat',
        subtitle: 'Hasil klasifikasi Anda',
        color: const Color(0xFF8B6F47),
        onTap: () => context.push('/history'),
      ),
      _MenuItem(
        icon: Icons.map_rounded,
        label: 'Peta Sebaran',
        subtitle: 'Lihat lokasi temuan',
        color: const Color(0xFF0E9F9A),
        onTap: () => context.push('/map'),
      ),
      _MenuItem(
        icon: Icons.local_florist_rounded,
        label: 'Info Spesies',
        subtitle: 'Katalog referensi Hoya',
        color: const Color(0xFFE08B2D),
        onTap: () => context.push('/species'),
      ),
      if (isAdmin)
        _MenuItem(
          icon: Icons.dashboard_customize_rounded,
          label: 'Dashboard Admin',
          subtitle: 'Kelola data aplikasi',
          color: Colors.blueGrey,
          onTap: () => context.push('/admin'),
        ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('iHoya'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Profil',
              icon: const Icon(Icons.person_rounded),
              onPressed: () => context.push('/profile'),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.22),
              colorScheme.surface,
              colorScheme.secondaryContainer.withValues(alpha: 0.48),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _HomeHero(
                name: displayName,
                onScan: () => context.push('/classification'),
                onMap: () => context.push('/map'),
              ),
              const SizedBox(height: 18),
              _InsightStrip(speciesAsync: speciesAsync),
              const SizedBox(height: 16),
              const _OfflinePendingCard(),
              const SizedBox(height: 22),
              _SectionHeader(
                title: 'Spesies Pilihan',
                actionLabel: 'Lihat semua',
                onAction: () => context.push('/species'),
              ),
              const SizedBox(height: 12),
              _SpeciesCarousel(speciesAsync: speciesAsync),
              const SizedBox(height: 24),
              Text(
                'Jelajahi iHoya',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 560;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: menuItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: isWide ? 1.2 : 1.04,
                    ),
                    itemBuilder: (context, index) =>
                        _MenuCard(item: menuItems[index]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflinePendingCard extends ConsumerStatefulWidget {
  const _OfflinePendingCard();

  @override
  ConsumerState<_OfflinePendingCard> createState() =>
      _OfflinePendingCardState();
}

class _OfflinePendingCardState extends ConsumerState<_OfflinePendingCard> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingOfflineClassificationsProvider);
    return pendingAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final colorScheme = Theme.of(context).colorScheme;
        final shownItems = items.take(3).toList();

        return Card(
          elevation: 0,
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.86),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${items.length} data menunggu upload',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onTertiaryContainer,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _isSyncing ? null : _syncNow,
                      icon: _isSyncing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(_isSyncing ? 'Sync...' : 'Sync'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Status: pending_upload. Data tersimpan di perangkat dan otomatis diupload saat internet tersedia.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                ),
                const SizedBox(height: 12),
                ...shownItems.map((item) => _OfflinePendingTile(item: item)),
                if (items.length > shownItems.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+${items.length - shownItems.length} data lainnya',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final result =
        await ref.read(offlineClassificationQueueServiceProvider).syncPending();
    ref.invalidate(pendingOfflineClassificationsProvider);
    if (!mounted) return;
    setState(() => _isSyncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.synced > 0
              ? '${result.synced} data offline berhasil disinkronkan.'
              : result.message ?? 'Belum ada data yang perlu disinkronkan.',
        ),
      ),
    );
  }
}

class _OfflinePendingTile extends StatelessWidget {
  final OfflineClassificationItem item;

  const _OfflinePendingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final location = item.location;
    final locationText = location == null
        ? 'Koordinat belum tersedia'
        : '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.prediction.speciesId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$locationText • ${DateFormat('dd MMM HH:mm').format(item.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const _PendingBadge(),
        ],
      ),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          'pending',
          style: TextStyle(
            color: Colors.deepOrange,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  final String? name;
  final VoidCallback onScan;
  final VoidCallback onMap;

  const _HomeHero({
    required this.name,
    required this.onScan,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final greeting = name == null || name!.trim().isEmpty
        ? 'Selamat datang'
        : 'Halo, ${name!.trim()}';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            const Color(0xFF1F8A70),
            colorScheme.tertiary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.24),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -28,
            child: Icon(
              Icons.eco_rounded,
              size: 148,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  greeting,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kenali Hoya dari foto, simpan temuan, dan jelajahi sebarannya.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Gunakan kamera untuk identifikasi cepat atau buka peta untuk melihat persebaran data yang sudah tercatat.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onScan,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colorScheme.primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Mulai Scan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: onMap,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      foregroundColor: Colors.white,
                      fixedSize: const Size(52, 52),
                    ),
                    icon: const Icon(Icons.map_rounded),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightStrip extends StatelessWidget {
  final AsyncValue<List<HoyaSpecies>> speciesAsync;

  const _InsightStrip({required this.speciesAsync});

  @override
  Widget build(BuildContext context) {
    return speciesAsync.when(
      data: (species) {
        final medicalCount = species.where((item) => item.hasMedicalUse).length;
        return Row(
          children: [
            Expanded(
              child: _InsightCard(
                icon: Icons.grass_rounded,
                value: species.length,
                label: 'Spesies terdaftar',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightCard(
                icon: Icons.medical_services_rounded,
                value: medicalCount,
                label: 'Manfaat medis',
              ),
            ),
          ],
        );
      },
      loading: () => const Row(
        children: [
          Expanded(child: _InsightSkeleton()),
          SizedBox(width: 10),
          Expanded(child: _InsightSkeleton()),
          SizedBox(width: 10),
          Expanded(child: _InsightSkeleton()),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _InsightCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(height: 10),
          AnimatedCountUp(
            value: value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InsightSkeleton extends StatelessWidget {
  const _InsightSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ShimmerBox(
      height: 98,
      borderRadius: BorderRadius.all(Radius.circular(22)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _SpeciesCarousel extends StatefulWidget {
  final AsyncValue<List<HoyaSpecies>> speciesAsync;

  const _SpeciesCarousel({required this.speciesAsync});

  @override
  State<_SpeciesCarousel> createState() => _SpeciesCarouselState();
}

class _SpeciesCarouselState extends State<_SpeciesCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final page = _controller.page ?? 0;
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.speciesAsync.when(
      data: (species) {
        final featured = species.take(6).toList();
        if (featured.isEmpty) return const _EmptySpeciesCard();

        return Column(
          children: [
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                itemCount: featured.length,
                itemBuilder: (context, index) {
                  // Kartu aktif sedikit lebih besar dari tetangganya.
                  final distance = (_page - index).abs().clamp(0.0, 1.0);
                  final scale = 1 - distance * 0.06;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == featured.length - 1 ? 0 : 12,
                    ),
                    child: Transform.scale(
                      scale: scale,
                      child: _SpeciesFeatureCard(species: featured[index]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _CarouselDots(count: featured.length, page: _page),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 210,
        child: ShimmerBox(
          height: 210,
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
      ),
      error: (_, __) => const _EmptySpeciesCard(),
    );
  }
}

/// Titik indikator halaman untuk carousel. Titik aktif memanjang.
class _CarouselDots extends StatelessWidget {
  final int count;
  final double page;

  const _CarouselDots({required this.count, required this.page});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = page.round();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active
                  ? colorScheme.primary
                  : colorScheme.primary.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _SpeciesFeatureCard extends StatelessWidget {
  final HoyaSpecies species;

  const _SpeciesFeatureCard({required this.species});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = species.referenceImageUrl;

    return PressableScale(
      borderRadius: BorderRadius.circular(28),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/species/${species.speciesId}'),
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.88),
                  const Color(0xFF163B2F),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _SpeciesPattern(),
                    )
                  else
                    const _SpeciesPattern(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.74),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (species.isRare)
                              const _SpeciesTag(label: 'Langka'),
                            if (species.hasMedicalUse)
                              const _SpeciesTag(label: 'Berpotensi bermanfaat'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          species.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          species.distribution,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeciesPattern extends StatelessWidget {
  const _SpeciesPattern();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF214B3D),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Icon(
              Icons.local_florist_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            left: 22,
            top: 20,
            child: Icon(
              Icons.eco_rounded,
              size: 54,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesTag extends StatelessWidget {
  final String label;

  const _SpeciesTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptySpeciesCard extends StatelessWidget {
  const _EmptySpeciesCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Center(
        child: Text('Data spesies akan tampil di sini setelah tersedia.'),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;

  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      borderRadius: BorderRadius.circular(24),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(item.icon, size: 30, color: item.color),
                ),
                const Spacer(),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
