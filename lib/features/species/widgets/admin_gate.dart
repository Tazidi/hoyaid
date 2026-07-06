import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/auth/providers/auth_provider.dart';
import 'package:hoyaid/shared/widgets/loading_widget.dart';

class AdminGate extends ConsumerWidget {
  final Widget child;

  const AdminGate({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);

    return userDataAsync.when(
      data: (userData) {
        if (userData?['role'] == 'admin') {
          return child;
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Akses Admin')),
          body: const EmptyStateWidget(
            title: 'Akses admin diperlukan',
            subtitle: 'Akun ini tidak memiliki izin untuk mengelola data.',
            icon: Icons.lock_outline,
          ),
        );
      },
      loading: () => const Scaffold(
        body: LoadingWidget(message: 'Memeriksa akses admin...'),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Akses Admin')),
        body: EmptyStateWidget(
          title: 'Gagal memeriksa akses',
          subtitle: readableErrorMessage(
            error,
            fallback: 'Gagal membaca profil admin.',
          ),
          icon: Icons.error_outline,
        ),
      ),
    );
  }
}
