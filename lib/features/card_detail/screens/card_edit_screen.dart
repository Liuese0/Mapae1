import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/collected_card.dart';
import '../../shared/models/context_tag.dart';
import '../../shared/widgets/category_picker_field.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../management/screens/tag_template_screen.dart';
import 'card_detail_screen.dart';

/// 템플릿 필드 이름 → CollectedCard 필드 매핑
const _cardFieldMap = <String, String>{
  '이름': 'name',
  '회사명': 'company',
  '회사': 'company',
  '직급': 'position',
  '직함': 'position',
  '부서': 'department',
  '이메일': 'email',
  '전화번호': 'phone',
  '전화': 'phone',
  '휴대폰': 'mobile',
  '핸드폰': 'mobile',
  '팩스': 'fax',
  '주소': 'address',
  '웹사이트': 'website',
  '홈페이지': 'website',
  '메모': 'memo',
};

/// CollectedCard 필드별 키보드 타입
const _fieldKeyboard = <String, TextInputType>{
  'email': TextInputType.emailAddress,
  'phone': TextInputType.phone,
  'mobile': TextInputType.phone,
  'fax': TextInputType.phone,
  'website': TextInputType.url,
};

class CardEditScreen extends ConsumerStatefulWidget {
  final String cardId;

  const CardEditScreen({super.key, required this.cardId});

  @override
  ConsumerState<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends ConsumerState<CardEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // 기본 카드 필드 컨트롤러 (항상 존재, 템플릿 무관)
  final _cardControllers = <String, TextEditingController>{};
  static const _allCardFields = [
    'name', 'company', 'position', 'department',
    'email', 'phone', 'mobile', 'fax',
    'address', 'website', 'memo',
  ];

  bool _isLoading = false;
  bool _initialized = false;
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  // 템플릿 상태
  TagTemplate? _selectedTemplate;
  // 커스텀(비표준) 필드 컨트롤러 — 템플릿에만 있고 카드모델에 없는 필드
  final Map<String, TextEditingController> _customFieldControllers = {};
  final Map<String, bool> _customCheckValues = {};
  String? _existingTagId;
  bool _tagsLoaded = false;

