import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/collected_card.dart';

class ScanCardSheet extends ConsumerStatefulWidget {
  final VoidCallback? onScanComplete;

  const ScanCardSheet({super.key, this.onScanComplete});

  @override
  ConsumerState<ScanCardSheet> createState() => _ScanCardSheetState();
}

class _ScanCardSheetState extends ConsumerState<ScanCardSheet> {
  bool _isProcessing = false;
  String _processingStatus = '';

  Future<void> _scanWithDocumentScanner() async {
    final scannerService = ref.read(documentScannerServiceProvider);
    final scannedFile = await scannerService.scanDocument();
    if (scannedFile != null && mounted) {
      await _processImage(scannedFile);
    }
  }

  void _updateStatus(String status) {
    if (mounted) setState(() => _processingStatus = status);
  }

  Future<void> _processImage(File imageFile) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isProcessing = true;
      _processingStatus = l10n.processingCard;
    });

    try {
      final ocrService = ref.read(ocrServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);
      final user = supabaseService.currentUser;
      if (user == null) {
        throw Exception(l10n.loginRequired);
      }

      // users 테이블에 프로필이 없으면 자동 생성 (FK 제약조건 충족)
      await supabaseService.ensureUserProfile();

      // Get locale for OCR language
      final locale = ref.read(localeProvider).languageCode;

      // Perform OCR (includes preprocessing: white balance, shadow removal, contrast, sharpening)
      _updateStatus(l10n.recognizingText);
      final result = await ocrService.scanBusinessCard(
        imageFile,
        language: locale,
      );

      _updateStatus(l10n.savingInfo);

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
        final l10nCurrent = AppLocalizations.of(context);
        Navigator.of(context).pop();
        widget.onScanComplete?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10nCurrent.cardAdded)),
        );

        // Navigate to edit to review OCR results
        context.push('/card/${card.id}/edit');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).recognitionFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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

          if (_isProcessing) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _processingStatus,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
          ] else ...[
            Text(
              l10n.addCard,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Document Scanner option
            _OptionTile(
              icon: Icons.document_scanner_outlined,
              title: l10n.scanCard,
              subtitle: l10n.scanCardSubtitle,
              onTap: _scanWithDocumentScanner,
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
