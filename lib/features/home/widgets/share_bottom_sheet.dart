import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/app_providers.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/business_card.dart';
import '../../shared/models/collected_card.dart';

class ShareBottomSheet extends ConsumerStatefulWidget {
  final BusinessCard card;

  const ShareBottomSheet({super.key, required this.card});

  @override
  ConsumerState<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends ConsumerState<ShareBottomSheet> {
  bool _quickShareMode = false;
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

  Future<void> _shareViaSns() async {
    final l10n = AppLocalizations.of(context);
    final card = widget.card;
    final text = StringBuffer('${card.name ?? ""}');
    if (card.company != null) text.write(' | ${card.company}');
    if (card.position != null) text.write(' - ${card.position}');
    if (card.email != null) text.write('\n${card.email}');
    if (card.phone != null) text.write('\n${card.phone}');
    if (card.mobile != null) text.write('\n${card.mobile}');

    try {
      final token = await _supabaseService.createSharedLink(card);
      final shareUrl =
          '${AppConstants.supabaseUrl}/functions/v1/share-redirect?token=$token';
      text.write('\n\n${l10n.shareCardContent}');
      text.write('\n$shareUrl');
    } catch (_) {
      // 링크 생성 실패 시 텍스트만 공유
    }

    Share.share(text.toString(), subject: l10n.shareCardTitle(card.name ?? ''));
    if (mounted) Navigator.of(context).pop();
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
    final l10n = AppLocalizations.of(context);
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
          SnackBar(content: Text(l10n.exchangeTimeout)),
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
    final l10n = AppLocalizations.of(context);

    if (_quickShareMode) {
      return _buildQuickShareMode(theme, l10n);
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
            l10n.shareCard,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          _ShareOption(
            icon: Icons.share_outlined,
            title: l10n.shareViaSns,
            subtitle: l10n.shareViaSnsSubtitle,
            onTap: _shareViaSns,
          ),
          const SizedBox(height: 12),
          _ShareOption(
            icon: Icons.devices,
            title: l10n.quickShare,
            subtitle: l10n.quickShareSubtitle,
            onTap: _shareViaQuickShare,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuickShareMode(ThemeData theme, AppLocalizations l10n) {
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
          Text(l10n.quickShare, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _quickShareDescription(l10n),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.65)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _quickShareStage == _QuickShareStage.scanning
                ? _buildScanningView(theme)
                : _quickShareStage == _QuickShareStage.discovered
                ? _buildDiscoveredView(theme, l10n)
                : _buildExchangeView(theme, l10n),
          ),
          const SizedBox(height: 12),
          if (_quickShareStage == _QuickShareStage.discovered)
            ElevatedButton(
              onPressed: _nearbyPeers.isEmpty ? null : _startExchange,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(l10n.startExchange),
            )
          else if (_quickShareStage == _QuickShareStage.completed)
            ElevatedButton(
              onPressed: () async {
                await _stopQuickShareSession();
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.exchangeCompleted(_exchangePeerName ?? l10n.opponent))),
                );
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(l10n.done),
            )
          else
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(l10n.scanning),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await _stopQuickShareSession();
              if (mounted) Navigator.of(context).pop();
            },
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  String _quickShareDescription(AppLocalizations l10n) {
    switch (_quickShareStage) {
      case _QuickShareStage.scanning:
        return l10n.quickShareScanningDesc;
      case _QuickShareStage.discovered:
        return l10n.quickShareDiscoveredDesc;
      case _QuickShareStage.exchanging:
        return l10n.quickShareExchangingDesc;
      case _QuickShareStage.completed:
        return l10n.quickShareCompletedDesc;
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

  Widget _buildDiscoveredView(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.nearbyUsers(_nearbyPeers.length), style: theme.textTheme.labelLarge),
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
                            Text(peer.name.isNotEmpty ? peer.name : l10n.noName,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildExchangeView(ThemeData theme, AppLocalizations l10n) {
    final peer = _nearbyPeers.isNotEmpty ? _nearbyPeers[_selectedPeerIndex] : null;
    return _ExchangeAnimationView(
      myCard: widget.card,
      peerName: peer?.name.isNotEmpty == true ? peer!.name : (_exchangePeerName ?? l10n.opponent),
      peerSubtitle: '${peer?.company ?? ''} ${peer?.position ?? ''}'.trim(),
      done: _quickShareStage == _QuickShareStage.completed,
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
      name: (json['name'] as String?) ?? '',
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
    final l10n = AppLocalizations.of(context);

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
                        title: widget.myCard.name ?? l10n.myCard,
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
            Text(
              widget.done ? l10n.cardExchangeComplete : l10n.exchangeInProgress,
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