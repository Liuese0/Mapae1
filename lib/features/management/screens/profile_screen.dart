import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
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
  bool _callerIdEnabled = false;
  bool _callerIdLoading = true;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).valueOrNull;
    _nameController.text = profile?.name ?? '';
    if (Platform.isAndroid) _loadCallerIdState();
  }

  Future<void> _loadCallerIdState() async {
    final service = ref.read(callerIdServiceProvider);
    final enabled = await service.isEnabled;
    if (enabled) {
      await _buildCallerIdIndex();
    }
    if (mounted) {
      setState(() {
        _callerIdEnabled = enabled;
        _callerIdLoading = false;
      });
    }
  }

  Future<void> _buildCallerIdIndex() async {
    final callerService = ref.read(callerIdServiceProvider);
    final supabaseService = ref.read(supabaseServiceProvider);
    final user = supabaseService.currentUser;
    if (user == null) return;

    final cards = await supabaseService.getCollectedCards(user.id, limit: 10000);
    callerService.buildIndex(collectedCards: cards);
  }

  Future<void> _toggleCallerId(bool value) async {
    final service = ref.read(callerIdServiceProvider);

    if (value) {
      // 오버레이 권한 요청
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        final result = await FlutterOverlayWindow.requestPermission();
        if (result != true) return;
      }
    }

    if (value) {
      await _buildCallerIdIndex();
    }
    setState(() => _callerIdEnabled = value);
    await service.setEnabled(value);
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
      _nameController.text = newName;
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

    // 수동 dispose하지 않음 — 다이얼로그 닫기 애니메이션 중 위젯 트리에서 아직 참조
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(autoLoginServiceProvider).clear();
      await ref.read(supabaseServiceProvider).deleteAccount();
      if (mounted) context.go('/login');
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
                    child: _isEditing
                        ? TextField(
                      controller: _nameController,
                      autofocus: true,
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
                    )
                        : Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Text(
                        user?.name ?? l10n.enterNameHint,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: user?.name != null
                              ? null
                              : theme.colorScheme.onSurface.withOpacity(0.4),
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
                        });
                      },
                      icon: Icon(Icons.close,
                          color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ] else
                    IconButton(
                      onPressed: () {
                        _nameController.text = user?.name ?? '';
                        setState(() => _isEditing = true);
                      },
                      icon: Icon(Icons.edit_outlined,
                          color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                ],
              ),

              // Caller ID 설정 (Android only)
              if (Platform.isAndroid) ...[
                const SizedBox(height: 28),
                Text(
                  'Caller ID',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.phone_callback_outlined,
                          size: 20,
                          color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'ko'
                              ? '수신 전화 시 명함 정보 표시'
                              : 'Show card info on incoming calls',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (_callerIdLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch(
                          value: _callerIdEnabled,
                          onChanged: _toggleCallerId,
                        ),
                    ],
                  ),
                ),
              ],

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