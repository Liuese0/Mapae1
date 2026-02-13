import 'dart:ui' show lerpDouble;
import 'dart:math' as math;
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
  bool _quickShareMode = false;
  NfcService? _nfcService;
  _QuickShareStage _quickShareStage = _QuickShareStage.scanning;
  int _selectedPeerIndex = 0;

  static const List<_PeerCard> _nearbyPeers = [
    _PeerCard(name: '김서준', company: 'Bluewave Studio', role: 'Product Designer'),
    _PeerCard(name: '한지민', company: 'Nexio Labs', role: 'iOS Developer'),
    _PeerCard(name: '박도윤', company: 'CloudFrame', role: 'Biz Partner'),
  ];

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

  Future<void> _shareViaQuickShare() async {
    setState(() {
      _quickShareMode = true;
      _quickShareStage = _QuickShareStage.scanning;
      _selectedPeerIndex = 0;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted || !_quickShareMode) return;

    setState(() {
      _quickShareStage = _QuickShareStage.discovered;
    });
  }

  Future<void> _startExchange() async {
    setState(() {
      _quickShareStage = _QuickShareStage.exchanging;
    });

    await Future<void>.delayed(const Duration(milliseconds: 2300));
    if (!mounted || !_quickShareMode) return;

    setState(() {
      _quickShareStage = _QuickShareStage.completed;
    });
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

    if (_quickShareMode) {
      return _buildQuickShareMode(theme);
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
          const SizedBox(height: 12),

          _ShareOption(
            icon: Icons.devices,
            title: '퀵쉐어',
            subtitle: '주변 사용자를 탐지해 명함을 교환합니다',
            onTap: _shareViaQuickShare,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickShareMode(ThemeData theme) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final peer = _nearbyPeers[_selectedPeerIndex];

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 20 + bottomPadding),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '퀵쉐어',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _quickShareDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: _quickShareStage == _QuickShareStage.scanning
                  ? _buildScanningView(theme)
                  : _quickShareStage == _QuickShareStage.discovered
                      ? _buildDiscoveredView(theme)
                      : _buildExchangeView(theme, peer),
            ),
          ),
          const SizedBox(height: 12),
          if (_quickShareStage == _QuickShareStage.discovered)
            ElevatedButton(
              onPressed: _startExchange,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('명함 교환 시작'),
            )
          else if (_quickShareStage == _QuickShareStage.completed)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${peer.name}님과 명함 교환이 완료되었습니다.')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('완료'),
            )
          else
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('주변 검색 중...'),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  String get _quickShareDescription {
    switch (_quickShareStage) {
      case _QuickShareStage.scanning:
        return '주변의 앱 사용자를 탐지하고 있어요.';
      case _QuickShareStage.discovered:
        return '교환할 상대를 선택하고 명함을 교환하세요.';
      case _QuickShareStage.exchanging:
        return '서로의 명함을 원격 전송하는 중입니다.';
      case _QuickShareStage.completed:
        return '서로의 명함이 양방향으로 저장되었어요.';
    }
  }

  Widget _buildScanningView(ThemeData theme) {
    return Column(
      key: const ValueKey('scan'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withOpacity(0.08),
            ),
            child: Icon(
              Icons.radar,
              color: theme.colorScheme.primary,
              size: 54,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildDiscoveredView(ThemeData theme) {
    return Column(
      key: const ValueKey('discovered'),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '근처 사용자 ${_nearbyPeers.length}명',
            style: theme.textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _nearbyPeers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final peer = _nearbyPeers[index];
              final selected = index == _selectedPeerIndex;
              return InkWell(
                onTap: () => setState(() => _selectedPeerIndex = index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                        child: Text(peer.name.isNotEmpty ? peer.name.substring(0, 1) : '?'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(peer.name,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              '${peer.company} · ${peer.role}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeView(ThemeData theme, _PeerCard peer) {
    return _ExchangeAnimationView(
      key: ValueKey('exchange_${_quickShareStage.name}'),
      myCard: widget.card,
      peer: peer,
      done: _quickShareStage == _QuickShareStage.completed,
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

enum _QuickShareStage { scanning, discovered, exchanging, completed }

class _PeerCard {
  final String name;
  final String company;
  final String role;

  const _PeerCard({required this.name, required this.company, required this.role});
}

class _ExchangeAnimationView extends StatefulWidget {
  final BusinessCard myCard;
  final _PeerCard peer;
  final bool done;

  const _ExchangeAnimationView({
    super.key,
    required this.myCard,
    required this.peer,
    required this.done,
  });

  @override
  State<_ExchangeAnimationView> createState() => _ExchangeAnimationViewState();
}

class _ExchangeAnimationViewState extends State<_ExchangeAnimationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = widget.done ? 1.0 : _controller.value;
        final curve = Curves.easeInOut.transform(progress);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(lerpDouble(0, 74, curve)!, 0),
                    child: Transform.rotate(
                      angle: lerpDouble(0, -math.pi / 2, 1)!,
                      child: _AnimatedCardFace(
                        title: widget.myCard.name ?? '내 명함',
                        subtitle:
                            '${widget.myCard.company ?? ''} ${widget.myCard.position ?? ''}'.trim(),
                        alignRight: false,
                        color: theme.colorScheme.primary.withOpacity(0.08),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(lerpDouble(0, -74, curve)!, 0),
                    child: Transform.rotate(
                      angle: lerpDouble(0, math.pi / 2, 1)!,
                      child: _AnimatedCardFace(
                        title: widget.peer.name,
                        subtitle: '${widget.peer.company} ${widget.peer.role}',
                        alignRight: true,
                        color: theme.colorScheme.secondary.withOpacity(0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.done ? '명함 교환 완료' : '서로의 명함을 교환하는 중...',
              style: theme.textTheme.titleSmall,
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedCardFace extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool alignRight;
  final Color color;

  const _AnimatedCardFace({
    required this.title,
    required this.subtitle,
    required this.alignRight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 150,
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
          ),
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
