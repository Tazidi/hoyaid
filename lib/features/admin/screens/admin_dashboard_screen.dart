import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/admin/models/admin_models.dart';
import 'package:hoyaid/features/admin/providers/admin_provider.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/features/history/models/classification_record.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';
import 'package:hoyaid/shared/widgets/interactive.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Admin'),
          actions: [
            IconButton(
              tooltip: 'Hitung ulang ringkasan',
              onPressed: () => _recalculateStats(context, ref),
              icon: const Icon(Icons.calculate_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            ref.invalidate(adminVerificationQueueProvider);
            ref.invalidate(adminRecentClassificationsProvider);
            ref.invalidate(adminLowConfidenceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              FadeSlideIn(
                child: _AdminHeroCard(ref.watch(userDataProvider)),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: _StatsSection(statsAsync: ref.watch(adminStatsProvider)),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 160),
                child: _VerificationBreakdown(
                  statsAsync: ref.watch(adminStatsProvider),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 220),
                child: _AdminActionsGrid(
                  onUsers: () => context.push('/admin/users'),
                  onVerification: () => context.push('/admin/verification'),
                  onExport: () => context.push('/admin/export'),
                  onHistory: () => context.push('/history'),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 280),
                child: _ModelPackagePanel(
                  onOpen: () => context.push('/admin/model-upload'),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 340),
                child: _QueuePreview(
                  title: 'Menunggu Verifikasi',
                  subtitle: 'Data klasifikasi yang perlu ditinjau admin.',
                  accent: const Color(0xFFB9772A),
                  accentIcon: Icons.fact_check_outlined,
                  recordsAsync: ref.watch(adminVerificationQueueProvider),
                  emptyText: 'Belum ada data yang menunggu verifikasi.',
                  emptyIcon: Icons.verified_outlined,
                  onOpenAll: () => context.push('/admin/verification'),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: _QueuePreview(
                  title: 'Klasifikasi Terbaru',
                  subtitle: 'Aktivitas klasifikasi terbaru dari pengguna.',
                  accent: const Color(0xFF1B7F5A),
                  accentIcon: Icons.bolt_outlined,
                  recordsAsync: ref.watch(adminRecentClassificationsProvider),
                  emptyText: 'Belum ada klasifikasi aktif.',
                  emptyIcon: Icons.inbox_outlined,
                  onOpenAll: () => context.push('/history'),
                ),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                delay: const Duration(milliseconds: 460),
                child: _QueuePreview(
                  title: 'Perlu Dicek Ulang',
                  subtitle:
                      'Prediksi dengan confidence rendah untuk evaluasi kualitas.',
                  accent: const Color(0xFFC2410C),
                  accentIcon: Icons.warning_amber_rounded,
                  recordsAsync: ref.watch(adminLowConfidenceProvider),
                  emptyText: 'Tidak ada data confidence rendah.',
                  emptyIcon: Icons.check_circle_outline,
                  onOpenAll: () => context.push('/history'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recalculateStats(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adminServiceProvider).recalculateGlobalStats();
      ref.invalidate(adminStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ringkasan berhasil diperbarui.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(readableErrorMessage(error))),
        );
      }
    }
  }
}

/// Hero card yang menyapa admin berdasarkan waktu, plus indikator "live"
/// berdenyut dan waktu pembaruan relatif supaya dashboard terasa hidup.
class _AdminHeroCard extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>?> userDataAsync;

  const _AdminHeroCard(this.userDataAsync);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Selamat pagi'
        : hour < 15
            ? 'Selamat siang'
            : hour < 19
                ? 'Selamat sore'
                : 'Selamat malam';
    final adminName = userDataAsync.maybeWhen(
      data: (data) => (data?['name'] as String?)?.trim(),
      orElse: () => null,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          greeting,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(width: 8),
                        const _LivePulse(),
                        Text(
                          'Live',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      adminName == null || adminName.isEmpty
                          ? 'Pusat Kontrol iHoya'
                          : adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Pantau aktivitas aplikasi, tinjau data pengguna, dan kelola pembaruan model dari satu tempat.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.42,
                ),
          ),
        ],
      ),
    );
  }
}

