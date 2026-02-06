import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/business_card.dart';
import 'management_screen.dart';

class MyCardEditScreen extends ConsumerStatefulWidget {
  final String? cardId;

  const MyCardEditScreen({super.key, this.cardId});

  @override
  ConsumerState<MyCardEditScreen> createState() => _MyCardEditScreenState();
}

class _MyCardEditScreenState extends ConsumerState<MyCardEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  String? _imageUrl;
  File? _newImage;
  bool _isLoading = false;
  bool _initialized = false;
  BusinessCard? _existingCard;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _positionCtrl.dispose();
    _departmentCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  void _populateFields(BusinessCard card) {
    if (_initialized) return;
    _initialized = true;
    _existingCard = card;
    _nameCtrl.text = card.name ?? '';
    _companyCtrl.text = card.company ?? '';
    _positionCtrl.text = card.position ?? '';
    _departmentCtrl.text = card.department ?? '';
    _emailCtrl.text = card.email ?? '';
    _phoneCtrl.text = card.phone ?? '';
    _mobileCtrl.text = card.mobile ?? '';
    _addressCtrl.text = card.address ?? '';
    _websiteCtrl.text = card.website ?? '';
    _imageUrl = card.imageUrl;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 90);
    if (image != null) {
      setState(() => _newImage = File(image.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final user = service.currentUser;
      if (user == null) return;

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
        name: _nameCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
        position: _positionCtrl.text.trim(),
        department: _departmentCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
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

    // Load existing card data if editing
    if (isEdit) {
      final myCards = ref.watch(myCardsManageProvider);
      myCards.whenData((cards) {
        final card = cards.where((c) => c.id == widget.cardId).firstOrNull;
        if (card != null) _populateFields(card);
      });
    }

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
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt_outlined),
                              title: const Text('사진 촬영'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading:
                                  const Icon(Icons.photo_library_outlined),
                              title: const Text('갤러리에서 선택'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
              const SizedBox(height: 24),

              _buildField('이름 *', _nameCtrl, required: true),
              _buildField('회사명', _companyCtrl),
              _buildField('직급', _positionCtrl),
              _buildField('부서', _departmentCtrl),
              _buildField('이메일', _emailCtrl,
                  keyboard: TextInputType.emailAddress),
              _buildField('전화번호', _phoneCtrl,
                  keyboard: TextInputType.phone),
              _buildField('휴대폰', _mobileCtrl,
                  keyboard: TextInputType.phone),
              _buildField('주소', _addressCtrl),
              _buildField('웹사이트', _websiteCtrl,
                  keyboard: TextInputType.url),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '필수 입력' : null
            : null,
      ),
    );
  }
}
