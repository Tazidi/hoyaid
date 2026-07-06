import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/admin/models/admin_models.dart';
import 'package:hoyaid/features/admin/providers/admin_provider.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';
import 'package:intl/intl.dart';

class AdminExportScreen extends ConsumerStatefulWidget {
  const AdminExportScreen({super.key});

  @override
  ConsumerState<AdminExportScreen> createState() => _AdminExportScreenState();
}

class _AdminExportScreenState extends ConsumerState<AdminExportScreen> {
  bool _verifiedOnly = true;
  bool _isExporting = false;
  DatasetExportResult? _lastResult;

  Future<void> _export() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final result = await ref.read(adminServiceProvider).exportDataset(
            verifiedOnly: _verifiedOnly,
          );
      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ekspor dataset selesai.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(readableErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Ekspor Dataset')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manifest Retraining',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ekspor menghasilkan manifest JSON berisi path gambar 640, label model, label koreksi, metadata, dan status verifikasi.',
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: _verifiedOnly,
                      onChanged: _isExporting
                          ? null
                          : (value) => setState(() => _verifiedOnly = value),
                      title: const Text('Hanya data verified'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _isExporting ? null : _export,
                      icon: _isExporting
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(_isExporting ? 'Mengekspor...' : 'Ekspor'),
                    ),
                  ],
                ),
              ),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              _ExportResultCard(result: _lastResult!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportResultCard extends StatelessWidget {
  final DatasetExportResult result;

  const _ExportResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final generatedAt = result.generatedAt == null
        ? '-'
        : DateFormat('dd MMM yyyy HH:mm').format(result.generatedAt!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil Ekspor',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _Row(label: 'Jumlah row', value: result.rowCount.toString()),
            _Row(label: 'Generated', value: generatedAt),
            _Row(label: 'Storage path', value: result.storagePath),
            if (result.downloadUrl?.isNotEmpty == true)
              _Row(label: 'Download URL', value: result.downloadUrl!),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
