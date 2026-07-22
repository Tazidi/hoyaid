import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/map/models/distribution_map_models.dart';
import 'package:hoyaid/features/map/providers/distribution_map_provider.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

enum _MapDisplayMode { markers, heatmap }

class DistributionMapScreen extends ConsumerStatefulWidget {
  const DistributionMapScreen({super.key});

  @override
  ConsumerState<DistributionMapScreen> createState() =>
      _DistributionMapScreenState();
}

class _DistributionMapScreenState extends ConsumerState<DistributionMapScreen> {
  static const _initialCenter = LatLng(-2.5489, 118.0149);

  final MapController _mapController = MapController();
  DistributionMapFilter _filter = const DistributionMapFilter();
  _MapDisplayMode _displayMode = _MapDisplayMode.markers;
  int? _lastAutoFocusKey;
  double _zoom = 4.7;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final userData = ref.watch(userDataProvider).valueOrNull;
    final isAdmin = userData?['role'] == 'admin';
    final canUseMine = user != null && !user.isAnonymous;
    final species = ref.watch(activeSpeciesProvider).valueOrNull ?? [];
    final speciesById = {
      for (final item in species) item.speciesId: item,
    };
    final pointsAsync = ref.watch(distributionMapPointsProvider(_filter));
    final points = pointsAsync.valueOrNull ?? const <DistributionMapPoint>[];
    final clusters = _clusterPoints(points, _zoom);
    _scheduleAutoFocus(points);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Sebaran'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(
              distributionMapPointsProvider(_filter),
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _zoom,
                minZoom: 3,
                maxZoom: 18,
                onPositionChanged: (camera, _) {
                  if ((_zoom - camera.zoom).abs() > 0.1) {
                    setState(() => _zoom = camera.zoom);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _filter.basemap.urlTemplate,
                  userAgentPackageName: 'com.tazidi.hoyaid',
                ),
                _BasemapAttribution(
                  basemap: _filter.basemap,
                ),
                if (_displayMode == _MapDisplayMode.heatmap &&
                    points.isNotEmpty)
                  HeatMapLayer(
                    key: ValueKey(_heatmapDataKey(points)),
                    heatMapDataSource: InMemoryHeatMapDataSource(
                      data: [
                        for (final point in points)
                          WeightedLatLng(point.point, 1),
                      ],
                    ),
                    heatMapOptions: HeatMapOptions(
                      radius: 42,
                      minOpacity: 0.1,
                      blurFactor: 0.8,
                      layerOpacity: 0.78,
                    ),
                  )
                else
                  MarkerLayer(
                    markers: [
                      for (final cluster in clusters)
                        Marker(
                          point: cluster.center,
                          width: cluster.isSingle ? 48 : 58,
                          height: cluster.isSingle ? 52 : 58,
                          child: _ClusterMarker(
                            cluster: cluster,
                            onTap: () {
                              if (cluster.isSingle) {
                                _showPointSheet(
                                  cluster.first,
                                  speciesById[cluster.first.record.speciesId],
                                );
                              } else {
                                _showClusterSheet(cluster, speciesById);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _MapControlBar(
              filter: _filter,
              displayMode: _displayMode,
              onTap: () => _showMapFilterSheet(
                species: species,
                canUseMine: canUseMine,
              ),
            ),
          ),
          if (pointsAsync.isLoading)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _MapStatusCard(
                icon: Icons.hourglass_empty,
                title: 'Memuat titik sebaran...',
              ),
            )
          else if (pointsAsync.hasError)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _MapStatusCard(
                icon: Icons.error_outline,
                title: 'Gagal memuat peta',
                message: readableErrorMessage(
                  pointsAsync.error!,
                  fallback: 'Gagal memuat titik sebaran.',
                ),
                action: TextButton.icon(
                  onPressed: () => ref.invalidate(
                    distributionMapPointsProvider(_filter),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ),
            )
          else if (points.isEmpty)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _MapStatusCard(
                icon: Icons.map_outlined,
                title: 'Belum ada titik sebaran',
                message: 'Coba longgarkan filter atau pilih mode lain.',
              ),
            ),
          if (points.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: FloatingActionButton.small(
                  heroTag: 'map-fit-points',
                  tooltip: 'Tampilkan semua temuan',
                  onPressed: () => _focusOnPoints(points),
                  child: const Icon(Icons.fit_screen_outlined),
                ),
              ),
            ),
          if (isAdmin)
            Positioned(
              left: 16,
              bottom: 16,
              child: SafeArea(
                child: FloatingActionButton.small(
                  heroTag: 'map-admin-history',
                  tooltip: 'Riwayat publik',
                  onPressed: () => context.push('/history'),
                  child: const Icon(Icons.manage_search_outlined),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _scheduleAutoFocus(List<DistributionMapPoint> points) {
    if (points.isEmpty) return;

    final dataKey = _heatmapDataKey(points);
    if (_lastAutoFocusKey == dataKey) return;
    _lastAutoFocusKey = dataKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusOnPoints(points);
    });
  }

  void _focusOnPoints(List<DistributionMapPoint> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first.point, 11.5);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
            points.map((point) => point.point).toList()),
        padding: const EdgeInsets.fromLTRB(28, 116, 28, 92),
        maxZoom: 12,
      ),
    );
  }

  void _showMapFilterSheet({
    required List<HoyaSpecies> species,
    required bool canUseMine,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.74,
        minChildSize: 0.48,
        maxChildSize: 0.94,
        builder: (context, scrollController) => _MapFilterSheet(
          filter: _filter,
          species: species,
          canUseMine: canUseMine,
          displayMode: _displayMode,
          scrollController: scrollController,
          onApply: (filter, displayMode) {
            var selectedFilter = filter;
            if (selectedFilter.scope == DistributionMapScope.mine &&
                !canUseMine) {
              selectedFilter = selectedFilter.copyWith(
                scope: DistributionMapScope.all,
              );
            }
            setState(() {
              _filter = selectedFilter;
              _displayMode = displayMode;
              _lastAutoFocusKey = null;
            });
          },
        ),
      ),
    );
  }

