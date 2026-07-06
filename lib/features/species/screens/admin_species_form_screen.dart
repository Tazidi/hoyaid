import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/species/models/hoya_species.dart';
import 'package:hoyaid/features/species/providers/species_provider.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';
import 'package:hoyaid/features/species/widgets/species_reference_image.dart';
import 'package:hoyaid/shared/widgets/loading_widget.dart' as shared;
import 'package:image_picker/image_picker.dart';

class AdminSpeciesFormScreen extends ConsumerStatefulWidget {
  final String? speciesId;

  const AdminSpeciesFormScreen({
    super.key,
    this.speciesId,
  });

  @override
  ConsumerState<AdminSpeciesFormScreen> createState() =>
      _AdminSpeciesFormScreenState();
}

class _AdminSpeciesFormScreenState
    extends ConsumerState<AdminSpeciesFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _speciesIdController = TextEditingController();
  final _scientificNameController = TextEditingController();
  final _localNameController = TextEditingController();
  final _distributionController = TextEditingController(text: '-');
  final _descriptionController = TextEditingController(text: '-');
  final _medicalUseDescriptionController = TextEditingController(text: '-');
  final _referenceImageUrlController = TextEditingController();

  bool _hasMedicalUse = false;
  bool _isRare = false;
  bool _isActive = true;
  bool _isSaving = false;
  bool _initialized = false;
  XFile? _pickedImage;
  String? _referenceStoragePath;

  bool get _isEditing => widget.speciesId != null;

  @override
  void dispose() {
    _speciesIdController.dispose();
    _scientificNameController.dispose();
    _localNameController.dispose();
    _distributionController.dispose();
    _descriptionController.dispose();
    _medicalUseDescriptionController.dispose();
    _referenceImageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Spesies' : 'Tambah Spesies'),
        ),
        body: _isEditing
            ? ref.watch(speciesDetailProvider(widget.speciesId!)).when(
                  data: (species) {
                    if (species == null) {
                      return const Center(child: Text('Spesies tidak ada.'));
                    }
                    _initializeFromSpecies(species);
                    return _buildForm(context);
                  },
                  loading: () =>
                      const shared.LoadingWidget(message: 'Memuat spesies...'),
                  error: (error, stackTrace) => shared.ErrorWidget(
                    message: 'Gagal memuat spesies: $error',
                    onRetry: () => ref.invalidate(
                      speciesDetailProvider(widget.speciesId!),
                    ),
                  ),
                )
            : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SpeciesReferenceImage(
            imageUrl: _referenceImageUrlController.text,
            height: 180,
            width: double.infinity,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              _pickedImage == null
                  ? 'Pilih gambar referensi'
                  : 'Gambar dipilih: ${_pickedImage!.name}',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _speciesIdController,
            enabled: !_isEditing,
            decoration: const InputDecoration(
              labelText: 'speciesId',
              border: OutlineInputBorder(),
              helperText: 'Contoh: hoya_amicabilis',
            ),
            validator: (value) {
              final normalized = _normalizeSpeciesId(value ?? '');
              if (normalized.isEmpty) return 'speciesId wajib diisi';
              if (!normalized.startsWith('hoya_')) {
                return 'speciesId harus memakai prefix hoya_';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _scientificNameController,
            decoration: const InputDecoration(
              labelText: 'Nama ilmiah',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama ilmiah wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _localNameController,
            decoration: const InputDecoration(
              labelText: 'Nama lokal',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _distributionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Persebaran',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Deskripsi',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _hasMedicalUse,
            title: const Text('Memiliki pemanfaatan medis'),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => _hasMedicalUse = value),
          ),
          TextFormField(
            controller: _medicalUseDescriptionController,
            enabled: _hasMedicalUse,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Deskripsi pemanfaatan medis',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _referenceImageUrlController,
            decoration: const InputDecoration(
              labelText: 'Reference image URL',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _isRare,
            title: const Text('Spesies langka'),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => _isRare = value),
          ),
          SwitchListTile(
            value: _isActive,
            title: const Text('Aktif'),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => _isActive = value),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }

  void _initializeFromSpecies(HoyaSpecies species) {
    if (_initialized) return;

    _speciesIdController.text = species.speciesId;
    _scientificNameController.text = species.scientificName;
    _localNameController.text = species.localName ?? '';
    _distributionController.text = species.distribution;
    _descriptionController.text = species.description;
    _medicalUseDescriptionController.text = species.medicalUseDescription;
    _referenceImageUrlController.text = species.referenceImageUrl ?? '';
    _referenceStoragePath = species.referenceStoragePath;
    _hasMedicalUse = species.hasMedicalUse;
    _isRare = species.isRare;
    _isActive = species.isActive;
    _initialized = true;
  }

  Future<void> _pickImage() async {
    try {
      final image = await ref.read(speciesServiceProvider).pickReferenceImage();
      if (image == null) return;
      setState(() => _pickedImage = image);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $error')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(speciesServiceProvider);
      final user = ref.read(currentUserProvider);
      final speciesId = _normalizeSpeciesId(_speciesIdController.text);
      var referenceImageUrl = _emptyToNull(_referenceImageUrlController.text);
      var referenceStoragePath = _referenceStoragePath;

      if (_pickedImage != null) {
        final upload = await service.uploadReferenceImage(
          speciesId: speciesId,
          image: _pickedImage!,
        );
        referenceImageUrl = upload.url;
        referenceStoragePath = upload.storagePath;
      }

      final medicalUseDescription = _hasMedicalUse
          ? _defaultDash(_medicalUseDescriptionController.text)
          : '-';

      final species = HoyaSpecies(
        speciesId: speciesId,
        scientificName: _scientificNameController.text.trim(),
        localName: _emptyToNull(_localNameController.text),
        distribution: _defaultDash(_distributionController.text),
        description: _defaultDash(_descriptionController.text),
        hasMedicalUse: _hasMedicalUse,
        medicalUse: medicalUseDescription,
        medicalUseDescription: medicalUseDescription,
        referenceImageUrl: referenceImageUrl,
        referenceStoragePath: referenceStoragePath,
        isRare: _isRare,
        isActive: _isActive,
      );

      await service.saveSpecies(species, actorId: user?.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spesies berhasil disimpan')),
        );
        context.go('/admin/species');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan spesies: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _normalizeSpeciesId(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized;
  }

  String _defaultDash(String value) {
    final text = value.trim();
    return text.isEmpty ? '-' : text;
  }

  String? _emptyToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
