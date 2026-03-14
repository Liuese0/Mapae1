import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import 'ocr_service.dart';

/// Business card OCR using Gemini 2.0 Flash Vision API.
/// Sends card image + optional Azure DI reference text
/// to Gemini for text extraction and field parsing.
class GeminiOcrService {
  late final GenerativeModel _model;

  GeminiOcrService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 1024,
      ),
    );
  }

  static const _basePrompt = '''
You are a world-class business card information extractor with 99.9% accuracy. Given an image of a business card, extract ALL contact information into structured JSON.

RULES:
1. Read ALL text on the card carefully, character by character. Cards contain Korean and/or English text ONLY. Do NOT attempt to read Chinese characters — any Chinese-like glyphs on Korean business cards are decorative or stylized Korean.
2. Use visual cues: person's name is usually the LARGEST text. Company name/logo is often at top or bottom. Contact details cluster together in smaller text.
3. Phone numbers: output only digits with leading + if present. Korean mobile = 010-xxxx-xxxx, Seoul office = 02-xxxx-xxxx.
4. Distinguish phone types by labels (T/Tel/전화→phone, M/Mobile/휴대폰→mobile, F/Fax/팩스→fax). Unlabeled 010 numbers are mobile.
5. Addresses: combine all parts into one string, preserve original language.
6. Websites: include full URL. Prepend "https://" if missing.
7. Omit fields not found on the card (do not include null or empty string).
8. If both Korean and English names exist, use Korean for "name".
9. In numeric contexts, interpret ambiguous characters as digits (O→0, l/I→1).
10. Split combined fields: if name and position appear together (e.g. "홍길동 부장"), separate them.
11. When reference OCR text is provided below, cross-check your readings against it. The reference text is machine-extracted and may contain errors, but use it to verify ambiguous characters — especially digits in phone numbers, email addresses, and Korean names.
12. For blurry or low-contrast text, zoom in mentally on each character. Double-check every digit in phone numbers and every character in email addresses.
13. Pay special attention to commonly confused characters: 0/O, 1/l/I, rn/m, cl/d, 가/카, 나/다.
14. IGNORE all icons, logos, decorative graphics, and small symbols (e.g. social media icons, QR codes, design elements). Only extract actual readable TEXT — do not guess text from icons or images.

OUTPUT: Return ONLY valid JSON, no markdown fencing, no explanation.
Fields: name, company, position, department, email, phone, mobile, fax, address, website, instagram

EXAMPLE:
Card: "삼성전자" top, "김민수" large, "수석연구원 AI연구소", T.02-1234-5678, M.010-9876-5432, minsu.kim@samsung.com, 서울시 강남구 삼성로 123
→ {"name":"김민수","company":"삼성전자","position":"수석연구원","department":"AI연구소","phone":"0212345678","mobile":"01098765432","email":"minsu.kim@samsung.com","address":"서울시 강남구 삼성로 123"}
''';

  /// Build prompt with optional reference text from Azure DI.
  String _buildPrompt(String? referenceText) {
    if (referenceText == null || referenceText.trim().length < 10) {
      return _basePrompt;
    }
    return '''$_basePrompt
REFERENCE OCR TEXT (from on-device recognition — use to cross-verify your readings):
"""
${referenceText.trim()}
"""
''';
  }

  /// Compress image for Gemini upload (target ~4MB).
  /// Preserves high quality for accurate text recognition.
  Future<File> _compressImage(File imageFile) async {
    final fileSize = await imageFile.length();
    if (fileSize <= 4 * 1024 * 1024) return imageFile;

    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/gemini_${DateTime.now().millisecondsSinceEpoch}.jpg';

    for (final quality in [92, 85, 75]) {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1600,
        minHeight: 1600,
      );
      if (result != null) {
        final compressed = File(result.path);
        if (await compressed.length() <= 4 * 1024 * 1024) return compressed;
      }
    }

    return imageFile; // fallback to original
  }

  /// Max retry attempts for rate-limited (429) requests.
  static const _maxRetries = 3;

  /// Scan a business card image using Gemini Vision.
  /// [referenceText] is optional ML Kit OCR text for cross-verification.
  Future<OcrResult> scanBusinessCard(File imageFile, {String? referenceText}) async {
    if (AppConstants.geminiApiKey.isEmpty) {
      throw Exception('Gemini API key not configured');
    }

    // Compress for upload if too large (4MB target, high quality)
    // Skip preprocessForOcr — Gemini Vision handles raw images well,
    // and Dart image package re-encoding destroys text quality.
    final compressed = await _compressImage(imageFile);
    final imageBytes = await compressed.readAsBytes();

    final prompt = _buildPrompt(referenceText);

    final content = Content.multi([
      TextPart(prompt),
      DataPart('image/jpeg', imageBytes),
    ]);

    // Retry with exponential backoff on 429 (rate limit)
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await _model.generateContent([content]);
        final text = response.text;

        if (text == null || text.trim().isEmpty) {
          throw Exception('Gemini returned empty response');
        }

        return _parseResponse(text);
      } catch (e) {
        final is429 = e.toString().contains('429') ||
            e.toString().contains('Too Many Requests') ||
            e.toString().contains('RESOURCE_EXHAUSTED');
        if (!is429 || attempt == _maxRetries - 1) rethrow;
        // Exponential backoff: 2s, 4s
        await Future.delayed(Duration(seconds: 2 << attempt));
      }
    }

    throw Exception('Gemini request failed after $_maxRetries retries');
  }

  /// Parse JSON response from Gemini into OcrResult.
  OcrResult _parseResponse(String responseText) {
    // Strip markdown code fences if present
    var jsonStr = responseText.trim();
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replaceAll(RegExp(r'^```\w*\n?'), '').replaceAll(RegExp(r'\n?```$'), '');
    }

    // Try direct JSON parse first
    Map<String, dynamic>? parsed;
    try {
      parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      // Try extracting JSON object from response
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (match != null) {
        try {
          parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        } catch (_) {
          throw Exception('Failed to parse Gemini response as JSON');
        }
      }
    }

    if (parsed == null) {
      throw Exception('No valid JSON in Gemini response');
    }

    String? getString(String key) {
      final v = parsed![key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    // Clean phone numbers: keep only digits and leading +
    String? cleanPhone(String? raw) {
      if (raw == null) return null;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      final prefix = trimmed.startsWith('+') ? '+' : '';
      final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
      return digits.isEmpty ? null : '$prefix$digits';
    }

    return OcrResult(
      name: getString('name'),
      company: getString('company'),
      position: getString('position'),
      department: getString('department'),
      email: getString('email'),
      phone: cleanPhone(getString('phone')),
      mobile: cleanPhone(getString('mobile')),
      fax: cleanPhone(getString('fax')),
      address: getString('address'),
      website: getString('website'),
      instagram: getString('instagram'),
      rawText: responseText,
      confidence: 0.95, // Gemini Vision is generally high confidence
    );
  }
}