  List<DistributionCluster> _clusterPoints(
    List<DistributionMapPoint> points,
    double zoom,
  ) {
    if (points.isEmpty) return const [];
    if (zoom >= 12) {
      return [
        for (final point in points)
          DistributionCluster(points: [point], center: point.point),
      ];
    }

    final cellSize = switch (zoom) {
      < 5 => 3.0,
      < 7 => 1.2,
      < 9 => 0.45,
      < 11 => 0.18,
      _ => 0.07,
    };
    final buckets = <String, List<DistributionMapPoint>>{};

    for (final point in points) {
      final latBucket = (point.point.latitude / cellSize).floor();
      final lngBucket = (point.point.longitude / cellSize).floor();
      final key = '$latBucket:$lngBucket';
      buckets.putIfAbsent(key, () => []).add(point);
    }

    return buckets.values.map((items) {
      final lat =
          items.map((item) => item.point.latitude).reduce((a, b) => a + b) /
              items.length;
      final lng =
          items.map((item) => item.point.longitude).reduce((a, b) => a + b) /
              items.length;
      return DistributionCluster(points: items, center: LatLng(lat, lng));
    }).toList();
  }

  int _heatmapDataKey(List<DistributionMapPoint> points) {
    return Object.hashAll(
      points.map(
        (point) => Object.hash(
          point.record.classificationId,
          point.point.latitude,
          point.point.longitude,
        ),
      ),
    );
  }

