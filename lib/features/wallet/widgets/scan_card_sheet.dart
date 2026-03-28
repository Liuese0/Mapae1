import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/collected_card.dart';
import '../screens/card_crop_screen.dart';

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
      await _processImage(scannedFile, fromDocumentScanner: true);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final imageFile = File(picked.path);

    // Show CardCropScreen for manual perspective correction
    final croppedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => CardCropScreen(imageFile: imageFile),
      ),
    );

    if (croppedFile != null && mounted) {
      await _processImage(croppedFile, fromDocumentScanner: false);
    }
  }

  void _updateStatus(String status) {
    if (mounted) setState(() => _processingStatus = status);
  }

  Future<void> _processImage(
      File imageFile, {
        bool fromDocumentScanner = false,
      }) async {
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

      await supabaseService.ensureUserProfile();
      final locale = ref.read(localeProvider).languageCode;
      final imageProcessor = ref.read(imageProcessingServiceProvider);

      // Step 1: Perspective correction (only for non-document-scanner images
      // that haven't been through CardCropScreen's perspective correction)
      File processedFile = imageFile;
      if (fromDocumentScanner) {
        // ML Kit already does perspective correction, skip it
      } else {
        // If came from CardCropScreen, perspective is already handled there
        // Just apply enhancement
      }

      // Step 2: Pro enhancement
      _updateStatus(l10n.processingCard);
      try {
        processedFile =
        await imageProcessor.enhanceCardImagePro(processedFile);
      } catch (e) {
        debugPrint('Enhancement failed, using original: $e');
      }

      // Step 3: Compress image for upload (max ~1MB)
      _updateStatus(l10n.processingCard);
      final rawBytes = await processedFile.readAsBytes();
      debugPrint('Image size before compress: ${rawBytes.length} bytes');
      final imageBytes = await compute(_compressForUpload, rawBytes);
      debugPrint('Image size after compress: ${imageBytes.length} bytes');
      final fileName = '${const Uuid().v4()}.jpg';

      // Step 4: Upload with retry
      late String imageUrl;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          imageUrl = await supabaseService.uploadCardImage(
            fileName,
            imageBytes,
          );
          break;
        } catch (e) {
          debugPrint('Upload attempt ${attempt + 1} failed: $e');
          if (attempt == 2) rethrow;
          await Future.delayed(Duration(seconds: attempt + 1));
        }
      }

      // Step 4: OCR on enhanced image
      _updateStatus(l10n.recognizingText);
      final result = await ocrService.scanBusinessCard(
        processedFile,
        language: locale,
      );

      _updateStatus(l10n.savingInfo);

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
        snsUrl: result.instagram,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Duplicate check
      final duplicates = await supabaseService.findDuplicates(
        user.id,
        email: result.email,
        phone: result.phone,
        mobile: result.mobile,
      );

      if (duplicates.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.duplicateCard),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.duplicateCardConfirm),
                const SizedBox(height: 12),
                ...duplicates.take(3).map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${d.name ?? ""} ${d.company != null ? "(${d.company})" : ""}',
                    style: const TextStyle(fontSize: 13),
                  ),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );

        if (proceed != true) {
          if (mounted) setState(() => _isProcessing = false);
          return;
        }
      }

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
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).recognitionFailed(e.toString()))),
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
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
            const SizedBox(height: 12),

            // Gallery import option
            _OptionTile(
              icon: Icons.photo_library_outlined,
              title: l10n.chooseFromGallery,
              subtitle: l10n.scanCardSubtitle,
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
                      color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compress image to max 1200px and JPEG quality 80 for reliable upload.
/// Runs in a separate isolate via compute().
Uint8List _compressForUpload(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  var image = decoded;
  const maxDim = 1200;
  if (image.width > maxDim || image.height > maxDim) {
    if (image.width > image.height) {
      image = img.copyResize(image, width: maxDim);
    } else {
      image = img.copyResize(image, height: maxDim);
    }
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}