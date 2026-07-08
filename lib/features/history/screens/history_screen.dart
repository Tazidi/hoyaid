import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';
import 'package:hoyaid/features/history/providers/history_provider.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/shared/widgets/interactive.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _HistoryAppBar(),
        body: TabBarView(
          children: [
            _HistoryListTab(scope: ClassificationScope.mine),
            _HistoryListTab(scope: ClassificationScope.public),
          ],
        ),
      ),
    );
  }
}

class _HistoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HistoryAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Riwayat Klasifikasi'),
      bottom: const TabBar(
        tabs: [
          Tab(text: 'Riwayat Saya'),
          Tab(text: 'Semua Riwayat'),
        ],
      ),
    );
  }
}

class _HistoryListTab extends ConsumerStatefulWidget {
  final ClassificationScope scope;

  const _HistoryListTab({required this.scope});

  @override
  ConsumerState<_HistoryListTab> createState() => _HistoryListTabState();
}

class _HistoryListTabState extends ConsumerState<_HistoryListTab> {
  AutoDisposeStateNotifierProvider<HistoryController,
      AsyncValue<HistoryListState>> get _provider {
    return widget.scope == ClassificationScope.mine
        ? myHistoryControllerProvider
        : publicHistoryControllerProvider;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_provider.notifier).loadInitial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final userData = ref.watch(userDataProvider).valueOrNull;
    final isAdmin = userData?['role'] == 'admin';
    final species = ref.watch(activeSpeciesProvider).valueOrNull ?? [];
    final speciesById = {
      for (final item in species) item.speciesId: item,
    };
    final state = ref.watch(_provider);
    final controller = ref.read(_provider.notifier);

