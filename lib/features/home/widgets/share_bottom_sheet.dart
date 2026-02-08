import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/nfc_service.dart';
import '../../shared/models/business_card.dart';

class ShareBottomSheet extends ConsumerStatefulWidget {
  final BusinessCard card;

  const ShareBottomSheet({super.key, required this.card});

  @override
  ConsumerState<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends ConsumerState<ShareBottomSheet> {
  bool _nfcMode = false;
  bool _nfcReady = false;
  NfcService? _nfcService;

  void _shareViaSns() {
    final card = widget.card;
    final text = StringBuffer('${card.name ?? ""}');
    if (card.company != null) text.write(' | ${card.company}');
    if (card.position != null) text.write(' - ${card.position}');
    if (card.email != null) text.write('\n${card.email}');
    if (card.phone != null) text.write('\n${card.phone}');
    if (card.mobile != null) text.write('\n${card.mobile}');

    Share.share(text.toString(), subject: '명함 공유 - ${card.name ?? ""}');
    Navigator.of(context).pop();
  }

  void _shareViaNfc() {
    setState(() => _nfcMode = true);

    final nfcService = ref.read(nfcServiceProvider);
    _nfcService = nfcService;
    nfcService.sendCard(
      card: widget.card,
      onSending: () {
        setState(() => _nfcReady = true);
      },
      onSuccess: () {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('명함이 공유되었습니다.')),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _nfcMode = false;
            _nfcReady = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    if (_nfcMode) {
      _nfcService?.stopSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_nfcMode) {
      return _buildNfcMode(theme);
    }

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '명함 공유',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // SNS Share
          _ShareOption(
            icon: Icons.share_outlined,
            title: 'SNS로 공유',
            subtitle: '카카오톡, 메시지 등',
            onTap: _shareViaSns,
          ),
          const SizedBox(height: 12),

          // NFC Share
          _ShareOption(
            icon: Icons.nfc_outlined,
            title: 'NFC로 공유',
            subtitle: '핸드폰을 서로 맞대세요',
            onTap: _shareViaNfc,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNfcMode(ThemeData theme) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          // Vertical card preview
          Transform.rotate(
            angle: 1.5708, // 90 degrees
            child: Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.card.name ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.card.company != null)
                    Text(
                      widget.card.company!,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // NFC animation indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _nfcReady
                  ? theme.colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.nfc,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '상대방 핸드폰을 가까이 대세요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}