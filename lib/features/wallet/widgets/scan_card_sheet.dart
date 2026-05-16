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
import '../../../core/services/ocr_service.dart';
import '../../../core/utils/save_to_contacts_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../shared/models/collected_card.dart';
import '../../shared/models/context_tag.dart';
import '../screens/card_crop_screen.dart';

/// 템플릿 필드 이름 → 표준 CollectedCard 필드 매핑 (커스텀 필드 판별용)
const _standardFieldNames = <String>{
  '이름', 'name', '회사명', '회사', 'company', '직급', '직함', 'position',
  '부서', 'department', '이메일', 'email', '전화번호', '전화', 'phone',
  '휴대폰', '핸드폰', 'mobile', '팩스', 'fax', '주소', 'address',
  '웹사이트', '홈페이지', 'website', '메모', 'memo',
  '인스타', '인스타그램', 'instagram', 'sns',
};

/// 템플릿 필드명 → OcrResult 표준 필드 키 매핑 (한/영 변형 포함)
const _templateFieldToStandard = <String, String>{
  '인스타': 'instagram', '인스타그램': 'instagram',
  'instagram': 'instagram', 'sns': 'instagram',
  '이름': 'name', 'name': 'name',
  '회사': 'company', '회사명': 'company', 'company': 'company',
  '직급': 'position', '직함': 'position', 'position': 'position',
  '부서': 'department', 'department': 'department',
  '이메일': 'email', 'email': 'email',
  '전화번호': 'phone', '전화': 'phone', 'phone': 'phone',
  '휴대폰': 'mobile', '핸드폰': 'mobile', 'mobile': 'mobile',
  '팩스': 'fax', 'fax': 'fax',
  '주소': 'address', 'address': 'address',
  '웹사이트': 'website', '홈페이지': 'website', 'website': 'website',
  '메모': 'memo', 'memo': 'memo',
};

/// OcrResult의 표준 필드에서 값을 조회
String? _getStandardField(OcrResult result, String key) {
  switch (key) {
    case 'name': return result.name;
    case 'company': return result.company;
    case 'position': return result.position;
    case 'department': return result.department;
    case 'email': return result.email;
    case 'phone': return result.phone;
    case 'mobile': return result.mobile;
    case 'fax': return result.fax;
    case 'address': return result.address;
    case 'website': return result.website;
    case 'instagram': return result.instagram;
    default: return null;
  }
}

class ScanCardSheet extends ConsumerStatefulWidget {
  final VoidCallback? onScanComplete;

  const ScanCardSheet({super.key, this.onScanComplete});

  @override
  ConsumerState<ScanCardSheet> createState() => _ScanCardSheetState();
}

class _ScanCardSheetState extends ConsumerState<ScanCardSheet> {
  bool _isProcessing = false;
  String _processingStatus = '';
  List<TagTemplate> _templates = [];
  TagTemplate? _selectedTemplate;
  bool _templatesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final supabaseService = ref.read(supabaseServiceProvider);
    final user = supabaseService.currentUser;
    if (user == null) return;

    final templates = await supabaseService.getTagTemplates(user.id);
    final defaultId = ref.read(defaultTemplateIdProvider);

    if (mounted) {
      setState(() {
        _templates = templates;
        _templatesLoaded = true;
        if (defaultId != null) {
          _selectedTemplate = templates.cast<TagTemplate?>().firstWhere(
                (t) => t?.id == defaultId,
            orElse: () => null,
          );
        }
      });
    }
  }

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
      // Deskew: correct tilt using Hough Line detection
      final imageProcessor = ref.read(imageProcessingServiceProvider);
      File processedFile = await imageProcessor.deskew(imageFile);

      // Compress image for upload (max ~1MB)
      _updateStatus(l10n.processingCard);
      final rawBytes = await processedFile.readAsBytes();
      debugPrint('Image size before compress: ${rawBytes.length} bytes');
      final imageBytes = await compute(_compressForUpload, rawBytes);
      debugPrint('Image size after compress: ${imageBytes.length} bytes');
      final fileName = '${const Uuid().v4()}.jpg';

      // Prepare template custom field names
      final defaultTemplate = _selectedTemplate;
      List<String>? customFieldNames;
      if (defaultTemplate != null) {
        customFieldNames = defaultTemplate.fields
            .where((f) => !_standardFieldNames.contains(f.name.toLowerCase()) &&
            !_standardFieldNames.contains(f.name))
            .map((f) => f.name)
            .toList();
        if (customFieldNames.isEmpty) customFieldNames = null;
      }

      // Run upload and OCR in parallel for speed
      _updateStatus(l10n.recognizingText);

      Future<String> uploadFuture() async {
        late String url;
        for (int attempt = 0; attempt < 3; attempt++) {
          try {
            url = await supabaseService.uploadCardImage(fileName, imageBytes);
            return url;
          } catch (e) {
            debugPrint('Upload attempt ${attempt + 1} failed: $e');
            if (attempt == 2) rethrow;
            await Future.delayed(Duration(seconds: attempt + 1));
          }
        }
        throw Exception('Upload failed');
      }

      final results = await Future.wait([
        uploadFuture(),
        ocrService.scanBusinessCard(
          processedFile,
          language: locale,
          templateFieldNames: customFieldNames,
        ),
      ]);

      final imageUrl = results[0] as String;
      final result = results[1] as OcrResult;

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

      final savedCard = await supabaseService.addCollectedCard(card);

      // Auto-create ContextTag when template is selected
      if (defaultTemplate != null && defaultTemplate.id.isNotEmpty) {
        final tagValues = <String, dynamic>{};
        for (final field in defaultTemplate.fields) {
          // extraFields에서 먼저 조회, 없으면 표준 필드 매핑에서 조회
          var extracted = result.extraFields[field.name];
          if (extracted == null) {
            final standardKey = _templateFieldToStandard[field.name] ??
                _templateFieldToStandard[field.name.toLowerCase()];
            if (standardKey != null) {
              extracted = _getStandardField(result, standardKey);
            }
          }
          if (extracted != null) {
            tagValues[field.name] = extracted;
          }
        }
        await supabaseService.addContextTag(ContextTag(
          id: const Uuid().v4(),
          cardId: savedCard.id,
          templateId: defaultTemplate.id,
          values: tagValues,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      if (mounted) {
        final l10nCurrent = AppLocalizations.of(context);
        Navigator.of(context).pop();
        widget.onScanComplete?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10nCurrent.cardAdded)),
        );

        if (!mounted) return;
        await promptSaveToContacts(context, ref, savedCard);
        if (!mounted) return;

        // Navigate to edit to review OCR results
        context.push('/card/${savedCard.id}/edit');
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
            const SizedBox(height: 16),

            // Template selector
            if (_templatesLoaded && _templates.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedTemplate?.id,
                    isExpanded: true,
                    icon: Icon(Icons.label_outlined, size: 18, color: theme.colorScheme.primary),
                    hint: Text(l10n.tagTemplate, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.defaultLabel, style: const TextStyle(fontSize: 13)),
                      ),
                      ..._templates.map((t) => DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(t.name, style: const TextStyle(fontSize: 13)),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTemplate = value == null
                            ? null
                            : _templates.firstWhere((t) => t.id == value);
                      });
                      // Save as default
                      ref.read(defaultTemplateIdProvider.notifier).setDefaultTemplateId(value);
                    },
                  ),
                ),
              ),

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