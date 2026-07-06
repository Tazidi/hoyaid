import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final isAdmin = userData?['role'] == 'admin';
    final displayName =
        (userData?['displayName'] ?? userData?['name']) as String?;
    final menuItems = [
      _MenuItem(
        icon: Icons.camera_alt_rounded,
        label: 'Klasifikasi',
        subtitle: 'Foto Hoya sekarang',
        color: colorScheme.primary,
        onTap: () => context.push('/classification'),
      ),
      _MenuItem(
        icon: Icons.history_rounded,
        label: 'Riwayat',
        subtitle: 'Lihat hasil tersimpan',
        color: const Color(0xFF8B6F47),
        onTap: () => context.push('/history'),
      ),
      _MenuItem(
        icon: Icons.map_rounded,
        label: 'Peta Sebaran',
        subtitle: 'Jelajahi lokasi temuan',
        color: const Color(0xFF0E9F9A),
        onTap: () => context.push('/map'),
      ),
      _MenuItem(
        icon: Icons.local_florist_rounded,
        label: 'Info Spesies',
        subtitle: 'Katalog referensi Hoya',
        color: const Color(0xFFE08B2D),
        onTap: () => context.push('/species'),
      ),
      if (isAdmin)
        _MenuItem(
          icon: Icons.dashboard_customize_rounded,
          label: 'Dashboard Admin',
          subtitle: 'Pantau aktivitas aplikasi',
          color: Colors.blueGrey,
          onTap: () => context.push('/admin'),
        ),
      if (isAdmin)
        _MenuItem(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Kelola Spesies',
          subtitle: 'Tambah dan edit data',
          color: Colors.indigo,
          onTap: () => context.push('/admin/species'),
        ),
      if (isAdmin)
        _MenuItem(
          icon: Icons.account_tree_rounded,
          label: 'Label Map',
          subtitle: 'Sinkronkan label model',
          color: Colors.deepPurple,
          onTap: () => context.push('/admin/label-map'),
        ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('HoyaID'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Profil',
              icon: const Icon(Icons.person_rounded),
              onPressed: () => context.push('/profile'),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.18),
              Theme.of(context).scaffoldBackgroundColor,
              colorScheme.secondaryContainer.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _HeroHeader(name: displayName),
              const SizedBox(height: 18),
              _QuickActionCard(onTap: () => context.push('/classification')),
              const SizedBox(height: 24),
              Text(
                'Pilih aktivitas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 560;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: menuItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: isWide ? 1.18 : 0.9,
                    ),
                    itemBuilder: (context, index) =>
                        _MenuCard(item: menuItems[index]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String? name;

  const _HeroHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final greeting = name == null || name!.trim().isEmpty
        ? 'Halo, Penjelajah Hoya'
        : 'Halo, ${name!.trim()}';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B7F5A), Color(0xFF55C28B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Identifikasi, simpan, dan jelajahi sebaran spesies Hoya dengan alur yang sederhana.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const _LeafBadge(),
        ],
      ),
    );
  }
}

class _LeafBadge extends StatelessWidget {
  const _LeafBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 42),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _QuickActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child:
                    Icon(Icons.camera_alt_rounded, color: colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mulai klasifikasi cepat',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ambil foto daun atau bunga dengan panduan otomatis.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;

  const _MenuCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.icon, size: 30, color: item.color),
              ),
              const Spacer(),
              Text(
                item.label,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