/// Titik berdenyut yang menandakan data streaming real-time.
class _LivePulse extends StatefulWidget {
  const _LivePulse();

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Dua lapis: inti padat + halo melebar & memudar.
        return SizedBox(
          width: 22,
          height: 14,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Opacity(
                opacity: (1 - t) * 0.6,
                child: Transform.scale(
                  scale: 1 + t * 1.6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Header section seragam dengan judul tebal, subjudul, dan trailing opsional.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            child: trailing!,
          ),
        ],
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  final AsyncValue<AdminStats> statsAsync;

  const _StatsSection({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return statsAsync.when(
      data: (stats) {
        final updatedAt = stats.updatedAt == null
            ? 'Belum pernah dihitung'
            : 'Diperbarui ${_relativeTime(stats.updatedAt!)}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Ringkasan Aplikasi',
              subtitle: 'Gambaran umum data dan aktivitas saat ini.',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.update_rounded,
                    size: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(updatedAt),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _StatsGrid(stats: stats),
          ],
        );
      },
      loading: () => const _StatsSkeleton(),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  readableErrorMessage(
                    error,
                    fallback: 'Gagal memuat statistik admin.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AdminStats stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      children: [
        _StatCard(
          icon: Icons.people_outline,
          label: 'Pengguna Aktif',
          value: stats.activeUsers,
          sub: 'dari ${stats.totalUsers} terdaftar',
          accent: const Color(0xFF1B7F5A),
          onTap: () => context.push('/admin/users'),
        ),
        _StatCard(
          icon: Icons.image_search_outlined,
          label: 'Klasifikasi Aktif',
          value: stats.activeClassifications,
          sub: 'sedang berjalan',
          accent: const Color(0xFF0EA5E9),
          onTap: () => context.push('/history'),
        ),
        _StatCard(
          icon: Icons.inventory_2_outlined,
          label: 'Data Diarsipkan',
          value: stats.archivedClassifications,
          sub: 'arsip tersimpan',
          accent: const Color(0xFF6B7280),
        ),
        _StatCard(
          icon: Icons.grass_outlined,
          label: 'Data Spesies',
          value: stats.speciesCount,
          sub: 'spesies terdaftar',
          accent: const Color(0xFF16A34A),
          onTap: () => context.push('/admin/species'),
        ),
        _StatCard(
          icon: Icons.pending_actions_outlined,
          label: 'Menunggu Verifikasi',
          value: stats.unverifiedClassifications,
          sub: 'perlu ditinjau',
          accent: const Color(0xFFB9772A),
          onTap: () => context.push('/admin/verification'),
        ),
        _StatCard(
          icon: Icons.warning_amber_outlined,
          label: 'Confidence Rendah',
          value: stats.lowConfidenceClassifications,
          sub: 'evaluasi kualitas',
          accent: const Color(0xFFC2410C),
          onTap: () => context.push('/history'),
        ),
      ],
    );
  }
}

/// Placeholder shimmer grid saat statistik sedang dimuat, menggantikan spinner
/// polos agar layout tidak "loncat" saat data tiba.
class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Ringkasan Aplikasi',
          subtitle: 'Gambaran umum data dan aktivitas saat ini.',
          trailing: Text('Memuat…'),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: List.generate(
            6,
            (_) => const ShimmerBox(height: double.infinity),
          ),
        ),
      ],
    );
  }
}

