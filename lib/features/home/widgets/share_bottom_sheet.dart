import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/nfc_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../shared/models/business_card.dart';
import '../../shared/models/collected_card.dart';

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
  late final SupabaseService _supabaseService;
  bool _quickShareSessionActive = false;

  _QuickShareStage _quickShareStage = _QuickShareStage.scanning;
  List<_QuickSharePeer> _nearbyPeers = const [];
  int _selectedPeerIndex = 0;
  Timer? _sessionHeartbeatTimer;
  Timer? _quickSharePollTimer;
  String? _exchangePeerName;
  final Set<String> _handledIncomingIds = <String>{};


  @override
  void initState() {
    super.initState();
    _supabaseService = ref.read(supabaseServiceProvider);
  }

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
      _nearbyPeers = const [];
      _exchangePeerName = null;
    });

    await _startQuickShareSession();
  }

  Future<void> _startQuickShareSession() async {
    final service = _supabaseService;

    _quickShareSessionActive = true;
    await service.upsertQuickShareSession(widget.card);
    await _pollQuickShareState();

    _sessionHeartbeatTimer?.cancel();
    _sessionHeartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_quickShareSessionActive) return;
      await service.upsertQuickShareSession(widget.card);
    });

    _quickSharePollTimer?.cancel();
    _quickSharePollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _pollQuickShareState();
    });
  }

  Future<void> _pollQuickShareState() async {
    if (!_quickShareMode || !_quickShareSessionActive || !mounted) return;

    final service = _supabaseService;
    final peerRows = await service.getActiveQuickSharePeers();
    final peers = peerRows.map(_QuickSharePeer.fromJson).toList();

    await _handleIncomingRequests();

    if (!mounted) return;
    setState(() {
      _nearbyPeers = peers;
      if (_quickShareStage == _QuickShareStage.scanning && peers.isNotEmpty) {
        _quickShareStage = _QuickShareStage.discovered;
      }
      if (peers.isEmpty && _quickShareStage == _QuickShareStage.discovered) {
        _quickShareStage = _QuickShareStage.scanning;
      }
      if (_selectedPeerIndex >= peers.length) {
        _selectedPeerIndex = 0;
      }
    });
  }

  Future<void> _handleIncomingRequests() async {
    final service = _supabaseService;
    final requests = await service.getIncomingQuickShareRequests();

    for (final request in requests) {
      final exchangeId = request['id'] as String;
      if (_handledIncomingIds.contains(exchangeId)) continue;

      _handledIncomingIds.add(exchangeId);
      final fromCardJson = Map<String, dynamic>.from(request['from_card'] as Map);
      final fromCard = BusinessCard.fromJson(fromCardJson);
      await _saveToCollected(fromCard);
      await service.respondQuickShareExchange(
        exchangeId: exchangeId,
        toCard: widget.card,
      );
    }
  }

  Future<void> _startExchange() async {
    if (_nearbyPeers.isEmpty) return;

    final peer = _nearbyPeers[_selectedPeerIndex];
    final service = _supabaseService;

    setState(() {
      _quickShareStage = _QuickShareStage.exchanging;
      _exchangePeerName = peer.name;
    });

    final exchangeId = await service.createQuickShareExchangeRequest(
      toUserId: peer.userId,
      fromCard: widget.card,
    );

    await _waitForResponse(exchangeId);
  }

  Future<void> _waitForResponse(String exchangeId) async {
    final service = _supabaseService;
    final startedAt = DateTime.now();

    while (mounted && _quickShareMode) {
      final exchange = await service.getQuickShareExchange(exchangeId);
      if (exchange == null) return;

      final status = exchange['status'] as String?;
      if (status == 'responded') {
        final toCardJson = Map<String, dynamic>.from(exchange['to_card'] as Map);
        final peerCard = BusinessCard.fromJson(toCardJson);
        await _saveToCollected(peerCard);
        await service.completeQuickShareExchange(exchangeId);

        if (!mounted) return;
        setState(() {
          _quickShareStage = _QuickShareStage.completed;
        });
        return;
      }

      if (DateTime.now().difference(startedAt) > const Duration(seconds: 20)) {
        if (!mounted) return;
        setState(() {
          _quickShareStage = _QuickShareStage.discovered;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('응답 시간이 초과되었습니다. 다시 시도해주세요.')),
        );
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
  }

  Future<void> _saveToCollected(BusinessCard remoteCard) async {
    final service = _supabaseService;
    final user = service.currentUser;
    if (user == null) return;

    await service.addCollectedCard(
      CollectedCard(
        id: '',
        userId: user.id,
        name: remoteCard.name,
        company: remoteCard.company,
        position: remoteCard.position,
        department: remoteCard.department,
        email: remoteCard.email,
        phone: remoteCard.phone,
        mobile: remoteCard.mobile,
        fax: remoteCard.fax,
        address: remoteCard.address,
        website: remoteCard.website,
        snsUrl: remoteCard.snsUrl,
        memo: remoteCard.memo,
        imageUrl: remoteCard.imageUrl,
        sourceCardId: remoteCard.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _stopQuickShareSession() async {
    if (!_quickShareSessionActive) return;
    _quickShareSessionActive = false;
    _sessionHeartbeatTimer?.cancel();
    _sessionHeartbeatTimer = null;
    _quickSharePollTimer?.cancel();
    _quickSharePollTimer = null;
    await _supabaseService.removeQuickShareSession();
  }

  @override
  void dispose() {
    if (_nfcMode) {
      _nfcService?.stopSession();
    }
    _sessionHeartbeatTimer?.cancel();
    _quickSharePollTimer?.cancel();
    if (_quickShareMode && _quickShareSessionActive) {
      _quickShareSessionActive = false;
      _supabaseService.removeQuickShareSession();
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
          _ShareOption(
            icon: Icons.share_outlined,
            title: 'SNS로 공유',
            subtitle: '카카오톡, 메시지 등',
            onTap: _shareViaSns,
          ),
          const SizedBox(height: 12),
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
            subtitle: '실시간으로 퀵쉐어 중인 사용자와 명함을 교환합니다',
            onTap: _shareViaQuickShare,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickShareMode(ThemeData theme) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

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
          Text('퀵쉐어', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _quickShareDescription,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.65)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _quickShareStage == _QuickShareStage.scanning
                ? _buildScanningView(theme)
                : _quickShareStage == _QuickShareStage.discovered
                ? _buildDiscoveredView(theme)
                : _buildExchangeView(theme),
          ),
          const SizedBox(height: 12),
          if (_quickShareStage == _QuickShareStage.discovered)
            ElevatedButton(
              onPressed: _nearbyPeers.isEmpty ? null : _startExchange,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('명함 교환 시작'),
            )
          else if (_quickShareStage == _QuickShareStage.completed)
            ElevatedButton(
              onPressed: () async {
                await _stopQuickShareSession();
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${_exchangePeerName ?? '상대'}님과 명함 교환이 완료되었습니다.')),
                );
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('완료'),
            )
          else
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('주변 검색 중...'),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await _stopQuickShareSession();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  String get _quickShareDescription {
    switch (_quickShareStage) {
      case _QuickShareStage.scanning:
        return '현재 퀵쉐어 화면을 연 사용자만 실시간으로 표시됩니다.';
      case _QuickShareStage.discovered:
        return '감지된 사용자 중 교환할 대상을 선택하세요.';
      case _QuickShareStage.exchanging:
        return '서로의 명함을 교환 중입니다.';
      case _QuickShareStage.completed:
        return '양쪽 지갑에 상대 명함이 저장되었습니다.';
    }
  }

  Widget _buildScanningView(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withOpacity(0.08),
            ),
            child: Icon(Icons.radar, color: theme.colorScheme.primary, size: 54),
          ),
        ),
        const SizedBox(height: 18),
        const CircularProgressIndicator(),
      ],
    );
  }

  Widget _buildDiscoveredView(ThemeData theme) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('근처 사용자 ${_nearbyPeers.length}명', style: theme.textTheme.labelLarge),
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
                      color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
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
                            Text(peer.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${peer.company ?? ''} · ${peer.position ?? ''}', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      if (selected) Icon(Icons.check_circle, color: theme.colorScheme.primary),
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

  Widget _buildExchangeView(ThemeData theme) {
    final peer = _nearbyPeers.isNotEmpty ? _nearbyPeers[_selectedPeerIndex] : null;
    return _ExchangeAnimationView(
      myCard: widget.card,
      peerName: peer?.name ?? _exchangePeerName ?? '상대',
      peerSubtitle: '${peer?.company ?? ''} ${peer?.position ?? ''}'.trim(),
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          Transform.rotate(
            angle: 1.5708,
            child: Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16)],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.card.name ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  if (widget.card.company != null)
                    Text(
                      widget.card.company!,
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _nfcReady ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3), width: 2),
            ),
            child: Icon(Icons.nfc, size: 36, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            '상대방 핸드폰을 가까이 대세요',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

enum _QuickShareStage { scanning, discovered, exchanging, completed }

class _QuickSharePeer {
  final String userId;
  final String name;
  final String? company;
  final String? position;

  const _QuickSharePeer({required this.userId, required this.name, this.company, this.position});

  factory _QuickSharePeer.fromJson(Map<String, dynamic> json) {
    return _QuickSharePeer(
      userId: json['user_id'] as String,
      name: (json['name'] as String?) ?? '이름 없음',
      company: json['company'] as String?,
      position: json['position'] as String?,
    );
  }
}

class _ExchangeAnimationView extends StatefulWidget {
  final BusinessCard myCard;
  final String peerName;
  final String peerSubtitle;
  final bool done;

  const _ExchangeAnimationView({
    super.key,
    required this.myCard,
    required this.peerName,
    required this.peerSubtitle,
    required this.done,
  });

  @override
  State<_ExchangeAnimationView> createState() => _ExchangeAnimationViewState();
}

class _ExchangeAnimationViewState extends State<_ExchangeAnimationView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
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
                        subtitle: '${widget.myCard.company ?? ''} ${widget.myCard.position ?? ''}'.trim(),
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
                        title: widget.peerName,
                        subtitle: widget.peerSubtitle,
                        alignRight: true,
                        color: theme.colorScheme.secondary.withOpacity(0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.done ? '명함 교환 완료' : '서로의 명함을 교환하는 중...', style: theme.textTheme.titleSmall),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}