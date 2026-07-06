import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';

class AdminModelUploadScreen extends ConsumerStatefulWidget {
  const AdminModelUploadScreen({super.key});

  @override
  ConsumerState<AdminModelUploadScreen> createState() =>
      _AdminModelUploadScreenState();
}

class _AdminModelUploadScreenState
    extends ConsumerState<AdminModelUploadScreen> {
  final TextEditingController _versionController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _pickModelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['tflite'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => _selectedFile = file);
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih file model .tflite terlebih dulu.')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      await ref.read(classificationConfigServiceProvider).uploadModelVersion(
            version: _versionController.text,
            fileName: file.name,
            bytes: bytes,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model berhasil diunggah dan diaktifkan.')),
      );
      setState(() => _selectedFile = null);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(readableErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Upload Model')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pembaruan Model Dinamis',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unggah file TFLite terbaru. Sistem akan menyimpan file '
                      'ke Firebase Storage dan memperbarui konfigurasi model aktif.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _versionController,
                      decoration: const InputDecoration(
                        labelText: 'Versi model',
                        hintText: 'contoh: hoya_model_v2',
                        prefixIcon: Icon(Icons.model_training_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickModelFile,
                      icon: const Icon(Icons.attach_file),
                      label: Text(_selectedFile?.name ?? 'Pilih file .tflite'),
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ukuran: ${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isUploading ? null : _upload,
                      icon: _isUploading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(_isUploading ? 'Mengunggah...' : 'Upload & Aktifkan'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Catatan: pastikan label_map untuk versi model ini sudah sesuai '
                  'dengan jumlah output model sebelum model digunakan pengguna.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
