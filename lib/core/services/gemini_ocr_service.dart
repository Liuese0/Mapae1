import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import 'ocr_service.dart';

/// Business card OCR using Gemini 2.0 Flash Vision API.
/// Sends the card image directly to Gemini for text extraction and field parsing.
class GeminiOcrService {
  late final GenerativeModel _model;

  GeminiOcrService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 1024,
      ),
    );
  }

  static const _prompt = '''
You are a business card information extractor. Given an image of a business card, extract all contact information into structured JSON.

RULES:
1. Read ALL text on the card. Cards may mix Korean, English, and Chinese.
2. Use visual cues: person's name is usually the LARGEST text. Company name/logo is often at top or bottom. Contact details cluster together in smaller text.
3. Phone numbers: output only digits with leading + if present. Korean mobile = 010-xxxx-xxxx, Seoul office = 02-xxxx-xxxx.
4. Distinguish phone types by labels (T/Tel/전화→phone, M/Mobile/휴대폰→mobile, F/Fax/팩스→fax). Unlabeled 010 numbers are mobile.
5. Addresses: combine all parts into one string, preserve original language.
6. Websites: include full URL. Prepend "https://" if missing.
7. Omit fields not found on the card (do not include null or empty string).
8. If both Korean and English names exist, use Korean for "name".
9. In numeric contexts, interpret ambiguous characters as digits (O→0, l/I→1).
10. Split combined fields: if name and position appear together (e.g. "홍길동 부장"), separate them.

OUTPUT: Return ONLY valid JSON, no markdown fencing, no explanation.
Fields: name, company, position, department, email, phone, mobile, fax, address, website

EXAMPLE:
Card: "삼성전자" top, "김민수" large, "수석연구원 AI연구소", T.02-1234-5678, M.010-9876-5432, minsu.kim@samsung.com, 서울시 강남구 삼성로 123
→ {"name":"김민수","company":"삼성전자","position":"수석연구원","department":"AI연구소","phone":"0212345678","mobile":"01098765432","email":"minsu.kim@samsung.com","address":"서울시 강남구 삼성로 123"}
''';

  /// Compress image to speed up upload (target ~500KB).
  Future<File> _compressImage(File imageFile) async {
    final fileSize = await imageFile.length();
    if (fileSize <= 500 * 1024) return imageFile;

    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/gemini_${DateTime.now().millisecondsSinceEpoch}.jpg';

    for (final quality in [75, 50, 30]) {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1200,
        minHeight: 1200,
      );
      if (result != null) {
        final compressed = File(result.path);
        if (await compressed.length() <= 500 * 1024) return compressed;
      }
    }

    return imageFile; // fallback to original
  }

  /// Max retry attempts for rate-limited (429) requests.
  static const _maxRetries = 3;

  /// Scan a business card image using Gemini Vision.
  Future<OcrResult> scanBusinessCard(File imageFile) async {
    if (AppConstants.geminiApiKey.isEmpty) {
      throw Exception('Gemini API key not configured');
    }

    // Compress for faster upload
    final compressed = await _compressImage(imageFile);
    final imageBytes = await compressed.readAsBytes();

    final content = Content.multi([
      TextPart(_prompt),
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
      rawText: responseText,
      confidence: 0.95, // Gemini Vision is generally high confidence
    );
  }
}