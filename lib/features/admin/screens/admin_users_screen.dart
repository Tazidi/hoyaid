import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoyaid/core/utils/error_messages.dart';
import 'package:hoyaid/features/admin/models/admin_models.dart';
import 'package:hoyaid/features/admin/providers/admin_provider.dart';
import 'package:hoyaid/features/species/widgets/admin_gate.dart';
import 'package:intl/intl.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Kelola User')),
        body: ref.watch(adminUsersProvider).when(
              data: (users) {
                if (users.isEmpty) {
                  return const Center(child: Text('Belum ada user.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _UserCard(user: user);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    readableErrorMessage(
                      error,
                      fallback: 'Gagal memuat daftar user.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _UserCard extends ConsumerStatefulWidget {
  final AdminUserProfile user;

  const _UserCard({required this.user});

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  bool _isWorking = false;

  Future<void> _editLimit() async {
    final result = await showDialog<_UserLimitEdit>(
      context: context,
      builder: (context) => _EditUserLimitDialog(user: widget.user),
    );
    if (result == null) return;

    await _run(
      success: 'Quota user diperbarui.',
      action: () => ref.read(adminServiceProvider).updateUserUploadLimit(
            uid: widget.user.uid,
            uploadLimit: result.uploadLimit,
            trusted: result.trusted,
          ),
    );
  }

  Future<void> _recalculate() async {
    await _run(
      success: 'Upload used dihitung ulang.',
      action: () => ref
          .read(adminServiceProvider)
          .recalculateUserUploadUsed(widget.user.uid),
    );
  }

  Future<void> _run({
    required Future<void> Function() action,
    required String success,
  }) async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(readableErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final created = user.createdAt == null
        ? '-'
        : DateFormat('dd MMM yyyy').format(user.createdAt!);
    final progress =
        user.uploadLimit > 0 ? user.uploadUsed / user.uploadLimit : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(
                    user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(user.email.isEmpty ? user.uid : user.email),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(user.role)),
                          if (user.trusted) const Chip(label: Text('trusted')),
                          if (user.isNearQuota)
                            const Chip(label: Text('quota hampir penuh')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            const SizedBox(height: 6),
            Text('Quota: ${user.uploadUsed} / ${user.uploadLimit}'),
            Text('Dibuat: $created'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isWorking ? null : _editLimit,
                  icon: const Icon(Icons.tune),
                  label: const Text('Edit Limit'),
                ),
                OutlinedButton.icon(
                  onPressed: _isWorking ? null : _recalculate,
                  icon: _isWorking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_outlined),
                  label: const Text('Recalculate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditUserLimitDialog extends StatefulWidget {
  final AdminUserProfile user;

  const _EditUserLimitDialog({required this.user});

  @override
  State<_EditUserLimitDialog> createState() => _EditUserLimitDialogState();
}

class _EditUserLimitDialogState extends State<_EditUserLimitDialog> {
  late final TextEditingController _limitController;
  late bool _trusted;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(
      text: widget.user.uploadLimit.toString(),
    );
    _trusted = widget.user.trusted;
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Quota'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Upload limit',
              prefixIcon: Icon(Icons.cloud_upload_outlined),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _trusted,
            onChanged: (value) => setState(() => _trusted = value),
            title: const Text('Trusted contributor'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final limit = int.tryParse(_limitController.text.trim());
            if (limit == null || limit < 0) return;
            Navigator.of(context).pop(
              _UserLimitEdit(uploadLimit: limit, trusted: _trusted),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _UserLimitEdit {
  final int uploadLimit;
  final bool trusted;

  const _UserLimitEdit({
    required this.uploadLimit,
    required this.trusted,
  });
}
