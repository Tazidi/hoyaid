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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
      ),
      body: user == null
          ? const Center(child: Text('Tidak ada data pengguna.'))
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    user.displayName?.isNotEmpty == true
                        ? user.displayName![0].toUpperCase()
                        : '?',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Nama Lengkap'),
                  subtitle: Text(user.displayName ??
                      (user.isAnonymous ? 'Tamu' : 'Tanpa Nama')),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(user.email ?? 'Tidak ada email (Guest)'),
                ),
                const Divider(),

                // Firestore Data section
                userDataAsync.when(
                  data: (userData) {
                    if (userData == null) {
                      return const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Mode Tamu'),
                        subtitle: Text('Data Anda tidak disimpan di server.'),
                      );
                    }

                    final role = userData['role'] ?? 'user';
                    final uploadLimit = userData['uploadLimit'] ?? 0;
                    final uploadUsed = userData['uploadUsed'] ?? 0;

                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.security),
                          title: const Text('Role'),
                          subtitle: Text(role.toString().toUpperCase()),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.cloud_upload),
                          title: const Text('Kuota Identifikasi'),
                          subtitle: Text('$uploadUsed / $uploadLimit terpakai'),
                          trailing: SizedBox(
                            width: 100,
                            child: LinearProgressIndicator(
                              value:
                                  uploadLimit > 0 ? uploadUsed / uploadLimit : 0,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => ListTile(
                    leading: const Icon(Icons.error, color: Colors.red),
                    title: const Text('Gagal memuat data pengguna'),
                    subtitle: Text(readableErrorMessage(err)),
                  ),
                ),

                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ref.read(authServiceProvider).signOut();
                      // router will redirect to /login automatically via Auth Guard
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(readableErrorMessage(e))),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    'Keluar Akun',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
    );
  }
}
