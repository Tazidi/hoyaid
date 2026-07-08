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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.22),
              colorScheme.surface,
              colorScheme.secondaryContainer.withValues(alpha: 0.42),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF12382C), Color(0xFF1F8A70), Color(0xFF6AA84F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.24),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -36,
            child: Icon(
              Icons.local_florist_rounded,
              size: 156,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isClassifying
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                    const SizedBox(width: 7),
                    Text(
                      isClassifying ? 'Memproses foto' : 'Identifikasi cepat',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isClassifying
                    ? 'Sebentar, foto sedang dianalisis.'
                    : 'Foto daun atau bunga Hoya, lalu biarkan iHoya mengenalinya.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Gunakan gambar yang terang, fokus, dan menampilkan bagian tanaman dengan jelas untuk hasil yang lebih baik.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PhotoTip(
                      icon: Icons.wb_sunny_rounded, label: 'Cahaya cukup'),
                  _PhotoTip(
                      icon: Icons.center_focus_strong_rounded,
                      label: 'Objek fokus'),
                  _PhotoTip(
                      icon: Icons.eco_rounded, label: 'Daun/bunga terlihat'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoTip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PhotoTip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final uploadUsed = (userData?['uploadUsed'] as num?)?.toInt() ?? 0;
    final uploadLimit = (userData?['uploadLimit'] as num?)?.toInt() ?? 5;
    final isFull = uploadUsed >= uploadLimit;
    final progress = uploadLimit > 0
        ? (uploadUsed / uploadLimit).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final remaining = (uploadLimit - uploadUsed).clamp(0, uploadLimit);

    return Card(
      elevation: 0,
      color: colorScheme.surface.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (isFull ? Colors.orange : colorScheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isFull ? Icons.warning_amber_rounded : Icons.bolt_rounded,
                    color: isFull ? Colors.orange : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFull
                            ? 'Kuota hampir penuh'
                            : 'Sisa $remaining kali klasifikasi',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$uploadUsed dari $uploadLimit kuota sudah digunakan',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            if (isFull) ...[
              const SizedBox(height: 12),
              Text(
                'Anda masih bisa mencoba, namun penyimpanan hasil dapat ditolak sampai kuota tersedia.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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

  const _CapturePanel({
    required this.isClassifying,
    required this.onOpenCamera,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surface.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 178,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.16),
                    colorScheme.tertiaryContainer.withValues(alpha: 0.54),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -28,
                    child: Icon(
                      Icons.eco_rounded,
                      size: 150,
                      color: colorScheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.add_a_photo_rounded,
                        size: 36,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Text(
                      'Pastikan daun atau bunga memenuhi sebagian besar frame foto.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Ambil foto tanaman Hoya',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pilih foto terbaik dari kamera. Setelah diproses, Anda bisa meninjau hasil dan menambahkan lokasi bila diperlukan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.42,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: isClassifying ? null : onOpenCamera,
              icon: isClassifying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.camera_alt_rounded),
              label: Text(isClassifying ? 'Memproses foto...' : 'Buka Kamera'),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  text:
                      'Pastikan foto menampilkan daun, bunga, atau bagian tanaman Hoya',
                ),
                SizedBox(height: 8),
                _SuggestionRow(
                  icon: Icons.wb_sunny_rounded,
                  text: 'Gunakan pencahayaan yang cukup dan fokus pada tanaman',
                ),
                SizedBox(height: 8),
                _SuggestionRow(
                  icon: Icons.crop_free_rounded,
                  text:
                      'Hindari foto benda lain: botol, orang, atau latar belakang kosong',
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
