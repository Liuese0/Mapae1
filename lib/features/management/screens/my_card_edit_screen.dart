import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/business_card.dart';
import '../../shared/models/context_tag.dart';
import 'management_screen.dart';
import 'tag_template_screen.dart';

/// 템플릿 필드 이름 → BusinessCard 필드 매핑
const _myCardFieldMap = <String, String>{
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
  '주소': 'address',
  '웹사이트': 'website',
  '홈페이지': 'website',
};

const _myCardKeyboard = <String, TextInputType>{
  'email': TextInputType.emailAddress,
  'phone': TextInputType.phone,
  'mobile': TextInputType.phone,
  'website': TextInputType.url,
};

class MyCardEditScreen extends ConsumerStatefulWidget {
  final String? cardId;

  const MyCardEditScreen({super.key, this.cardId});

  @override
  ConsumerState<MyCardEditScreen> createState() => _MyCardEditScreenState();
}

class _MyCardEditScreenState extends ConsumerState<MyCardEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _cardControllers = <String, TextEditingController>{};
  static const _allFields = [
    'name', 'company', 'position', 'department',
    'email', 'phone', 'mobile', 'address', 'website',
  ];

  String? _imageUrl;
  File? _newImage;
  bool _isLoading = false;
  bool _isExtracting = false;
  bool _initialized = false;
  BusinessCard? _existingCard;

  // 템플릿 상태
  TagTemplate? _selectedTemplate;
  final Map<String, TextEditingController> _customFieldControllers = {};
  final Map<String, bool> _customCheckValues = {};

  @override
  void initState() {
    super.initState();
    for (final key in _allFields) {
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

  void _populateFields(BusinessCard card) {
    if (_initialized) return;
    _initialized = true;
    _existingCard = card;
    _cardControllers['name']!.text = card.name ?? '';
    _cardControllers['company']!.text = card.company ?? '';
    _cardControllers['position']!.text = card.position ?? '';
    _cardControllers['department']!.text = card.department ?? '';
    _cardControllers['email']!.text = card.email ?? '';
    _cardControllers['phone']!.text = card.phone ?? '';
    _cardControllers['mobile']!.text = card.mobile ?? '';
    _cardControllers['address']!.text = card.address ?? '';
    _cardControllers['website']!.text = card.website ?? '';
    _imageUrl = card.imageUrl;
  }

  String? _resolveCardField(String fieldName) {
    return _myCardFieldMap[fieldName];
  }

  void _selectTemplate(TagTemplate template) {
    for (final ctrl in _customFieldControllers.values) {
      ctrl.dispose();
    }
    _customFieldControllers.clear();
    _customCheckValues.clear();

    _selectedTemplate = template;

    for (final field in template.fields) {
      final cardField = _resolveCardField(field.name);
      if (cardField != null) continue;

      if (field.type == TagFieldType.check) {
        _customCheckValues[field.id] = false;
      } else {
        _customFieldControllers[field.id] = TextEditingController();
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

  Future<void> _scanWithDocumentScanner() async {
    final scannerService = ref.read(documentScannerServiceProvider);
    final scannedFile = await scannerService.scanDocument();
    if (scannedFile != null && mounted) {
      setState(() => _newImage = scannedFile);
      await _extractText(scannedFile);
    }
  }

  Future<void> _extractText(File imageFile) async {
    setState(() => _isExtracting = true);
    try {
      final ocrService = ref.read(ocrServiceProvider);
      final locale = ref.read(localeProvider).languageCode;
      final result = await ocrService.scanBusinessCard(
        imageFile,
        language: locale,
      );

      if (mounted) {
        setState(() {
          if (result.name != null && result.name!.isNotEmpty && _cardControllers['name']!.text.isEmpty) {
            _cardControllers['name']!.text = result.name!;
          }
          if (result.company != null && result.company!.isNotEmpty && _cardControllers['company']!.text.isEmpty) {
            _cardControllers['company']!.text = result.company!;
          }
          if (result.position != null && result.position!.isNotEmpty && _cardControllers['position']!.text.isEmpty) {
            _cardControllers['position']!.text = result.position!;
          }
          if (result.department != null && result.department!.isNotEmpty && _cardControllers['department']!.text.isEmpty) {
            _cardControllers['department']!.text = result.department!;
          }
          if (result.email != null && result.email!.isNotEmpty && _cardControllers['email']!.text.isEmpty) {
            _cardControllers['email']!.text = result.email!;
          }
          if (result.phone != null && result.phone!.isNotEmpty && _cardControllers['phone']!.text.isEmpty) {
            _cardControllers['phone']!.text = result.phone!;
          }
          if (result.mobile != null && result.mobile!.isNotEmpty && _cardControllers['mobile']!.text.isEmpty) {
            _cardControllers['mobile']!.text = result.mobile!;
          }
          if (result.address != null && result.address!.isNotEmpty && _cardControllers['address']!.text.isEmpty) {
            _cardControllers['address']!.text = result.address!;
          }
          if (result.website != null && result.website!.isNotEmpty && _cardControllers['website']!.text.isEmpty) {
            _cardControllers['website']!.text = result.website!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('텍스트 인식 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final user = service.currentUser;
      if (user == null) return;

      // users 테이블에 프로필이 없으면 자동 생성 (FK 제약조건 충족)
      await service.ensureUserProfile();

      // Upload image if new
      String? imageUrl = _imageUrl;
      if (_newImage != null) {
        final bytes = await _newImage!.readAsBytes();
        final fileName = '${const Uuid().v4()}.jpg';
        imageUrl = await service.uploadCardImage(fileName, bytes);
      }

      final now = DateTime.now();
      final card = BusinessCard(
        id: widget.cardId ?? const Uuid().v4(),
        userId: user.id,
        name: _cardControllers['name']!.text.trim(),
        company: _cardControllers['company']!.text.trim(),
        position: _cardControllers['position']!.text.trim(),
        department: _cardControllers['department']!.text.trim(),
        email: _cardControllers['email']!.text.trim(),
        phone: _cardControllers['phone']!.text.trim(),
        mobile: _cardControllers['mobile']!.text.trim(),
        address: _cardControllers['address']!.text.trim(),
        website: _cardControllers['website']!.text.trim(),
        imageUrl: imageUrl,
        createdAt: _existingCard?.createdAt ?? now,
        updatedAt: now,
      );

      if (widget.cardId != null) {
        await service.updateMyCard(card);
      } else {
        await service.createMyCard(card);
      }

      ref.invalidate(myCardsManageProvider);

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
    final isEdit = widget.cardId != null;
    final templatesAsync = ref.watch(tagTemplatesProvider);

    // Load existing card data if editing
    if (isEdit) {
      final myCards = ref.watch(myCardsManageProvider);
      myCards.whenData((cards) {
        final card = cards.where((c) => c.id == widget.cardId).firstOrNull;
        if (card != null) _populateFields(card);
      });
    }

    final templates = templatesAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(isEdit ? '내 명함 수정' : '내 명함 추가'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card image
              Center(
                child: GestureDetector(
                  onTap: _scanWithDocumentScanner,
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        style: BorderStyle.solid,
                      ),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: _newImage != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_newImage!, fit: BoxFit.cover),
                    )
                        : _imageUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 32,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '명함 이미지 추가',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isExtracting) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '명함 텍스트 인식 중...',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

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

              // ── 폼 필드 ──
              ..._buildFormFields(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    // 기본 양식
    if (_selectedTemplate == null) {
      return [
        _buildCardField('이름 *', 'name', required: true),
        _buildCardField('회사명', 'company'),
        _buildCardField('직급', 'position'),
        _buildCardField('부서', 'department'),
        _buildCardField('이메일', 'email'),
        _buildCardField('전화번호', 'phone'),
        _buildCardField('휴대폰', 'mobile'),
        _buildCardField('주소', 'address'),
        _buildCardField('웹사이트', 'website'),
      ];
    }

    // 템플릿 양식
    final sortedFields = [..._selectedTemplate!.fields]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return sortedFields.map((field) {
      final cardField = _resolveCardField(field.name);

      if (cardField != null) {
        return _buildCardField(field.name, cardField);
      }

      // 커스텀 필드
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

  Widget _buildCardField(String label, String fieldKey,
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _cardControllers[fieldKey],
        keyboardType: _myCardKeyboard[fieldKey] ?? TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '필수 입력' : null
            : null,
      ),
    );
  }
}