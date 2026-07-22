import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/services/account_session_manager.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userDataAsync = ref.watch(userDataProvider);
    final accountSession = ref.watch(accountSessionProvider);
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _ProfileHero(
                    name: user.displayName ??
                        (user.isAnonymous ? 'Pengguna Tamu' : 'Tanpa Nama'),
                    email: user.email ?? 'Tidak ada email (Guest)',
                    isGuest: user.isAnonymous,
                  ),
                  const SizedBox(height: 24),
                  const _ProfileSectionHeader(
                    eyebrow: 'AKUN TERSIMPAN',
                    title: 'Pilih akun aktif',
                    subtitle: 'Simpan dan pindah hingga dua akun',
                  ),
                  const SizedBox(height: 10),
                  const _AccountSwitcherCard(),
                  const SizedBox(height: 24),
                  const _ProfileSectionHeader(
                    eyebrow: 'DETAIL AKUN',
                    title: 'Informasi pribadi',
                    subtitle: 'Data yang terhubung ke akun Anda',
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 24),
                  const _ProfileSectionHeader(
                    eyebrow: 'AKTIVITAS',
                    title: 'Status & penggunaan',
                    subtitle: 'Pantau kuota identifikasi akun Anda',
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 28),
                  const _ProfileSectionHeader(
                    eyebrow: 'SESI',
                    title: 'Akses akun',
                    subtitle: 'Kelola sesi yang sedang digunakan',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await accountSession.removeActiveAccount();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(readableErrorMessage(e))),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      accountSession.accounts.length > 1
                          ? 'Keluarkan akun ini'
                          : 'Keluar Akun',
                    ),
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

class _AccountSwitcherCard extends ConsumerWidget {
  const _AccountSwitcherCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountSessionProvider);
    final accounts = session.accounts;

    if (!session.isInitialized) {
      return const _InfoCard(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return _InfoCard(
      children: [
        for (final account in accounts) ...[
          _StoredAccountTile(
            account: account,
            isActive: account.slot == session.activeSlot,
            onSelect: account.slot == session.activeSlot
                ? null
                : () => _selectAccount(context, session, account.slot),
            onRemove: () => _confirmRemove(context, session, account),
          ),
          if (account != accounts.last) const _SoftDivider(),
        ],
        if (session.canAddAccount) ...[
          const _SoftDivider(),
          ListTile(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _AddAccountSheet(),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const _TileIcon(icon: Icons.person_add_alt_1_rounded),
            title: const Text(
              'Tambahkan akun',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle:
                const Text('Masuk ke akun kedua tanpa keluar dari akun ini'),
            trailing: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ],
    );
  }

  Future<void> _selectAccount(
    BuildContext context,
    AccountSessionManager session,
    AccountSlot slot,
  ) async {
    try {
      await session.switchTo(slot);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun aktif berhasil diganti.')),
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

  Future<void> _confirmRemove(
    BuildContext context,
    AccountSessionManager session,
    StoredAccount account,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluarkan akun?'),
        content: Text(
          'Akun ${account.user.email ?? account.user.displayName ?? 'ini'} akan dikeluarkan dari perangkat. Akun Firebase tidak dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluarkan'),
          ),
        ],
      ),
    );
    if (shouldRemove != true) return;

    try {
      await session.removeAccount(account.slot);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun dikeluarkan dari perangkat.')),
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

class _StoredAccountTile extends StatelessWidget {
  final StoredAccount account;
  final bool isActive;
  final VoidCallback? onSelect;
  final VoidCallback onRemove;

  const _StoredAccountTile({
    required this.account,
    required this.isActive,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = account.user;
    final name =
        user.displayName ?? (user.isAnonymous ? 'Pengguna Tamu' : 'Tanpa Nama');
    final email =
        user.email ?? (user.isAnonymous ? 'Sesi tamu' : 'Email tidak tersedia');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return ListTile(
      onTap: onSelect,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 21,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Aktif',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            )
          else
            Icon(Icons.swap_horiz_rounded, color: colorScheme.primary),
          PopupMenuButton<String>(
            tooltip: 'Opsi akun',
            onSelected: (value) {
              if (value == 'remove') onRemove();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'remove',
                child: Text('Keluarkan dari perangkat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  const _AddAccountSheet();

  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  bool get _isBusy => _isEmailLoading || _isGoogleLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _addWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan kata sandi harus diisi.')),
      );
      return;
    }

    setState(() => _isEmailLoading = true);
    try {
      await ref.read(accountSessionProvider).addAccountWithEmail(
            email: email,
            password: password,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Akun kedua ditambahkan dan diaktifkan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(readableErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _addWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final result =
          await ref.read(accountSessionProvider).addAccountWithGoogle();
      if (result != null && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Akun kedua ditambahkan dan diaktifkan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(readableErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tambahkan akun',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Masuk ke akun kedua. Anda dapat berpindah akun tanpa keluar lagi.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email akun kedua',
                prefixIcon: Icon(Icons.email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isBusy ? null : _addWithEmail(),
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isBusy ? null : _addWithEmail,
              icon: _isEmailLoading
                  ? const _SmallAccountLoader()
                  : const Icon(Icons.login_rounded),
              label: const Text('Tambahkan & pindah akun'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _addWithGoogle,
              icon: _isGoogleLoading
                  ? const _SmallAccountLoader()
                  : const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Tambahkan dengan Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
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

class _SmallAccountLoader extends StatelessWidget {
  const _SmallAccountLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.tertiary],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -54,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 104,
            bottom: -82,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.52),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        initial,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
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
                            'PROFIL AKUN',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.76),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.86),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroStatusChip(
                      icon: isGuest
                          ? Icons.person_outline_rounded
                          : Icons.verified_rounded,
                      label: isGuest ? 'Mode tamu' : 'Akun aktif',
                    ),
                    _HeroStatusChip(
                      icon: isGuest
                          ? Icons.phone_android_rounded
                          : Icons.cloud_done_rounded,
                      label: isGuest ? 'Data lokal' : 'Tersinkron',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroStatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _ProfileSectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
