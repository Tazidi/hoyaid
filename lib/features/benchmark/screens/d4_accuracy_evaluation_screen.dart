import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hoyaid/features/benchmark/models/d4_accuracy_evaluation_models.dart';
import 'package:hoyaid/features/benchmark/services/d4_accuracy_evaluation_service.dart';
import 'package:hoyaid/features/benchmark/services/d4_accuracy_log_storage.dart';
import 'package:hoyaid/features/classification/models/classification_config.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';

enum D4ModelChoiceType {
  firebaseActive, // Model Aktif Firebase (app_config/general)
  assetDefault, // Model Aset Bawaan (hoya_model_v1.tflite)
  customFile, // File .tflite lokal yang dipilih dari HP
}

class D4AccuracyEvaluationScreen extends ConsumerStatefulWidget {
  const D4AccuracyEvaluationScreen({super.key});

  @override
  ConsumerState<D4AccuracyEvaluationScreen> createState() =>
      _D4AccuracyEvaluationScreenState();
}

class _D4AccuracyEvaluationScreenState
    extends ConsumerState<D4AccuracyEvaluationScreen> {
  String? _datasetRoot;
  D4AccuracyEvaluationResult? _result;
  D4AccuracyLogFiles? _logFiles;
  String? _error;
  bool _isRunning = false;
  bool _isExtracting = false;
  String _extractingStatus = '';
  int _completed = 0;
  int _total = 355;
  String? _currentFile;
  bool _isDatasetValid = false;

  // Model Selection State
  D4ModelChoiceType _modelChoice = D4ModelChoiceType.firebaseActive;
  ClassificationConfig? _remoteConfig;
  File? _customModelFile;
  String _customModelName = '';
  bool _isLoadingConfig = false;

  @override
  void initState() {
    super.initState();
    _autoDetectDataset();
    _loadActiveRemoteConfig();
  }

  Future<void> _loadActiveRemoteConfig() async {
    setState(() => _isLoadingConfig = true);
    try {
      final config =
          await ref.read(classificationConfigServiceProvider).getConfig();
      if (!mounted) return;
      setState(() {
        _remoteConfig = config;
        _isLoadingConfig = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingConfig = false);
    }
  }

  /// Pindai lokasi-lokasi umum di HP Android untuk mencari folder mobile_d4_test
  Future<void> _autoDetectDataset() async {
    final candidatePaths = <String>[];

    try {
      final appDoc = await getApplicationDocumentsDirectory();
      candidatePaths.add('${appDoc.path}${Platform.pathSeparator}mobile_d4_test');
    } catch (_) {}

    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        candidatePaths.add('${ext.path}${Platform.pathSeparator}mobile_d4_test');
      }
    } catch (_) {}

    // Jalur penyimpanan publik standar Android
    candidatePaths.addAll([
      '/storage/emulated/0/Download/mobile_d4_test',
      '/storage/emulated/0/Documents/mobile_d4_test',
      '/storage/emulated/0/mobile_d4_test',
      '/sdcard/Download/mobile_d4_test',
      '/sdcard/Documents/mobile_d4_test',
    ]);

    for (final path in candidatePaths) {
      if (await _checkIsValidDataset(path)) {
        if (!mounted) return;
        setState(() {
          _datasetRoot = path;
          _isDatasetValid = true;
          _error = null;
        });
        return;
      }
    }

    try {
      final appDoc = await getApplicationDocumentsDirectory();
      final defaultPath = '${appDoc.path}${Platform.pathSeparator}mobile_d4_test';
      if (!mounted) return;
      setState(() {
        _datasetRoot = defaultPath;
        _isDatasetValid = false;
      });
    } catch (_) {}
  }

  Future<bool> _checkIsValidDataset(String? path) async {
    if (path == null || path.isEmpty) return false;
    final manifest = File('$path${Platform.pathSeparator}d4_test_manifest.csv');
    final imagesDir = Directory('$path${Platform.pathSeparator}images');
    return await manifest.exists() && await imagesDir.exists();
  }

  /// 1. Pilih File ZIP langsung (mobile_d4_test.zip) dan ekstrak otomatis ke storage internal aplikasi
  Future<void> _pickAndExtractZip() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      final file = result?.files.single;
      if (file == null) return;

      if (!file.name.toLowerCase().endsWith('.zip')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap pilih file berformat .zip (contoh: mobile_d4_test.zip)'),
          ),
        );
        return;
      }

      setState(() {
        _isExtracting = true;
        _extractingStatus = 'Membaca file ${file.name}...';
        _error = null;
      });

      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          bytes = await ioFile.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        throw StateError('File ZIP tidak dapat dibaca.');
      }

      final appDoc = await getApplicationDocumentsDirectory();
      final destDir = Directory('${appDoc.path}${Platform.pathSeparator}mobile_d4_test');
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      setState(() => _extractingStatus = 'Mengekstrak 355 citra data uji...');

      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        String relativeName = entry.name;
        if (relativeName.startsWith('mobile_d4_test/')) {
          relativeName = relativeName.substring('mobile_d4_test/'.length);
        } else if (relativeName.startsWith('mobile_d4_test\\')) {
          relativeName = relativeName.substring('mobile_d4_test\\'.length);
        }
        if (relativeName.isEmpty) continue;

        if (entry.isFile) {
          final outFile = File('${destDir.path}${Platform.pathSeparator}$relativeName');
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(entry.content as List<int>);
        } else {
          await Directory('${destDir.path}${Platform.pathSeparator}$relativeName')
              .create(recursive: true);
        }
      }

      final isValid = await _checkIsValidDataset(destDir.path);
      if (!mounted) return;
      setState(() {
        _datasetRoot = destDir.path;
        _isDatasetValid = isValid;
        _isExtracting = false;
        _error = isValid ? null : 'Ekstraksi selesai tetapi format dataset belum lengkap.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isValid
                ? 'Dataset D4 berhasil diekstrak dan siap diuji!'
                : 'Ekstraksi selesai, periksa isi folder.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _error = 'Gagal mengekstrak ZIP: $error';
      });
    }
  }

  /// 2. Pilih Folder langsung via sistem File Picker
  Future<void> _pickDirectory() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih folder mobile_d4_test',
      );
      if (!mounted || path == null) return;
      final isValid = await _checkIsValidDataset(path);
      setState(() {
        _datasetRoot = path;
        _isDatasetValid = isValid;
        _result = null;
        _logFiles = null;
        _error = isValid ? null : 'Folder yang dipilih tidak berisi d4_test_manifest.csv dan folder images/.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Gagal memilih folder data uji: $error');
      }
    }
  }

  /// 3. Ketik atau Tempel Path Folder Manual
  Future<void> _enterPathManually() async {
    final controller = TextEditingController(text: _datasetRoot);
    final selectedPath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan Path Folder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempel lokasi folder mobile_d4_test di HP Anda:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '/storage/emulated/0/Download/mobile_d4_test',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pastikan di dalamnya terdapat d4_test_manifest.csv dan folder images/.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (selectedPath != null && selectedPath.isNotEmpty) {
      final isValid = await _checkIsValidDataset(selectedPath);
      if (!mounted) return;
      setState(() {
        _datasetRoot = selectedPath;
        _isDatasetValid = isValid;
        _error = isValid ? null : 'Path tidak memuat d4_test_manifest.csv dan folder images/.';
      });
    }
  }

  /// Menu pilihan metode pemilihan dataset
  void _showDatasetPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Pilih Sumber Dataset D4',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.archive_outlined, color: Colors.white),
                ),
                title: const Text('Pilih File ZIP (Rekomendasi)'),
                subtitle: const Text('Pilih mobile_d4_test.zip, aplikasi mengekstrak otomatis.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndExtractZip();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.folder_open_outlined, color: Colors.white),
                ),
                title: const Text('Pilih Folder via File Picker'),
                subtitle: const Text('Arahkan ke folder mobile_d4_test yang ada di HP.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickDirectory();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.edit_location_alt_outlined, color: Colors.white),
                ),
                title: const Text('Ketik / Tempel Path Manual'),
                subtitle: const Text('Masukkan path seperti /storage/emulated/0/Download/mobile_d4_test.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _enterPathManually();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.refresh_rounded, color: Colors.white),
                ),
                title: const Text('Pindai Otomatis (Auto-Detect)'),
                subtitle: const Text('Cari otomatis di Download, Documents, dan folder internal.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _autoDetectDataset();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Memilih file .tflite kustom dari HP
  Future<void> _pickCustomModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      final file = result?.files.single;
      if (file == null) return;

      if (!file.name.toLowerCase().endsWith('.tflite')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih file dengan format .tflite.')),
        );
        return;
      }

      File? ioFile;
      if (file.path != null) {
        ioFile = File(file.path!);
      } else if (file.bytes != null) {
        final temp = await getTemporaryDirectory();
        ioFile = File('${temp.path}/${file.name}');
        await ioFile.writeAsBytes(file.bytes!);
      }

      if (ioFile == null || !await ioFile.exists()) {
        throw StateError('File model tidak dapat dibuka.');
      }

      setState(() {
        _modelChoice = D4ModelChoiceType.customFile;
        _customModelFile = ioFile;
        _customModelName = file.name;
        _result = null;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih file TFLite: $error')),
        );
      }
    }
  }

  /// Menu pilihan model TFLite yang akan diuji
  void _showModelPickerOptions() {
    final activeVersion = _remoteConfig?.activeModelVersion ?? 'hoya_model_v1';
    final isRemote = _remoteConfig?.useRemoteModel == true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Pilih Model TFLite untuk Diuji',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.cloud_sync_outlined, color: Colors.white),
                ),
                title: Text('Model Aktif Firebase ($activeVersion)'),
                subtitle: Text(
                  isRemote
                      ? 'Model dinamis yang baru diunggah & aktif di Firebase.'
                      : 'Konfigurasi aktif saat ini (Aset bawaan).',
                ),
                trailing: _modelChoice == D4ModelChoiceType.firebaseActive
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _modelChoice = D4ModelChoiceType.firebaseActive;
                    _result = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.phone_android_outlined, color: Colors.white),
                ),
                title: const Text('Model Aset Bawaan APK (hoya_model_v1)'),
                subtitle: const Text('Model default lokal dari assets/models/hoya_model_v1.tflite.'),
                trailing: _modelChoice == D4ModelChoiceType.assetDefault
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _modelChoice = D4ModelChoiceType.assetDefault;
                    _result = null;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.file_open_outlined, color: Colors.white),
                ),
                title: Text(
                  _customModelFile != null
                      ? 'File Lokal: $_customModelName'
                      : 'Pilih File .tflite dari HP...',
                ),
                subtitle: const Text('Pilih file model .tflite kustom dari penyimpanan HP Anda.'),
                trailing: _modelChoice == D4ModelChoiceType.customFile
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCustomModelFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run() async {
    final datasetRoot = _datasetRoot;
    if (datasetRoot == null || _isRunning) return;
    if (!Platform.isAndroid) {
      setState(() => _error = 'Evaluasi ini hanya dapat dijalankan di HP Android fisik.');
      return;
    }

    setState(() {
      _isRunning = true;
      _result = null;
      _logFiles = null;
      _error = null;
      _completed = 0;
      _total = 355;
      _currentFile = null;
    });

    try {
      final evaluator = D4AccuracyEvaluationService(
        preprocessService: ref.read(imagePreprocessServiceProvider),
        tfliteService: ref.read(tfliteServiceProvider),
      );

      ClassificationConfig? targetConfig;
      File? targetCustomFile;
      String? targetModelVersion;

      switch (_modelChoice) {
        case D4ModelChoiceType.firebaseActive:
          targetConfig = _remoteConfig ??
              await ref.read(classificationConfigServiceProvider).getConfig();
          targetModelVersion = targetConfig.activeModelVersion;
          break;
        case D4ModelChoiceType.assetDefault:
          targetConfig = ClassificationConfig.fallback();
          targetModelVersion = 'hoya_model_v1';
          break;
        case D4ModelChoiceType.customFile:
          targetCustomFile = _customModelFile;
          if (targetCustomFile == null) {
            throw StateError('Pilih file .tflite kustom terlebih dahulu.');
          }
          targetModelVersion = _customModelName.replaceAll('.tflite', '');
          break;
      }

      final result = await evaluator.run(
        mobileDatasetRoot: datasetRoot,
        config: targetConfig,
        customModelFile: targetCustomFile,
        modelVersionOverride: targetModelVersion,
        onProgress: ({required completed, required total, required currentFile}) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
            _currentFile = currentFile;
          });
        },
      );

      final logs = await D4AccuracyLogStorage().save(result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _logFiles = logs;
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Evaluasi D4 gagal: $error');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  Future<void> _copyResult() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.clipboardText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ringkasan evaluasi berhasil disalin.')),
      );
    }
  }

  String _getModelDescription() {
    switch (_modelChoice) {
      case D4ModelChoiceType.firebaseActive:
        final version = _remoteConfig?.activeModelVersion ?? 'Memuat...';
        final isRemote = _remoteConfig?.useRemoteModel == true;
        return '$version (${isRemote ? 'Cloud Storage' : 'Asset'})';
      case D4ModelChoiceType.assetDefault:
        return 'hoya_model_v1 (Asset Bawaan)';
      case D4ModelChoiceType.customFile:
        return _customModelFile != null
            ? '$_customModelName (File Lokal HP)'
            : 'Belum memilih file .tflite';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uji Akurasi D4 (355 Citra)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Konfigurasi Model',
            onPressed: _isLoadingConfig ? null : _loadActiveRemoteConfig,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const _ProtocolCard(),
            const SizedBox(height: 16),
            _ModelSelector(
              modelDescription: _getModelDescription(),
              choiceType: _modelChoice,
              isLoading: _isLoadingConfig,
              isRunning: _isRunning || _isExtracting,
              onTap: _showModelPickerOptions,
            ),
            const SizedBox(height: 12),
            _DatasetSelector(
              rootPath: _datasetRoot,
              isValid: _isDatasetValid,
              isRunning: _isRunning || _isExtracting,
              onTap: _showDatasetPickerOptions,
            ),
            if (_isExtracting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                _extractingStatus,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _datasetRoot == null || _isRunning || _isExtracting ? null : _run,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _isRunning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _isRunning
                    ? 'Menguji $_completed/$_total citra...'
                    : 'Mulai Evaluasi 355 Citra D4',
              ),
            ),
            if (_isRunning) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _total == 0 ? null : _completed / _total,
              ),
              const SizedBox(height: 8),
              Text(
                _currentFile == null
                    ? 'Menyiapkan model...'
                    : 'Memproses: $_currentFile',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Biarkan aplikasi tetap terbuka sampai seluruh 355 citra selesai.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _error!),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _ResultCard(result: _result!, logFiles: _logFiles),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copyResult,
                icon: const Icon(Icons.content_copy_rounded),
                label: const Text('Salin ringkasan untuk tabel laporan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fact_check_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Evaluasi TFLite On-Device — D4',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Gunakan file ZIP mobile_d4_test.zip atau folder mobile_d4_test. Mode ini '
              'memakai model pilihan Anda dan preprocessing kanonik: EXIF transpose, '
              'RGB, resize-with-pad 224×224, nilai piksel 0–255.',
            ),
            SizedBox(height: 8),
            Text(
              'GPS, Firebase, riwayat, upload, dan pemeriksa kualitas gambar '
              'tidak dijalankan. Nilai ini khusus untuk membandingkan inferensi '
              'secara terkendali.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  final String modelDescription;
  final D4ModelChoiceType choiceType;
  final bool isLoading;
  final bool isRunning;
  final VoidCallback onTap;

  const _ModelSelector({
    required this.modelDescription,
    required this.choiceType,
    required this.isLoading,
    required this.isRunning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData getIcon() {
      switch (choiceType) {
        case D4ModelChoiceType.firebaseActive:
          return Icons.cloud_done_rounded;
        case D4ModelChoiceType.assetDefault:
          return Icons.memory_rounded;
        case D4ModelChoiceType.customFile:
          return Icons.file_present_rounded;
      }
    }

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: isRunning ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                getIcon(),
                color: colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Model TFLite yang Diuji',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLoading ? 'Memuat model aktif...' : modelDescription,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down_circle_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatasetSelector extends StatelessWidget {
  final String? rootPath;
  final bool isValid;
  final bool isRunning;
  final VoidCallback onTap;

  const _DatasetSelector({
    required this.rootPath,
    required this.isValid,
    required this.isRunning,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedPath = rootPath;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: isRunning ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isValid ? Icons.check_circle_rounded : Icons.folder_open_rounded,
                    color: isValid ? Colors.green : colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPath == null
                              ? 'Pilih Sumber Dataset D4'
                              : _lastSegment(selectedPath),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isValid
                              ? '🟢 Dataset valid (d4_test_manifest.csv & images/ siap)'
                              : '🟡 Ketuk untuk pilih ZIP, folder, atau tempel path',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isValid ? Colors.green.shade700 : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_circle_outlined),
                ],
              ),
              if (selectedPath != null) ...[
                const Divider(height: 20),
                Text(
                  'Lokasi: $selectedPath',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _lastSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.isEmpty) return 'mobile_d4_test';
    return segments.last;
  }
}

class _ResultCard extends StatelessWidget {
  final D4AccuracyEvaluationResult result;
  final D4AccuracyLogFiles? logFiles;

  const _ResultCard({required this.result, required this.logFiles});

  @override
  Widget build(BuildContext context) {
    final metrics = result.metrics;
    final isComplete = metrics.evaluatedSamples == result.expectedSamples;
    final rows = [
      _Metric('Model TFLite', '${result.modelVersion} · ${(result.modelSizeBytes / 1000000).toStringAsFixed(2)} MB'),
      _Metric('Data diproses', '${metrics.evaluatedSamples}/${result.expectedSamples} · gagal ${result.failedSamples}'),
      _Metric('Accuracy top-1', '${metrics.accuracy.toStringAsFixed(4)} (${metrics.correctTop1}/${metrics.evaluatedSamples})'),
      _Metric('Macro precision', metrics.macroPrecision.toStringAsFixed(4)),
      _Metric('Macro recall', metrics.macroRecall.toStringAsFixed(4)),
      _Metric('Macro-F1', metrics.macroF1.toStringAsFixed(4)),
      _Metric('Top-3 accuracy', '${metrics.top3Accuracy.toStringAsFixed(4)} (${metrics.correctTop3}/${metrics.evaluatedSamples})'),
      _Metric('Rata-rata preprocessing', '${result.meanPreprocessingMs.toStringAsFixed(2)} ms/citra'),
      _Metric('Rata-rata inferensi', '${result.meanInferenceMs.toStringAsFixed(2)} ms/citra'),
      _Metric('Durasi keseluruhan', '${result.elapsed.inMinutes} m ${result.elapsed.inSeconds.remainder(60)} d'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil evaluasi on-device',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            if (!isComplete)
              Text(
                'Jangan bandingkan metrik ini dengan desktop sebelum semua 355 citra berhasil diproses.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!isComplete) const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(0.92),
                1: FlexColumnWidth(1.35),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              children: [
                for (final row in rows)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          row.label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(row.value),
                      ),
                    ],
                  ),
              ],
            ),
            if (logFiles != null) ...[
              const SizedBox(height: 12),
              Text(
                'CSV: ${logFiles!.predictionsCsv.path}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'JSON: ${logFiles!.summaryJson.path}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;

  const _Metric(this.label, this.value);
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
