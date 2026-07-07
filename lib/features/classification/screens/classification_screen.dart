import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/classification/providers/classification_provider.dart';
import 'package:hoyaid/features/classification/services/plant_filter_service.dart';
import 'package:image_picker/image_picker.dart';

class ClassificationScreen extends ConsumerStatefulWidget {
  const ClassificationScreen({super.key});

  @override
  ConsumerState<ClassificationScreen> createState() =>
      _ClassificationScreenState();
}

class _ClassificationScreenState extends ConsumerState<ClassificationScreen> {
  bool _isClassifying = false;
  String? _errorMessage;
  bool _isNotPlant = false; // true bila ML Kit mendeteksi bukan tanaman

  Future<void> _openCameraAndClassify() async {
    final image = await context.push<XFile>('/classification/camera');
    if (image == null || !mounted) return;
    await _classifyImage(image.path);
  }

  Future<void> _classifyImage(String imagePath) async {
    setState(() {
      _isClassifying = true;
      _errorMessage = null;
      _isNotPlant = false;
    });

    try {
      final draft = await ref
          .read(classificationPipelineServiceProvider)
          .classifyImage(imagePath);
      if (!mounted) return;
      await context.push('/classification/result', extra: draft);
    } on NotAPlantException {
      // ML Kit mendeteksi bukan tanaman — tampilkan panel khusus
      if (!mounted) return;
      setState(() => _isNotPlant = true);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = readableErrorMessage(
          error,
          fallback:
              'Gagal memproses gambar. Coba foto lain dengan pencahayaan lebih baik.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isClassifying = false);
    }
  }

  Future<void> _goToLogin() async {
    final user = ref.read(currentUserProvider);
    if (user?.isAnonymous == true) {
      await ref.read(authServiceProvider).signOut();
    }
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final userData = ref.watch(userDataProvider).valueOrNull;
    final isGuest = user == null || user.isAnonymous;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Klasifikasi Hoya')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.16),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              if (isGuest)
                _GuestGuard(onLogin: _goToLogin)
              else ...[
                _IntroPanel(isClassifying: _isClassifying),
                const SizedBox(height: 16),
                _QuotaPanel(userData: userData),
                const SizedBox(height: 16),
                _CapturePanel(
                  isClassifying: _isClassifying,
                  onOpenCamera: _openCameraAndClassify,
                ),
                // Panel: bukan tanaman (ML Kit filter)
                if (_isNotPlant) ...[
                  const SizedBox(height: 16),
                  _NotAPlantPanel(
                    onRetry: _openCameraAndClassify,
                  ),
                ] else if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _ErrorPanel(message: _errorMessage!),
                ],
                const SizedBox(height: 16),
                _BatchStatusPanel(isClassifying: _isClassifying),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  final bool isClassifying;

  const _IntroPanel({required this.isClassifying});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF173D2E), Color(0xFF1B7F5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isClassifying
                      ? 'Sedang membaca pola daun...'
                      : 'Siap identifikasi spesies?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gunakan foto yang terang, fokus, dan menampilkan bagian tanaman secara jelas.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: isClassifying
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                  )
                : const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }
}

class _GuestGuard extends StatelessWidget {
  final VoidCallback onLogin;