  @override
  void initState() {
    super.initState();
    for (final key in _allCardFields) {
      _cardControllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final ctrl in _cardControllers.values) {
      ctrl.dispose();
    }
    for (final ctrl in _customFieldControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _populateFields(CollectedCard card) {
    if (_initialized) return;
    _initialized = true;
    _cardControllers['name']!.text = card.name ?? '';
    _cardControllers['company']!.text = card.company ?? '';
    _cardControllers['position']!.text = card.position ?? '';
    _cardControllers['department']!.text = card.department ?? '';
    _cardControllers['email']!.text = card.email ?? '';
    _cardControllers['phone']!.text = card.phone ?? '';
    _cardControllers['mobile']!.text = card.mobile ?? '';
    _cardControllers['fax']!.text = card.fax ?? '';
    _cardControllers['address']!.text = card.address ?? '';
    _cardControllers['website']!.text = card.website ?? '';
    _cardControllers['memo']!.text = card.memo ?? '';
    _selectedCategoryId = card.categoryId;
    _selectedCategoryName = card.categoryName;
    _loadExistingTag();
  }

  Future<void> _loadExistingTag() async {
    if (_tagsLoaded) return;
    _tagsLoaded = true;

    try {
      final service = ref.read(supabaseServiceProvider);
      final existingTags = await service.getCardTags(widget.cardId);
      if (existingTags.isEmpty || !mounted) return;

      final templates = await ref.read(tagTemplatesProvider.future);
      final tag = existingTags.first;
      final template =
          templates.where((t) => t.id == tag.templateId).firstOrNull;
      if (template == null) return;

      setState(() {
        _existingTagId = tag.id;
        _selectTemplate(template, tag.values);
      });
    } catch (_) {}
  }

  /// 필드 이름이 표준 카드 필드에 매핑되는지 확인
  String? _resolveCardField(String fieldName) {
    return _cardFieldMap[fieldName];
  }

  void _selectTemplate(TagTemplate template, [Map<String, dynamic>? existingCustomValues]) {
    // 기존 커스텀 컨트롤러 정리
    for (final ctrl in _customFieldControllers.values) {
      ctrl.dispose();
    }
    _customFieldControllers.clear();
    _customCheckValues.clear();

    _selectedTemplate = template;

    // 커스텀(비표준) 필드만 별도 컨트롤러 생성
    for (final field in template.fields) {
      final cardField = _resolveCardField(field.name);
      if (cardField != null) continue; // 표준 필드 → 기존 cardController 사용

      // 커스텀 필드
      if (field.type == TagFieldType.check) {
        final raw = existingCustomValues?[field.name];
        _customCheckValues[field.id] = raw == true || raw == 'true';
      } else {
        _customFieldControllers[field.id] = TextEditingController(
          text: existingCustomValues?[field.name]?.toString() ?? '',
        );
      }
    }
  }

  void _clearTemplate() {
    for (final ctrl in _customFieldControllers.values) {
      ctrl.dispose();
    }
    _customFieldControllers.clear();
    _customCheckValues.clear();
    _selectedTemplate = null;
  }

  Future<void> _save(CollectedCard original) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);

      // 항상 모든 카드 필드 저장 (템플릿에서 안 보인 필드도 기존 값 유지)
      final updated = CollectedCard(
        id: original.id,
        userId: original.userId,
        name: _cardControllers['name']!.text.trim(),
        company: _cardControllers['company']!.text.trim(),
        position: _cardControllers['position']!.text.trim(),
        department: _cardControllers['department']!.text.trim(),
        email: _cardControllers['email']!.text.trim(),
        phone: _cardControllers['phone']!.text.trim(),
        mobile: _cardControllers['mobile']!.text.trim(),
        fax: _cardControllers['fax']!.text.trim(),
        address: _cardControllers['address']!.text.trim(),
        website: _cardControllers['website']!.text.trim(),
        memo: _cardControllers['memo']!.text.trim(),
        imageUrl: original.imageUrl,
        categoryId: _selectedCategoryId,
        categoryName: _selectedCategoryName,
        sourceCardId: original.sourceCardId,
        createdAt: original.createdAt,
        updatedAt: DateTime.now(),
      );

      await service.updateCollectedCard(updated);

      // 커스텀 필드가 있으면 ContextTag로 저장
      if (_selectedTemplate != null) {
        final customValues = <String, dynamic>{};
        for (final field in _selectedTemplate!.fields) {
          if (_resolveCardField(field.name) != null) continue;
          if (field.type == TagFieldType.check) {
            customValues[field.name] = _customCheckValues[field.id] ?? false;
          } else {
            final val = _customFieldControllers[field.id]?.text.trim() ?? '';
            if (val.isNotEmpty) customValues[field.name] = val;
          }
        }

        if (customValues.isNotEmpty) {
          if (_existingTagId != null) {
            await service.updateContextTag(ContextTag(
              id: _existingTagId!,
              cardId: widget.cardId,
              templateId: _selectedTemplate!.id,
              values: customValues,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          } else {
            await service.addContextTag(ContextTag(
              id: const Uuid().v4(),
              cardId: widget.cardId,
              templateId: _selectedTemplate!.id,
              values: customValues,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          }
        } else if (_existingTagId != null) {
          await service.deleteContextTag(_existingTagId!);
        }
      } else if (_existingTagId != null) {
        await service.deleteContextTag(_existingTagId!);
      }

      ref.invalidate(cardDetailProvider(widget.cardId));
      ref.invalidate(cardTagsProvider(widget.cardId));
      ref.invalidate(categoriesProvider);
      ref.invalidate(collectedCardsProvider);

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
    final theme = Theme.of(context);
    final cardAsync = ref.watch(cardDetailProvider(widget.cardId));
    final templatesAsync = ref.watch(tagTemplatesProvider);

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

          final templates = templatesAsync.valueOrNull ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 명함 이미지
                  if (card.imageUrl != null && card.imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: card.imageUrl!,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 180,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 180,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined, size: 32),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 카테고리
                  CategoryPickerField(
                    categoryId: _selectedCategoryId,
                    categoryName: _selectedCategoryName,
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value.id;
                        _selectedCategoryName = value.name;
                      });
                    },
                  ),

                  // ── 양식 선택 드롭다운 ──
                  if (templates.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedTemplate?.id,
                        decoration: InputDecoration(
                          labelText: '입력 양식',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: Icon(
                            Icons.description_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('기본 양식',
                                style: TextStyle(fontSize: 14)),
                          ),
                          ...templates.map((t) => DropdownMenuItem<String>(
                            value: t.id,
                            child: Text(t.name,
                                style: const TextStyle(fontSize: 14)),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _clearTemplate();
                            } else {
                              final template =
                              templates.firstWhere((t) => t.id == value);
                              if (_selectedTemplate?.id == template.id) return;
                              _selectTemplate(template);
                            }
                          });
                        },
                      ),
                    ),