/// Kartu statistik dengan ikon berwarna, angka yang menghitung naik (count-up),
/// dan umpan balik sentuh. Setiap kategori punya warna aksen sendiri supaya
/// grid tidak terlihat monoton.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String sub;
  final Color accent;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accent.withValues(alpha: 0.16),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: accent.withValues(alpha: 0.6),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedCountUp(
              value: value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Breakdown status verifikasi sebagai donut chart animasi (tanpa dependency
/// tambahan). Memvisualkan proporsi verified / unverified / rejected yang
/// sebelumnya hanya angka mentah.
class _VerificationBreakdown extends StatelessWidget {
  final AsyncValue<AdminStats> statsAsync;

  const _VerificationBreakdown({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return statsAsync.when(
      data: (stats) {
        final verified = stats.verifiedClassifications;
        final unverified = stats.unverifiedClassifications;
        final rejected = stats.rejectedClassifications;
        final total = verified + unverified + rejected;

        return _SectionCard(
          icon: Icons.donut_large_outlined,
          title: 'Status Verifikasi',
          accent: const Color(0xFF1B7F5A),
          trailing: Text(
            total == 0 ? 'Belum ada data' : 'Total $total',
          ),
          child: total == 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      'Belum ada data klasifikasi untuk ditinjau.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    _DonutChart(
                      segments: [
                        _DonutSegment(
                          value: verified,
                          color: const Color(0xFF1B7F5A),
                          label: 'Terverifikasi',
                        ),
                        _DonutSegment(
                          value: unverified,
                          color: const Color(0xFFB9772A),
                          label: 'Menunggu',
                        ),
                        _DonutSegment(
                          value: rejected,
                          color: const Color(0xFFD32F2F),
                          label: 'Ditolak',
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LegendRow(
                            color: const Color(0xFF1B7F5A),
                            label: 'Terverifikasi',
                            value: verified,
                            total: total,
                          ),
                          const SizedBox(height: 10),
                          _LegendRow(
                            color: const Color(0xFFB9772A),
                            label: 'Menunggu',
                            value: unverified,
                            total: total,
                          ),
                          const SizedBox(height: 10),
                          _LegendRow(
                            color: const Color(0xFFD32F2F),
                            label: 'Ditolak',
                            value: rejected,
                            total: total,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
      loading: () => const _SectionCardSkeleton(
        icon: Icons.donut_large_outlined,
        title: 'Status Verifikasi',
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            readableErrorMessage(
              error,
              fallback: 'Gagal memuat status verifikasi.',
            ),
          ),
        ),
      ),
    );
  }
}

/// Bagian donut chart yang menggambar sendiri lewat CustomPaint.
/// Garis diputar dari atas searah jarum jam dengan animasi tween 0 -> 1.
class _DonutChart extends StatefulWidget {
  final List<_DonutSegment> segments;

  const _DonutChart({required this.segments});

  @override
  State<_DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<_DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.segments.fold<double>(
      0,
      (sum, s) => sum + s.value,
    );

    return SizedBox(
      width: 104,
      height: 104,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CustomPaint(
            painter: _DonutPainter(
              segments: widget.segments,
              total: total,
              progress: _progress.value,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedCountUp(
                    value: total.round(),
                    duration: const Duration(milliseconds: 1000),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'total',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DonutSegment {
  final num value;
  final Color color;
  final String label;

  const _DonutSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double total;
  final double progress;

  _DonutPainter({
    required this.segments,
    required this.total,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    const thickness = 14.0;
    const gapAngle = 0.04; // celah tipis antar segmen

    // Track dasar.
    final trackPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - thickness / 2, trackPaint);

    if (total <= 0) return;

    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    // Mulai dari atas (-90 derajat), searah jarum jam.
    var startAngle = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = (segment.value / total) * 2 * math.pi * progress;
      final clampedSweep = math.max(0.0, sweep);
      segmentPaint.color = segment.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - thickness / 2),
        startAngle + gapAngle / 2,
        math.max(0.0, clampedSweep - gapAngle),
        false,
        segmentPaint,
      );
      startAngle += segment.value / total * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.total != total ||
      oldDelegate.segments != segments;
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final int total;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : (value / total) * 100;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Text(
          '$value (${percent.toStringAsFixed(0)}%)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _AdminActionsGrid extends StatelessWidget {
  final VoidCallback onUsers;
  final VoidCallback onVerification;
  final VoidCallback onExport;
  final VoidCallback onHistory;

  const _AdminActionsGrid({
    required this.onUsers,
    required this.onVerification,
    required this.onExport,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminAction(
        icon: Icons.people_alt_outlined,
        label: 'Pengguna',
        subtitle: 'Atur akun, role, dan kuota',
        accent: const Color(0xFF1B7F5A),
        onTap: onUsers,
      ),
      _AdminAction(
        icon: Icons.fact_check_outlined,
        label: 'Verifikasi',
        subtitle: 'Tinjau data masuk',
        accent: const Color(0xFFB9772A),
        onTap: onVerification,
      ),
      _AdminAction(
        icon: Icons.download_outlined,
        label: 'Ekspor Data',
        subtitle: 'Unduh dataset valid',
        accent: const Color(0xFF0EA5E9),
        onTap: onExport,
      ),
      _AdminAction(
        icon: Icons.manage_search_outlined,
        label: 'Riwayat',
        subtitle: 'Lihat semua klasifikasi',
        accent: const Color(0xFF7C3AED),
        onTap: onHistory,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Menu Pengelolaan',
          subtitle: 'Akses cepat untuk tugas admin harian.',
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.15,
          children: [
            for (final item in items)
              PressableScale(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: item.accent.withValues(alpha: 0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.accent.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: item.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(item.icon, size: 24, color: item.accent),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ModelPackagePanel extends StatelessWidget {
  final VoidCallback onOpen;

  const _ModelPackagePanel({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PressableScale(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.model_training_outlined,
                color: colorScheme.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paket Update Model',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kelola spesies, label map, panduan format, dan upload model dalam satu alur yang runtut.',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _QueuePreview extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData accentIcon;
  final AsyncValue<List<ClassificationRecord>> recordsAsync;
  final String emptyText;
  final IconData emptyIcon;
  final VoidCallback onOpenAll;

  const _QueuePreview({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.accentIcon,
    required this.recordsAsync,
    required this.emptyText,
    required this.emptyIcon,
    required this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(accentIcon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onOpenAll,
                child: const Text('Lihat semua'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          recordsAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return _QueueEmpty(icon: emptyIcon, text: emptyText);
              }
              return Column(
                children: [
                  for (final record in records.take(5))
                    _QueueRecordTile(record: record, accent: accent),
                ],
              );
            },
            loading: () => Column(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      ShimmerBox(width: 44, height: 44),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(height: 14),
                            SizedBox(height: 8),
                            ShimmerBox(height: 12, width: 120),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            error: (error, _) => Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    readableErrorMessage(
                      error,
                      fallback: 'Gagal memuat data ringkas.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRecordTile extends StatelessWidget {
  final ClassificationRecord record;
  final Color accent;

  const _QueueRecordTile({required this.record, required this.accent});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.push('/history/${record.classificationId}'),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _SpeciesAvatar(speciesId: record.speciesId, accent: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.speciesId.isEmpty
                        ? 'Spesies tidak diketahui'
                        : record.speciesId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _ConfidenceChip(confidence: record.confidence),
                      const SizedBox(width: 6),
                      if (record.createdAt != null)
                        Expanded(
                          child: Text(
                            _relativeTime(record.createdAt!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

/// Avatar bulat berisi inisial spesies, diberi warna aksen section supaya
/// tiap queue preview punya identitas visualnya sendiri.
class _SpeciesAvatar extends StatelessWidget {
  final String speciesId;
  final Color accent;

  const _SpeciesAvatar({required this.speciesId, required this.accent});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(speciesId);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: accent,
            ),
      ),
    );
  }

  String _initials(String value) {
    if (value.trim().isEmpty) return '?';
    final parts = value.trim().split(RegExp(r'[\s_]+'));
    if (parts.length == 1) {
      return parts[0].characters.first.toUpperCase();
    }
    return '${parts[0].characters.first}${parts[1].characters.first}'
        .toUpperCase();
  }
}

/// Chip kecil yang menampilkan persentase confidence dengan warna yang
/// mencerminkan kualitas prediksi (hijau/ambre/oranye/merah).
class _ConfidenceChip extends StatelessWidget {
  final double confidence;

  const _ConfidenceChip({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final percent = (confidence * 100).clamp(0.0, 100.0);
    final color = _colorFor(percent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${percent.toStringAsFixed(0)}%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Color _colorFor(double percent) {
    if (percent >= 80) return const Color(0xFF1B7F5A);
    if (percent >= 60) return const Color(0xFFB9772A);
    if (percent >= 40) return const Color(0xFFC2410C);
    return const Color(0xFFD32F2F);
  }
}

class _QueueEmpty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _QueueEmpty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Section card lokal: header ikon + judul dengan aksen warna, lalu konten.
/// Memakai styling sendiri (bukan SectionCard global) agar selaras dengan
/// aksen per-section di dashboard ini.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.accent,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (trailing != null)
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  child: trailing!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SectionCardSkeleton extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionCardSkeleton({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(width: 38, height: 38),
              SizedBox(width: 12),
              ShimmerBox(width: 140, height: 16),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              ShimmerBox(width: 104, height: 104),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 14),
                    SizedBox(height: 10),
                    ShimmerBox(height: 14),
                    SizedBox(height: 10),
                    ShimmerBox(height: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _AdminAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });
}

/// Waktu relatif berbahasa Indonesia: "baru saja", "5 menit lalu", dst.
String _relativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} minggu lalu';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} bulan lalu';
  return DateFormat('dd MMM yyyy').format(time);
}
