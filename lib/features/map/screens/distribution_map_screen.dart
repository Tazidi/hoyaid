import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

class DistributionMapScreen extends ConsumerStatefulWidget {
  const DistributionMapScreen({super.key});

  @override
  ConsumerState<DistributionMapScreen> createState() =>
      _DistributionMapScreenState();
}

class _DistributionMapScreenState extends ConsumerState<DistributionMapScreen> {
  static const _initialCenter = LatLng(-2.5489, 118.0149);

  final MapController _mapController = MapController();
  final TextEditingController _dateBucketController = TextEditingController();
  DistributionMapFilter _filter = const DistributionMapFilter();
  double _zoom = 4.7;

  @override
  void dispose() {
    _dateBucketController.dispose();
    super.dispose();
  }

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
            child: _MapFilterPanel(
              filter: _filter,
              species: species,
              canUseMine: canUseMine,
              onChanged: (filter) {
                setState(() {
                  _filter = filter;
                  if (filter.scope == DistributionMapScope.mine &&
                      !canUseMine) {
                    _filter = filter.copyWith(scope: DistributionMapScope.all);
                  }
                });
              },
              dateBucketController: _dateBucketController,
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
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'map-reset',
                tooltip: 'Kembali ke Indonesia',
                onPressed: () => _mapController.move(_initialCenter, 4.7),
                child: const Icon(Icons.my_location_outlined),
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
    final sortedPoints = [...cluster.points]
      ..sort((a, b) {
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

class _MapFilterPanel extends StatelessWidget {
  final DistributionMapFilter filter;
  final List<HoyaSpecies> species;
  final bool canUseMine;
  final ValueChanged<DistributionMapFilter> onChanged;
  final TextEditingController dateBucketController;

  const _MapFilterPanel({
    required this.filter,
    required this.species,
    required this.canUseMine,
    required this.onChanged,
    required this.dateBucketController,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: filter.hasActiveFilters,
        leading: const Icon(Icons.tune),
        title: const Text('Filter Peta'),
        subtitle: Text(
          filter.scope == DistributionMapScope.mine
              ? 'Data saya'
              : filter.verificationFilter.label,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SegmentedButton<DistributionMapScope>(
            segments: const [
              ButtonSegment(
                value: DistributionMapScope.all,
                icon: Icon(Icons.public),
                label: Text('Semua'),
              ),
              ButtonSegment(
                value: DistributionMapScope.mine,
                icon: Icon(Icons.person_pin_circle_outlined),
                label: Text('Saya'),
              ),
            ],
            selected: {filter.scope},
            onSelectionChanged: (value) {
              final selected = value.first;
              if (selected == DistributionMapScope.mine && !canUseMine) return;
              onChanged(filter.copyWith(scope: selected));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DistributionBasemap>(
            initialValue: filter.basemap,
            decoration: const InputDecoration(
              labelText: 'Basemap',
              prefixIcon: Icon(Icons.layers_outlined),
            ),
            items: [
              for (final basemap in DistributionBasemap.values)
                DropdownMenuItem(
                  value: basemap,
                  child: Text(basemap.label),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              onChanged(filter.copyWith(basemap: value));
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
            selected: {filter.verificationFilter},
            onSelectionChanged: (value) {
              onChanged(filter.copyWith(verificationFilter: value.first));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: filter.speciesId ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Spesies',
              prefixIcon: Icon(Icons.grass_outlined),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua spesies')),
              for (final item in species)
                DropdownMenuItem(
                  value: item.speciesId,
                  child: Text(item.displayName),
                ),
            ],
            onChanged: (value) {
              onChanged(
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
                child: TextField(
                  controller: dateBucketController,
                  decoration: const InputDecoration(
                    labelText: 'Bulan',
                    hintText: 'YYYY-MM',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  onSubmitted: (value) {
                    final normalized = value.trim();
                    onChanged(
                      filter.copyWith(
                        dateBucket: normalized,
                        clearDateBucket: normalized.isEmpty,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _MarkerLegend(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final normalized = dateBucketController.text.trim();
                onChanged(
                  filter.copyWith(
                    dateBucket: normalized,
                    clearDateBucket: normalized.isEmpty,
                  ),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Terapkan'),
            ),
          ),
        ],
      ),
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