                  // ── 폼 필드: 기본 양식 or 템플릿 양식 ──
                  ..._buildFormFields(),

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

  /// 선택된 템플릿에 따라 폼 필드 목록 생성
  List<Widget> _buildFormFields() {
    // 템플릿 없음 → 기본 전체 필드
    if (_selectedTemplate == null) {
      return [
        _buildCardField('이름', 'name'),
        _buildCardField('회사명', 'company'),
        _buildCardField('직급', 'position'),
        _buildCardField('부서', 'department'),
        _buildCardField('이메일', 'email'),
        _buildCardField('전화번호', 'phone'),
        _buildCardField('휴대폰', 'mobile'),
        _buildCardField('팩스', 'fax'),
        _buildCardField('주소', 'address'),
        _buildCardField('웹사이트', 'website'),
        _buildCardField('메모', 'memo', maxLines: 3),
      ];
    }

    // 템플릿 선택됨 → 템플릿 필드 순서대로
    final sortedFields = [..._selectedTemplate!.fields]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return sortedFields.map((field) {
      final cardField = _resolveCardField(field.name);

      if (cardField != null) {
        // 표준 카드 필드 → 카드 컨트롤러 사용
        return _buildCardField(
          field.name,
          cardField,
          maxLines: cardField == 'memo' ? 3 : 1,
        );
      }

      // 커스텀 필드 → 타입에 따라 렌더링
      switch (field.type) {
        case TagFieldType.text:
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _customFieldControllers[field.id],
              decoration: InputDecoration(
                labelText: field.name,
                labelStyle: const TextStyle(fontSize: 13),
              ),
            ),
          );
        case TagFieldType.date:
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _customFieldControllers[field.id],
              readOnly: true,
              decoration: InputDecoration(
                labelText: field.name,
                labelStyle: const TextStyle(fontSize: 13),
                suffixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
              onTap: () async {
                final ctrl = _customFieldControllers[field.id]!;
                final now = DateTime.now();
                DateTime? initial;
                try { initial = DateTime.parse(ctrl.text); } catch (_) {}

                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial ?? now,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  ctrl.text =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                }
              },
            ),
          );
        case TagFieldType.check:
          final checked = _customCheckValues[field.id] ?? false;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CheckboxListTile(
              title: Text(field.name, style: const TextStyle(fontSize: 14)),
              value: checked,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() {
                  _customCheckValues[field.id] = value ?? false;
                });
              },
            ),
          );
      }
    }).toList();
  }

  /// 표준 카드 필드 위젯
  Widget _buildCardField(String label, String fieldKey, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _cardControllers[fieldKey],
        keyboardType: _fieldKeyboard[fieldKey] ?? TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}