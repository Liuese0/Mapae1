import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/collected_card.dart';

class ScanCardSheet extends ConsumerStatefulWidget {
  final VoidCallback? onScanComplete;

  const ScanCardSheet({super.key, this.onScanComplete});

  @override
  ConsumerState<ScanCardSheet> createState() => _ScanCardSheetState();
}

class _ScanCardSheetState extends ConsumerState<ScanCardSheet> {
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image != null) {
      await _processImage(File(image.path));
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image != null) {
      await _processImage(File(image.path));
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() => _isProcessing = true);

    try {
      final ocrService = ref.read(ocrServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);
      final user = supabaseService.currentUser;
      if (user == null) return;

      // users 테이블에 프로필이 없으면 자동 생성 (FK 제약조건 충족)
      await supabaseService.ensureUserProfile();

      // Get locale for OCR language
      final locale = ref.read(localeProvider).languageCode;

      // Perform OCR
      final result = await ocrService.scanBusinessCard(
        imageFile,
        language: locale,
      );

      // Upload image
      final imageBytes = await imageFile.readAsBytes();
      final fileName = '${const Uuid().v4()}.jpg';
      final imageUrl = await supabaseService.uploadCardImage(
        fileName,
        imageBytes,
      );

      // Create collected card
      final card = CollectedCard(
        id: const Uuid().v4(),
        userId: user.id,
        name: result.name,
        company: result.company,
        position: result.position,
        department: result.department,
        email: result.email,
        phone: result.phone,
        mobile: result.mobile,
        fax: result.fax,
        address: result.address,
        website: result.website,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await supabaseService.addCollectedCard(card);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onScanComplete?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('명함이 추가되었습니다')),
        );

        // Navigate to edit to review OCR results
        context.push('/card/${card.id}/edit');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인식 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
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

          if (_isProcessing) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '명함 인식 중...',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
          ] else ...[
            Text(
              '명함 추가',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Camera option
            _OptionTile(
              icon: Icons.camera_alt_outlined,
              title: '사진 촬영',
              subtitle: '카메라로 명함을 촬영합니다',
              onTap: _pickFromCamera,
            ),
            const SizedBox(height: 12),

            // Gallery option
            _OptionTile(
              icon: Icons.photo_library_outlined,
              title: '갤러리에서 선택',
              subtitle: '저장된 명함 이미지를 선택합니다',
              onTap: _pickFromGallery,
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
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
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
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
    );
  }
}