import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/species/models/label_map.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';
import 'package:hoyaid/shared/widgets/loading_widget.dart' as shared;

class AdminLabelMapScreen extends ConsumerStatefulWidget {
  const AdminLabelMapScreen({super.key});

  @override
  ConsumerState<AdminLabelMapScreen> createState() =>
      _AdminLabelMapScreenState();
}

class _AdminLabelMapScreenState extends ConsumerState<AdminLabelMapScreen> {
  final TextEditingController _modelVersionController =
      TextEditingController(text: 'hoya_model_v1');
  final List<TextEditingController> _labelControllers = [];
  String _modelVersion = 'hoya_model_v1';
  bool _isActive = true;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _modelVersionController.dispose();
    for (final controller in _labelControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Kelola Label Map')),
        body: ref.watch(labelMapProvider(_modelVersion)).when(
              data: (labelMap) {
                if (!_initialized && labelMap != null) {
                  _initialize(labelMap);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    TextField(
                      controller: _modelVersionController,
                      decoration: const InputDecoration(
                        labelText: 'Model version',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _changeModelVersion,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _changeModelVersion(_modelVersionController.text),
                      icon: const Icon(Icons.search),
                      label: const Text('Muat model version'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _isActive,
                      title: const Text('Label map aktif'),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _isActive = value),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loadFromAssetLabels,
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('Muat labels.txt'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_isSaving ? 'Simpan...' : 'Simpan'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_labelControllers.length} label',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_labelControllers.isEmpty)
                      const shared.EmptyStateWidget(
                        title: 'Belum ada label',
                        subtitle: 'Muat dari labels.txt atau isi manual.',
                        icon: Icons.account_tree_outlined,
                      )
                    else
                      for (var index = 0;
                          index < _labelControllers.length;
                          index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: _labelControllers[index],
                            decoration: InputDecoration(
                              labelText: 'labelIndex $index',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                  ],
                );
              },
              loading: () =>
                  const shared.LoadingWidget(message: 'Memuat label map...'),
              error: (error, stackTrace) => shared.ErrorWidget(
                message: 'Gagal memuat label map: $error',
                onRetry: () => ref.invalidate(labelMapProvider(_modelVersion)),
              ),
            ),
      ),
    );
  }

  void _initialize(LabelMapModel labelMap) {
    _replaceControllers(
      labelMap.labels.map((entry) => entry.speciesId).toList(),
    );
    _modelVersionController.text = labelMap.modelVersion;
    _isActive = labelMap.isActive;
    _initialized = true;
  }

  void _replaceControllers(List<String> values) {
    for (final controller in _labelControllers) {
      controller.dispose();
    }
    _labelControllers
      ..clear()
      ..addAll(values.map((value) => TextEditingController(text: value)));
  }

  void _changeModelVersion(String value) {
    final next = value.trim();
    if (next.isEmpty || next == _modelVersion) return;
    setState(() {
      _modelVersion = next;
      _initialized = false;
      _replaceControllers([]);
    });
  }

  Future<void> _loadFromAssetLabels() async {
    try {
      final content = await rootBundle.loadString('assets/models/labels.txt');
      final labels = content
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      setState(() {
        _replaceControllers(labels);
        _initialized = true;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca labels.txt: $error')),
        );
      }
    }
  }

  Future<void> _save() async {
    final speciesIds = _labelControllers
        .map((controller) => controller.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final duplicates = <String>{};
    final seen = <String>{};
    for (final speciesId in speciesIds) {
      if (!seen.add(speciesId)) duplicates.add(speciesId);
    }

    if (speciesIds.isEmpty) {
      _showSnack('Label map tidak boleh kosong.');
      return;
    }
    if (duplicates.isNotEmpty) {
      _showSnack('Ada speciesId duplikat: ${duplicates.join(', ')}');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = ref.read(currentUserProvider);
      final modelVersion = _modelVersionController.text.trim().isEmpty
          ? _modelVersion
          : _modelVersionController.text.trim();
      final labelMap = LabelMapModel(
        modelVersion: modelVersion,
        modelAssetPath: 'assets/models/$modelVersion.tflite',
        labelsAssetPath: 'assets/models/labels.txt',
        isActive: _isActive,
        labels: [
          for (var index = 0; index < speciesIds.length; index++)
            LabelMapEntry(labelIndex: index, speciesId: speciesIds[index]),
        ],
      );

      await ref
          .read(speciesServiceProvider)
          .saveLabelMap(labelMap, actorId: user?.uid);

      if (mounted) {
        _showSnack('Label map berhasil disimpan.');
      }
    } catch (error) {
      if (mounted) {
        _showSnack('Gagal menyimpan label map: $error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
