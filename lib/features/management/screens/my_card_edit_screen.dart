import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/business_card.dart';
import '../../wallet/screens/card_crop_screen.dart';
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
  bool _isExtracting = false;
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

  Future<void> _pickFromCamera() async {
    try {
      final ocrService = ref.read(ocrServiceProvider);
      final File? scannedImage = await ocrService.scanCardWithDocumentScanner();

      if (scannedImage != null && mounted) {
        setState(() => _newImage = scannedImage);
        await _extractText(scannedImage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('문서 스캔 실패: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1500,
      maxHeight: 1500,
      imageQuality: 70,
    );
    if (image != null && mounted) {
      final file = File(image.path);
      final cropped = await _cropImage(file);
      setState(() => _newImage = cropped);
      await _extractText(cropped);
    }
  }

  Future<File> _cropImage(File imageFile) async {
    final File? cropped = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => CardCropScreen(imageFile: imageFile)),
    );
    return cropped ?? imageFile;
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
          if (result.name != null && result.name!.isNotEmpty && _nameCtrl.text.isEmpty) {
            _nameCtrl.text = result.name!;
          }
          if (result.company != null && result.company!.isNotEmpty && _companyCtrl.text.isEmpty) {
            _companyCtrl.text = result.company!;
          }
          if (result.position != null && result.position!.isNotEmpty && _positionCtrl.text.isEmpty) {
            _positionCtrl.text = result.position!;
          }
          if (result.department != null && result.department!.isNotEmpty && _departmentCtrl.text.isEmpty) {
            _departmentCtrl.text = result.department!;
          }
          if (result.email != null && result.email!.isNotEmpty && _emailCtrl.text.isEmpty) {
            _emailCtrl.text = result.email!;
          }
          if (result.phone != null && result.phone!.isNotEmpty && _phoneCtrl.text.isEmpty) {
            _phoneCtrl.text = result.phone!;
          }
          if (result.mobile != null && result.mobile!.isNotEmpty && _mobileCtrl.text.isEmpty) {
            _mobileCtrl.text = result.mobile!;
          }
          if (result.address != null && result.address!.isNotEmpty && _addressCtrl.text.isEmpty) {
            _addressCtrl.text = result.address!;
          }
          if (result.website != null && result.website!.isNotEmpty && _websiteCtrl.text.isEmpty) {
            _websiteCtrl.text = result.website!;
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


  Future<void> _closeSheetAndStartCameraScan() async {
    Navigator.of(context).pop();

    // 바텀시트 닫힘 애니메이션 직후 스캐너를 열면
    // 일부 기기에서 화면이 잠깐 검게 보일 수 있어 한 프레임 여유를 둡니다.
    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (!mounted) return;
    await _pickFromCamera();
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
                              title: const Text('사진 촬영 (문서 스캐너)'),
                              onTap: _closeSheetAndStartCameraScan,
                            ),
                            ListTile(
                              leading:
                              const Icon(Icons.photo_library_outlined),
                              title: const Text('갤러리에서 선택'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickFromGallery();
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