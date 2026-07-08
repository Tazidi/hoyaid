import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userDataAsync = ref.watch(userDataProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        centerTitle: false,
      ),
      body: user == null
          ? const Center(child: Text('Tidak ada data pengguna.'))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primaryContainer.withValues(alpha: 0.42),
                    colorScheme.surface,
                  ],
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _ProfileHero(
                    name: user.displayName ??
                        (user.isAnonymous ? 'Pengguna Tamu' : 'Tanpa Nama'),
                    email: user.email ?? 'Tidak ada email (Guest)',
                    isGuest: user.isAnonymous,
                  ),
                  const SizedBox(height: 18),
                  _InfoCard(
                    children: [
                      _ProfileTile(
                        icon: Icons.person_rounded,
                        title: 'Nama Lengkap',
                        subtitle: user.displayName ??
                            (user.isAnonymous ? 'Tamu' : 'Tanpa Nama'),
                      ),
                      const _SoftDivider(),
                      _ProfileTile(
                        icon: Icons.email_rounded,
                        title: 'Email',
                        subtitle: user.email ?? 'Tidak ada email (Guest)',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  userDataAsync.when(
                    data: (userData) {
                      if (userData == null) {
                        return const _InfoCard(
                          children: [
                            _ProfileTile(
                              icon: Icons.travel_explore_rounded,
                              title: 'Mode Tamu',
                              subtitle: 'Data Anda tidak disimpan di server.',
                            ),
                          ],
                        );
                      }

                      final role = userData['role'] ?? 'user';
                      final uploadLimit = userData['uploadLimit'] ?? 0;
                      final uploadUsed = userData['uploadUsed'] ?? 0;
                      final progress = uploadLimit > 0
                          ? (uploadUsed / uploadLimit).clamp(0.0, 1.0)
                          : 0.0;

                      return _InfoCard(
                        children: [
                          if (role == 'admin') ...[
                            const _ProfileTile(
                              icon: Icons.verified_user_rounded,
                              title: 'Role Admin',
                              subtitle: 'Akses pengelolaan aplikasi aktif',
                              trailing: Chip(
                                label: Text('ADMIN'),
                                avatar: Icon(Icons.shield_rounded, size: 16),
                              ),
                            ),
                            const _SoftDivider(),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const _TileIcon(
                                        icon: Icons.cloud_upload_rounded),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Kuota Identifikasi',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$uploadUsed / $uploadLimit terpakai',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
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
                                    minHeight: 10,
                                    value: progress,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const _InfoCard(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    ),
                    error: (err, stack) => _InfoCard(
                      children: [
                        _ProfileTile(
                          icon: Icons.error_rounded,
                          title: 'Gagal memuat data pengguna',
                          subtitle: readableErrorMessage(err),
                          iconColor: colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ref.read(authServiceProvider).signOut();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(readableErrorMessage(e))),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Keluar Akun'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String email;
  final bool isGuest;

  const _ProfileHero({
    required this.name,
    required this.email,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
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
            color: colorScheme.primary.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            child: Text(
              initial,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isGuest ? 'Mode Tamu' : 'Akun Terhubung',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
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

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surface.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.58),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? iconColor;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _TileIcon(icon: icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
      trailing: trailing,
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const _TileIcon({required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: (color ?? colorScheme.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color ?? colorScheme.primary),
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 72,
      endIndent: 16,
      color:
          Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.7),
    );
  }
}