  const _GuestGuard({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded,
                  size: 42, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Masuk untuk mulai klasifikasi',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mode tamu tetap bisa melihat info spesies, tetapi hasil klasifikasi perlu akun agar bisa diproses dan disimpan.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Masuk atau Daftar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotaPanel extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const _QuotaPanel({required this.userData});

  @override
  Widget build(BuildContext context) {
    final uploadUsed = (userData?['uploadUsed'] as num?)?.toInt() ?? 0;
    final uploadLimit = (userData?['uploadLimit'] as num?)?.toInt() ?? 5;
    final isFull = uploadUsed >= uploadLimit;
    final progress = uploadLimit > 0
        ? (uploadUsed / uploadLimit).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final remaining = (uploadLimit - uploadUsed).clamp(0, uploadLimit);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isFull
                            ? Colors.orange
                            : Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(isFull
                      ? Icons.warning_rounded
                      : Icons.cloud_upload_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kuota unggah',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(isFull
                          ? 'Kuota penuh sementara'
                          : 'Tersisa $remaining kali klasifikasi'),
                    ],
                  ),
                ),
                Text('$uploadUsed/$uploadLimit',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
            if (isFull) ...[
              const SizedBox(height: 12),
              const Text(
                  'Anda masih bisa mencoba klasifikasi, tetapi penyimpanan dapat ditolak server sampai kuota tersedia.'),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapturePanel extends StatelessWidget {
  final bool isClassifying;
  final VoidCallback onOpenCamera;

  const _CapturePanel(
      {required this.isClassifying, required this.onOpenCamera});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    const Color(0xFFE8F5E9),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -18,
                    bottom: -22,
                    child: Icon(Icons.eco_rounded,
                        size: 136,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.16)),
                  ),
                  const Center(
                      child: Icon(Icons.add_a_photo_rounded, size: 56)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Ambil foto daun atau bunga Hoya',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aplikasi akan memproses gambar lokal untuk model dan menyiapkan preview yang ringan untuk disimpan.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isClassifying ? null : onOpenCamera,
              icon: isClassifying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt_rounded),
              label: Text(isClassifying ? 'Memproses...' : 'Buka Kamera'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;

  const _ErrorPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _BatchStatusPanel extends StatelessWidget {
  final bool isClassifying;

  const _BatchStatusPanel({required this.isClassifying});

  @override
  Widget build(BuildContext context) {
    const items = [
      _StatusItem(
          Icons.memory_rounded, 'Model TFLite', 'Membaca label spesies'),
      _StatusItem(
          Icons.image_rounded, 'Preprocess gambar', 'Resize 224/640 otomatis'),
      _StatusItem(Icons.place_rounded, 'Lokasi opsional',
          'Bisa ditambahkan setelah hasil'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alur proses',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final item in items)
              _StatusRow(item: item, done: !isClassifying),
          ],
        ),
      ),
    );
  }
}

class _StatusItem {
  final IconData icon;
  final String label;
  final String subtitle;

  const _StatusItem(this.icon, this.label, this.subtitle);
}

class _StatusRow extends StatelessWidget {
  final _StatusItem item;
  final bool done;

  const _StatusRow({required this.item, required this.done});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            (done ? Colors.green : Colors.orange).withValues(alpha: 0.12),
        child: Icon(item.icon, color: done ? Colors.green : Colors.orange),
      ),
      title:
          Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(item.subtitle),
      trailing: Icon(
          done ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
          color: done ? Colors.green : Colors.orange),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel: Foto bukan tanaman (ML Kit filter stage 1)
// ─────────────────────────────────────────────────────────────────────────────

class _NotAPlantPanel extends StatelessWidget {
  final VoidCallback onRetry;

  const _NotAPlantPanel({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF7B1A1A), Color(0xFFBF360C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bukan Tanaman Hoya',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Foto yang Anda kirim tidak terdeteksi sebagai tanaman.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SuggestionRow(
                  icon: Icons.eco_rounded,
                  text: 'Pastikan foto menampilkan daun, bunga, atau bagian tanaman Hoya',
                ),
                SizedBox(height: 8),
                _SuggestionRow(
                  icon: Icons.wb_sunny_rounded,
                  text: 'Gunakan pencahayaan yang cukup dan fokus pada tanaman',
                ),
                SizedBox(height: 8),
                _SuggestionRow(
                  icon: Icons.crop_free_rounded,
                  text: 'Hindari foto benda lain: botol, orang, atau latar belakang kosong',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Coba Foto Ulang'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SuggestionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
          ),
        ),
      ],
    );
  }
}