    if (widget.scope == ClassificationScope.mine &&
        (user == null || user.isAnonymous)) {
      return _EmptyState(
        icon: Icons.login,
        title: 'Login diperlukan',
        message: 'Mode tamu hanya dapat melihat riwayat publik.',
        action: FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Login'),
        ),
      );
    }

    return state.when(
      data: (data) {
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HistoryFilterPanel(
                filter: data.filter,
                species: species,
                isAdmin: isAdmin,
                scope: widget.scope,
                onChanged: controller.setFilter,
                onClear: controller.clearFilters,
              ),
              const SizedBox(height: 12),
              if (data.items.isEmpty)
                const _EmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'Belum ada data',
                  message: 'Data yang cocok dengan filter belum tersedia.',
                )
              else
                for (final (index, record) in data.items.indexed) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: (index * 40).clamp(0, 320)),
                    offsetY: 16,
                    child: _ClassificationCard(
                      record: record,
                      species: speciesById[record.speciesId],
                      onTap: () => context.push(
                        '/history/${record.classificationId}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              if (data.items.isNotEmpty)
                Center(
                  child: OutlinedButton.icon(
                    onPressed: data.hasMore && !data.isLoadingMore
                        ? controller.loadMore
                        : null,
                    icon: data.isLoadingMore
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(data.hasMore ? 'Muat Lagi' : 'Semua termuat'),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const _HistoryLoadingSkeleton(),
      error: (error, _) => _ErrorState(
        message: readableErrorMessage(
          error,
          fallback: 'Gagal memuat riwayat. Periksa koneksi lalu coba lagi.',
        ),
        onRetry: controller.refresh,
      ),
    );
  }
}

class _HistoryFilterPanel extends StatefulWidget {
  final HistoryFilter filter;
  final List<HoyaSpecies> species;
  final bool isAdmin;
  final ClassificationScope scope;
  final ValueChanged<HistoryFilter> onChanged;
  final VoidCallback onClear;

  const _HistoryFilterPanel({
    required this.filter,
    required this.species,
    required this.isAdmin,
    required this.scope,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_HistoryFilterPanel> createState() => _HistoryFilterPanelState();
}

class _HistoryFilterPanelState extends State<_HistoryFilterPanel> {
  late final TextEditingController _dateBucketController;
  late final TextEditingController _userIdController;

  @override
  void initState() {
    super.initState();
    _dateBucketController = TextEditingController(
      text: widget.filter.dateBucket ?? '',
    );
    _userIdController = TextEditingController(text: widget.filter.userId ?? '');
  }

  @override
  void didUpdateWidget(covariant _HistoryFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter.dateBucket != widget.filter.dateBucket) {
      _dateBucketController.text = widget.filter.dateBucket ?? '';
    }
    if (oldWidget.filter.userId != widget.filter.userId) {
      _userIdController.text = widget.filter.userId ?? '';
    }
  }

  @override
  void dispose() {
    _dateBucketController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;

    return Card(
      child: ExpansionTile(
        initiallyExpanded: filter.hasActiveFilters,
        leading: const Icon(Icons.filter_alt_outlined),
        title: const Text('Filter & Sort'),
        subtitle: Text(
          filter.hasActiveFilters
              ? 'Filter aktif'
              : 'Terbaru, semua spesies, semua status',
        ),
        trailing: filter.hasActiveFilters
            ? IconButton(
                tooltip: 'Bersihkan filter',
                onPressed: widget.onClear,
                icon: const Icon(Icons.filter_alt_off_outlined),
              )
            : null,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          DropdownButtonFormField<ClassificationSortOrder>(
            initialValue: filter.sortOrder,
            decoration: const InputDecoration(
              labelText: 'Urutkan',
              prefixIcon: Icon(Icons.sort),
            ),
            items: const [
              DropdownMenuItem(
                value: ClassificationSortOrder.newest,
                child: Text('Terbaru'),
              ),
              DropdownMenuItem(
                value: ClassificationSortOrder.oldest,
                child: Text('Terlama'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              widget.onChanged(filter.copyWith(sortOrder: value));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: filter.speciesId ?? '',
            decoration: const InputDecoration(
              labelText: 'Spesies',
              prefixIcon: Icon(Icons.grass_outlined),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua spesies')),
              for (final item in widget.species)
                DropdownMenuItem(
                  value: item.speciesId,
                  child: Text(item.displayName),
                ),
            ],
            onChanged: (value) {
              widget.onChanged(
                filter.copyWith(
                  speciesId: value,
                  clearSpeciesId: value == null || value.isEmpty,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: filter.confidenceBucket ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Confidence',
                    prefixIcon: Icon(Icons.speed_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                  ],
                  onChanged: (value) {
                    widget.onChanged(
                      filter.copyWith(
                        confidenceBucket: value,
                        clearConfidenceBucket: value == null || value.isEmpty,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: filter.verificationStatus ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Verifikasi',
                    prefixIcon: Icon(Icons.fact_check_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua')),
                    DropdownMenuItem(
                      value: 'unverified',
                      child: Text('Unverified'),
                    ),
                    DropdownMenuItem(
                        value: 'verified', child: Text('Verified')),
                    DropdownMenuItem(
                        value: 'rejected', child: Text('Rejected')),
                  ],
                  onChanged: (value) {
                    widget.onChanged(
                      filter.copyWith(
                        verificationStatus: value,
                        clearVerificationStatus: value == null || value.isEmpty,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateBucketController,
                  decoration: const InputDecoration(
                    labelText: 'Bulan',
                    hintText: 'YYYY-MM',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submitDateBucket,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: filter.hasLocation == null
                      ? ''
                      : filter.hasLocation == true
                          ? 'yes'
                          : 'no',
                  decoration: const InputDecoration(
                    labelText: 'Lokasi',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua')),
                    DropdownMenuItem(value: 'yes', child: Text('Ada')),
                    DropdownMenuItem(value: 'no', child: Text('Tanpa')),
                  ],
                  onChanged: (value) {
                    widget.onChanged(
                      filter.copyWith(
                        hasLocation: value == 'yes'
                            ? true
                            : value == 'no'
                                ? false
                                : null,
                        clearHasLocation: value == null || value.isEmpty,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (widget.isAdmin && widget.scope == ClassificationScope.public) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: _submitUserId,
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                _submitDateBucket(_dateBucketController.text);
                if (widget.isAdmin &&
                    widget.scope == ClassificationScope.public) {
                  _submitUserId(_userIdController.text);
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Terapkan'),
            ),
          ),
        ],
      ),
    );
  }

  void _submitDateBucket(String value) {
    final normalized = value.trim();
    widget.onChanged(
      widget.filter.copyWith(
        dateBucket: normalized,
        clearDateBucket: normalized.isEmpty,
      ),
    );
  }

  void _submitUserId(String value) {
    final normalized = value.trim();
    widget.onChanged(
      widget.filter.copyWith(
        userId: normalized,
        clearUserId: normalized.isEmpty,
      ),
    );
  }
}

class _ClassificationCard extends StatelessWidget {
  final ClassificationRecord record;
  final HoyaSpecies? species;
  final VoidCallback onTap;

  const _ClassificationCard({
    required this.record,
    required this.species,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = record.imageUrl;
    final date = record.createdAt == null
        ? '-'
        : DateFormat('dd MMM yyyy HH:mm').format(record.createdAt!);

    return PressableScale(
      pressedScale: 0.97,
      child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 86,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Icon(Icons.image_not_supported),
                        )
                      : _NetworkThumbnail(imageUrl: imageUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      species?.displayName ?? record.speciesId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(
                          icon: Icons.speed_outlined,
                          text: record.confidencePercent,
                        ),
                        _VerificationChip(status: record.verificationStatus),
                        if (record.hasCorrection)
                          const _StatusChip(
                            icon: Icons.edit_note_outlined,
                            text: 'Dikoreksi',
                          ),
                        _StatusChip(
                          icon: record.hasLocation
                              ? Icons.place_outlined
                              : Icons.location_off_outlined,
                          text: record.hasLocation
                              ? 'Ada lokasi'
                              : 'Tanpa lokasi',
                        ),
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

/// Skeleton shimmer untuk daftar riwayat saat memuat.
class _HistoryLoadingSkeleton extends StatelessWidget {
  const _HistoryLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ShimmerBox(
          height: 72,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerBox(
              height: 112,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
      ],
    );
  }
}

class _NetworkThumbnail extends StatelessWidget {
  final String imageUrl;

  const _NetworkThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return ColoredBox(
          color: colorScheme.errorContainer,
          child: Icon(
            Icons.broken_image_outlined,
            color: colorScheme.onErrorContainer,
          ),
        );
      },
    );
  }
}

class _VerificationChip extends StatelessWidget {
  final String status;

  const _VerificationChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'verified' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.orange,
    };
    final icon = switch (status) {
      'verified' => Icons.verified_outlined,
      'rejected' => Icons.block_outlined,
      _ => Icons.pending_actions_outlined,
    };

    return _StatusChip(
      icon: icon,
      text: status,
      color: color,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _StatusChip({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: effectiveColor),
            const SizedBox(width: 4),
            Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
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
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
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
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            const Text('Gagal memuat riwayat.'),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
