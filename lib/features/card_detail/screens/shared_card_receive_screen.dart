import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/business_card.dart';
import '../../shared/models/collected_card.dart';

class SharedCardReceiveScreen extends ConsumerStatefulWidget {
  final String token;

  const SharedCardReceiveScreen({super.key, required this.token});

  @override
  ConsumerState<SharedCardReceiveScreen> createState() =>
      _SharedCardReceiveScreenState();
}

class _SharedCardReceiveScreenState
    extends ConsumerState<SharedCardReceiveScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  String? _error;
  Map<String, dynamic>? _cardData;

  @override
  void initState() {
    super.initState();
    _fetchSharedCard();
  }

  Future<void> _fetchSharedCard() async {
    try {
      final service = ref.read(supabaseServiceProvider);
      final data = await service.getSharedLink(widget.token);
      if (!mounted) return;
      setState(() {
        _cardData = data;
        _loading = false;
        if (data == null) _error = '만료되었거나 존재하지 않는 공유 링크입니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '명함을 불러올 수 없습니다.';
      });
    }
  }

  Future<void> _saveToWallet() async {
    final service = ref.read(supabaseServiceProvider);
    final user = service.currentUser;
    if (user == null || _cardData == null) return;

    setState(() => _saving = true);

    try {
      await service.addCollectedCard(
        CollectedCard(
          id: '',
          userId: user.id,
          name: _cardData!['name'] as String?,
          company: _cardData!['company'] as String?,
          position: _cardData!['position'] as String?,
          department: _cardData!['department'] as String?,
          email: _cardData!['email'] as String?,
          phone: _cardData!['phone'] as String?,
          mobile: _cardData!['mobile'] as String?,
          fax: _cardData!['fax'] as String?,
          address: _cardData!['address'] as String?,
          website: _cardData!['website'] as String?,
          snsUrl: _cardData!['sns_url'] as String?,
          memo: _cardData!['memo'] as String?,
          imageUrl: _cardData!['image_url'] as String?,
          sourceCardId: _cardData!['id'] as String?,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('명함이 지갑에 저장되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('공유된 명함'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off,
                  size: 56,
                  color:
                  theme.colorScheme.onSurface.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color:
                  theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      )
          : _buildCardContent(theme),
      bottomNavigationBar: (!_loading && _error == null)
          ? SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ElevatedButton(
            onPressed: _saving || _saved ? null : _saveToWallet,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(_saved ? '저장 완료' : '내 지갑에 저장'),
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildCardContent(ThemeData theme) {
    final data = _cardData!;
    final name = data['name'] as String?;
    final company = data['company'] as String?;
    final position = data['position'] as String?;
    final department = data['department'] as String?;
    final email = data['email'] as String?;
    final phone = data['phone'] as String?;
    final mobile = data['mobile'] as String?;
    final fax = data['fax'] as String?;
    final address = data['address'] as String?;
    final website = data['website'] as String?;
    final imageUrl = data['image_url'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card image
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (imageUrl != null) const SizedBox(height: 24),

          // Header badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '공유된 명함',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Name & company
          Text(
            name ?? '이름 없음',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (company != null || position != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [company, position].where((s) => s != null).join(' · '),
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          if (department != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                department,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Contact details
          if (phone != null)
            _DetailRow(
              icon: Icons.phone_outlined,
              label: '전화',
              value: phone,
            ),
          if (mobile != null)
            _DetailRow(
              icon: Icons.smartphone_outlined,
              label: '휴대폰',
              value: mobile,
            ),
          if (fax != null)
            _DetailRow(
              icon: Icons.fax_outlined,
              label: '팩스',
              value: fax,
            ),
          if (email != null)
            _DetailRow(
              icon: Icons.email_outlined,
              label: '이메일',
              value: email,
            ),
          if (website != null)
            _DetailRow(
              icon: Icons.language,
              label: '웹사이트',
              value: website,
            ),
          if (address != null)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: '주소',
              value: address,
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}