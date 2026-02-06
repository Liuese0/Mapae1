import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/collected_card.dart';
import 'card_detail_screen.dart';

class CardEditScreen extends ConsumerStatefulWidget {
  final String cardId;

  const CardEditScreen({super.key, required this.cardId});

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _positionCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _faxCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _memoCtrl;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _companyCtrl = TextEditingController();
    _positionCtrl = TextEditingController();
    _departmentCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _faxCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _memoCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _positionCtrl.dispose();
    _departmentCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _faxCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  void _populateFields(CollectedCard card) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = card.name ?? '';
    _companyCtrl.text = card.company ?? '';
    _positionCtrl.text = card.position ?? '';
    _departmentCtrl.text = card.department ?? '';
    _emailCtrl.text = card.email ?? '';
    _phoneCtrl.text = card.phone ?? '';
    _mobileCtrl.text = card.mobile ?? '';
    _faxCtrl.text = card.fax ?? '';
    _addressCtrl.text = card.address ?? '';
    _websiteCtrl.text = card.website ?? '';
    _memoCtrl.text = card.memo ?? '';
  }

  Future<void> _save(CollectedCard original) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final updated = original.copyWith(
        name: _nameCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
        position: _positionCtrl.text.trim(),
        department: _departmentCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        fax: _faxCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        memo: _memoCtrl.text.trim(),
        updatedAt: DateTime.now(),
      );

      await ref.read(supabaseServiceProvider).updateCollectedCard(updated);
      ref.invalidate(cardDetailProvider(widget.cardId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(cardDetailProvider(widget.cardId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('명함 수정'),
        actions: [
          cardAsync.when(
            data: (card) {
              if (card == null) return const SizedBox.shrink();
              return TextButton(
                onPressed: _isLoading ? null : () => _save(card),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: cardAsync.when(
        data: (card) {
          if (card == null) {
            return const Center(child: Text('명함을 찾을 수 없습니다'));
          }
          _populateFields(card);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildField('이름', _nameCtrl),
                  _buildField('회사명', _companyCtrl),
                  _buildField('직급', _positionCtrl),
                  _buildField('부서', _departmentCtrl),
                  _buildField('이메일', _emailCtrl,
                      keyboard: TextInputType.emailAddress),
                  _buildField('전화번호', _phoneCtrl,
                      keyboard: TextInputType.phone),
                  _buildField('휴대폰', _mobileCtrl,
                      keyboard: TextInputType.phone),
                  _buildField('팩스', _faxCtrl,
                      keyboard: TextInputType.phone),
                  _buildField('주소', _addressCtrl),
                  _buildField('웹사이트', _websiteCtrl,
                      keyboard: TextInputType.url),
                  _buildField('메모', _memoCtrl, maxLines: 3),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}
