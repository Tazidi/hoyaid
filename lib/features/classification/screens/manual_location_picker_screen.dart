import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/classification/models/classification_models.dart';
import 'package:latlong2/latlong.dart';

class ManualLocationPickerScreen extends StatefulWidget {
  const ManualLocationPickerScreen({super.key});

  @override
  State<ManualLocationPickerScreen> createState() =>
      _ManualLocationPickerScreenState();
}

class _ManualLocationPickerScreenState
    extends State<ManualLocationPickerScreen> {
  static const _initialCenter = LatLng(-2.5489, 118.0149);
  LatLng? _selectedPoint;

  void _saveSelection() {
    final point = _selectedPoint;
    if (point == null) return;

    context.pop<ClassificationLocation>(
      ClassificationLocation(
        latitude: point.latitude,
        longitude: point.longitude,
        source: ClassificationLocationSource.manual,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        actions: [
          TextButton(
            onPressed: selected == null ? null : _saveSelection,
            child: const Text('Simpan'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: selected ?? _initialCenter,
                initialZoom: 4.7,
                onTap: (_, point) => setState(() => _selectedPoint = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tazidi.hoyaid',
                ),
                if (selected != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selected,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 44,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selected == null
                              ? 'Tap peta untuk menandai lokasi.'
                              : '${selected.latitude.toStringAsFixed(5)}, '
                                  '${selected.longitude.toStringAsFixed(5)}',
                        ),
                      ),
                      FilledButton(
                        onPressed: selected == null ? null : _saveSelection,
                        child: const Text('Pakai'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
