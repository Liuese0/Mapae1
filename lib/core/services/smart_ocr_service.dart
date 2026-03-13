import 'dart:io';
import 'gemini_ocr_service.dart';
import 'ocr_service.dart';

/// Wrapper that tries Gemini Vision first, falling back to OCR.space + regex.
class SmartOcrService {
  final GeminiOcrService _gemini;
  final OcrService _fallback;

  SmartOcrService(this._gemini, this._fallback);

  /// Scan a business card image.
  /// Tries Gemini Vision API first (8s timeout), falls back to OCR.space.
  Future<OcrResult> scanBusinessCard(File imageFile, {String language = 'kor'}) async {
    try {
      return await _gemini
          .scanBusinessCard(imageFile)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Gemini failed — fall back to OCR.space + regex parser
      return _fallback.scanBusinessCard(imageFile, language: language);
    }
  }
}