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
  static const _initialZoom = 4.7;

  final MapController _mapController = MapController();
  LatLng _selectedPoint = _initialCenter;

  void _saveSelection() {
    context.pop<ClassificationLocation>(
      ClassificationLocation(
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
        source: ClassificationLocationSource.manual,
      ),
    );
  }

  void _selectPoint(TapPosition _, LatLng point) {
    setState(() => _selectedPoint = point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        actions: [
          TextButton(
            onPressed: _saveSelection,
            child: const Text('Simpan'),
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
                initialZoom: _initialZoom,
                minZoom: 3,
                maxZoom: 18,
                onTap: _selectPoint,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tazidi.hoyaid',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
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
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    // Only an Icon + Expanded here — no trailing non-flexible
                    // widget. A RenderFlex measures its non-flex children with
                    // an unbounded main-axis width, and during the route's
                    // offstage push transition the whole body is briefly laid
                    // out unbounded; a fixed-size child (e.g. a FilledButton)
                    // would then be asked to lay out at infinite width and
                    // throw, poisoning the subtree and leaving the screen blank
                    // and frozen. Expanded absorbs the width instead, and the
                    // AppBar "Simpan" action already covers saving.
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ketuk peta untuk memilih titik, lalu tekan '
                            'Simpan. Terpilih: '
                            '${_selectedPoint.latitude.toStringAsFixed(5)}, '
                            '${_selectedPoint.longitude.toStringAsFixed(5)}',
                          ),
                        ),
                      ],
                    ),
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
