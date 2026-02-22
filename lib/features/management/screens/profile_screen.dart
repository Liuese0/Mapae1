import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../l10n/generated/app_localizations.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).valueOrNull;
    _nameController.text = profile?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(supabaseServiceProvider).updateUserName(newName);
      await ref.read(userProfileProvider.notifier).refresh();
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).nameChanged)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorMsg(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final passwordController = TextEditingController();
    String? errorText;

    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.deleteAccount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.deleteAccountWarning),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.password,
                  prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                final password = passwordController.text;
                if (password.isEmpty) {
                  setDialogState(() => errorText = l10n.enterPassword);
                  return;
                }
                try {
                  final service = ref.read(supabaseServiceProvider);
                  final email = service.currentUser?.email;
                  if (email == null) return;

                  await service.signInWithEmail(
                    email: email,
                    password: password,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (_) {
                  setDialogState(() => errorText = l10n.incorrectPassword);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.withdraw),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(autoLoginServiceProvider).clear();
      await ref.read(supabaseServiceProvider).deleteAccount();
      if (mounted) {
        // Wait for the widget tree to settle before navigating
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorMsg(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider);
    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.personalInfo),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: profile.when(
          data: (user) => ListView(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 24),
            children: [
              // Email (read-only)
              Text(
                l10n.email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                ),
                child: Text(
                  user?.email ?? '-',
                  style: theme.textTheme.bodyLarge,
                ),
              ),

              const SizedBox(height: 28),

              // Name (editable)
              Text(
                l10n.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      enabled: _isEditing,
                      decoration: InputDecoration(
                        hintText: l10n.enterNameHint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isEditing) ...[
                    IconButton(
                      onPressed: _isLoading ? null : _saveName,
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.check, color: Colors.green),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _nameController.text = user?.name ?? '';
                        });
                      },
                      icon: Icon(Icons.close,
                          color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ] else
                    IconButton(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: Icon(Icons.edit_outlined,
                          color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                ],
              ),

              const SizedBox(height: 48),
              const Divider(),
              const SizedBox(height: 24),

              // Delete account
              TextButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                ),
                child: Text(l10n.deleteAccount),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.errorMsg(e.toString()))),
        ),
      ),
    );
  }
}