  void _showPointSheet(DistributionMapPoint point, HoyaSpecies? species) {
    final record = point.record;
    final createdAt = record.createdAt == null
        ? '-'
        : DateFormat('dd MMM yyyy').format(record.createdAt!);

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                species?.displayName ?? record.speciesId,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Dibuat: $createdAt'),
              Text('Confidence: ${record.confidencePercent}'),
              Text('Verifikasi: ${record.verificationLabel}'),
              Text('Koordinat: ${record.locationLabel}'),
              Text(point.isPrecise ? 'Lokasi presisi' : 'Lokasi publik'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/history/${record.classificationId}');
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Buka Detail'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClusterSheet(
    DistributionCluster cluster,
    Map<String, HoyaSpecies> speciesById,
  ) {
    final sortedPoints = [...cluster.points]..sort((a, b) {
        final aDate = a.record.createdAt;
        final bDate = b.record.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${cluster.points.length} titik pada area ini',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sortedPoints.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final point = sortedPoints[index];
                    final record = point.record;
                    final species = speciesById[record.speciesId];
                    final date = record.createdAt == null
                        ? '-'
                        : DateFormat('dd MMM yyyy').format(record.createdAt!);
                    return ListTile(
                      leading: Icon(
                        Icons.location_pin,
                        color: _markerColor(context, point),
                      ),
                      title: Text(species?.displayName ?? record.speciesId),
                      subtitle: Text(
                        '${record.verificationLabel} • $date • '
                        '${point.isPrecise ? 'presisi' : 'publik'}',
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _mapController.move(point.point, 13);
                        _showPointSheet(point, species);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  final nextZoom = math.min(_zoom + 2.0, 18.0);
                  _mapController.move(cluster.center, nextZoom);
                },
                icon: const Icon(Icons.zoom_in_map_outlined),
                label: const Text('Zoom ke area'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BasemapAttribution extends StatelessWidget {
  final DistributionBasemap basemap;

  const _BasemapAttribution({required this.basemap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomLeft,
      child: SafeArea(
        top: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Tooltip(
            message: basemap.attribution,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 210),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                '© ${basemap.compactAttribution}',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      height: 1.1,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControlBar extends StatelessWidget {
  final DistributionMapFilter filter;
  final _MapDisplayMode displayMode;
  final VoidCallback onTap;

  const _MapControlBar({
    required this.filter,
    required this.displayMode,
    required this.onTap,
  });

  String get _summary {
    final items = <String>[
      filter.scope == DistributionMapScope.mine
          ? 'Data saya'
          : filter.verificationFilter == DistributionVerificationFilter.all
              ? 'Semua temuan'
              : filter.verificationFilter.label,
      displayMode == _MapDisplayMode.markers ? 'Marker' : 'Heatmap',
    ];
    if (filter.speciesId != null) items.add('Spesies dipilih');
    if (filter.dateBucket != null) items.add(filter.dateBucket!);
    return items.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                child: const Icon(Icons.tune),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter & tampilan peta',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Badge(
                isLabelVisible: filter.hasActiveFilters,
                label: Text(filter.activeFilterCount.toString()),
                child: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFilterSheet extends StatefulWidget {
  final DistributionMapFilter filter;
  final List<HoyaSpecies> species;
  final bool canUseMine;
  final _MapDisplayMode displayMode;
  final ScrollController scrollController;
  final void Function(DistributionMapFilter, _MapDisplayMode) onApply;

  const _MapFilterSheet({
    required this.filter,
    required this.species,
    required this.canUseMine,
    required this.displayMode,
    required this.scrollController,
    required this.onApply,
  });

  @override
  State<_MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<_MapFilterSheet> {
  static final _monthPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

  late DistributionMapFilter _draftFilter;
  late _MapDisplayMode _draftDisplayMode;
  late TextEditingController _dateBucketController;

  @override
  void initState() {
    super.initState();
    _draftFilter = widget.filter;
    _draftDisplayMode = widget.displayMode;
    _dateBucketController = TextEditingController(
      text: widget.filter.dateBucket ?? '',
    );
  }

  @override
  void dispose() {
    _dateBucketController.dispose();
    super.dispose();
  }

  void _resetDataFilters() {
    setState(() {
      _draftFilter = DistributionMapFilter(basemap: _draftFilter.basemap);
      _dateBucketController.clear();
    });
  }

  void _apply() {
    final month = _dateBucketController.text.trim();
    if (month.isNotEmpty && !_monthPattern.hasMatch(month)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format bulan harus YYYY-MM.')),
      );
      return;
    }

    final selectedFilter = _draftFilter.copyWith(
      dateBucket: month,
      clearDateBucket: month.isEmpty,
    );
    widget.onApply(selectedFilter, _draftDisplayMode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter & tampilan peta',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Atur pilihan, lalu tekan Terapkan untuk memperbarui peta.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tutup',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _MapControlSection(
          icon: Icons.layers_outlined,
          title: 'Tampilan peta',
        ),
        const SizedBox(height: 10),
        SegmentedButton<_MapDisplayMode>(
          segments: const [
            ButtonSegment(
              value: _MapDisplayMode.markers,
              icon: Icon(Icons.location_pin),
              label: Text('Marker'),
            ),
            ButtonSegment(
              value: _MapDisplayMode.heatmap,
              icon: Icon(Icons.local_fire_department_outlined),
              label: Text('Heatmap'),
            ),
          ],
          selected: {_draftDisplayMode},
          onSelectionChanged: (value) {
            setState(() => _draftDisplayMode = value.first);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BasemapQuickButton(
                selected:
                    _draftFilter.basemap == DistributionBasemap.defaultMap,
                icon: Icons.map_outlined,
                label: 'Jalan',
                onPressed: () {
                  setState(
                    () => _draftFilter = _draftFilter.copyWith(
                      basemap: DistributionBasemap.defaultMap,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BasemapQuickButton(
                selected: _draftFilter.basemap == DistributionBasemap.satellite,
                icon: Icons.satellite_alt_outlined,
                label: 'Satelit',
                onPressed: () {
                  setState(
                    () => _draftFilter = _draftFilter.copyWith(
                      basemap: DistributionBasemap.satellite,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BasemapQuickButton(
                selected:
                    _draftFilter.basemap == DistributionBasemap.topography,
                icon: Icons.terrain_outlined,
                label: 'Topo',
                onPressed: () {
                  setState(
                    () => _draftFilter = _draftFilter.copyWith(
                      basemap: DistributionBasemap.topography,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _draftDisplayMode == _MapDisplayMode.markers
              ? const _MarkerLegend()
              : const _HeatmapLegend(),
        ),
        const SizedBox(height: 24),
        const _MapControlSection(
          icon: Icons.filter_alt_outlined,
          title: 'Data temuan',
        ),
        const SizedBox(height: 10),
        SegmentedButton<DistributionMapScope>(
          segments: [
            const ButtonSegment(
              value: DistributionMapScope.all,
              icon: Icon(Icons.public),
              label: Text('Semua'),
            ),
            ButtonSegment(
              value: DistributionMapScope.mine,
              enabled: widget.canUseMine,
              icon: const Icon(Icons.person_pin_circle_outlined),
              label: const Text('Saya'),
            ),
          ],
          selected: {_draftFilter.scope},
          onSelectionChanged: (value) {
            setState(
                () => _draftFilter = _draftFilter.copyWith(scope: value.first));
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<DistributionVerificationFilter>(
          segments: const [
            ButtonSegment(
              value: DistributionVerificationFilter.verified,
              icon: Icon(Icons.verified_outlined),
              label: Text('Terverifikasi'),
            ),
            ButtonSegment(
              value: DistributionVerificationFilter.publicUnverified,
              icon: Icon(Icons.public_outlined),
              label: Text('Publik'),
            ),
            ButtonSegment(
              value: DistributionVerificationFilter.all,
              icon: Icon(Icons.layers_clear_outlined),
              label: Text('Semua'),
            ),
          ],
          selected: {_draftFilter.verificationFilter},
          onSelectionChanged: (value) {
            setState(
              () => _draftFilter = _draftFilter.copyWith(
                verificationFilter: value.first,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(_draftFilter.speciesId ?? ''),
          initialValue: _draftFilter.speciesId ?? '',
          isExpanded: true,
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
            setState(
              () => _draftFilter = _draftFilter.copyWith(
                speciesId: value,
                clearSpeciesId: value == null || value.isEmpty,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dateBucketController,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'Bulan temuan',
            hintText: 'YYYY-MM, mis. 2026-07',
            prefixIcon: Icon(Icons.calendar_month_outlined),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _resetDataFilters,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset filter'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: const Text('Terapkan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BasemapQuickButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BasemapQuickButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Peta $label',
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 72),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          backgroundColor: selected ? colors.primaryContainer : null,
          foregroundColor:
              selected ? colors.onPrimaryContainer : colors.onSurface,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _MapControlSection extends StatelessWidget {
  final IconData icon;
  final String title;

  const _MapControlSection({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _ClusterMarker extends StatelessWidget {
  final DistributionCluster cluster;
  final VoidCallback onTap;

  const _ClusterMarker({
    required this.cluster,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cluster.isSingle) {
      final point = cluster.first;
      return GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.location_pin,
              color: _markerColor(context, point),
              size: 46,
              shadows: const [
                Shadow(blurRadius: 6, color: Colors.black38),
              ],
            ),
            if (point.record.isVerified)
              Positioned(
                right: 0,
                top: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black26,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            cluster.points.length.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

Color _markerColor(BuildContext context, DistributionMapPoint point) {
  if (point.record.isVerified) return Colors.green;
  if (point.record.isUnverified) return Colors.orange;
  return Theme.of(context).colorScheme.error;
}

class _MarkerLegend extends StatelessWidget {
  const _MarkerLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _LegendItem(color: Colors.green, label: 'Terverifikasi Ahli'),
        _LegendItem(color: Colors.orange, label: 'Pending/Unverified'),
      ],
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _HeatmapLegendItem(color: Colors.blue, label: 'Rendah'),
        _HeatmapLegendItem(color: Colors.red, label: 'Tinggi'),
      ],
    );
  }
}

class _HeatmapLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _HeatmapLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_pin, color: color, size: 18),
        const SizedBox(width: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MapStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const _MapStatusCard({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (message != null) Text(message!),
                    if (action != null) ...[
                      const SizedBox(height: 8),
                      action!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
