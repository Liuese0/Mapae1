import 'dart:io';
import 'package:flutter/foundation.dart';
import 'azure_ocr_service.dart';
import 'gemini_ocr_service.dart';
import 'ocr_service.dart';

/// Multi-stage OCR pipeline:
/// 1. Azure DI Read → high-accuracy text extraction (Korean supported)
/// 2. Gemini Vision → semantic interpretation with image + reference text
/// 3. OCR.space → fallback on failure
class SmartOcrService {
  final GeminiOcrService _gemini;
  final OcrService _fallback;
  final AzureOcrService _azure;

  SmartOcrService(this._gemini, this._fallback, this._azure);

  /// Scan a business card image using the multi-stage pipeline.
  Future<OcrResult> scanBusinessCard(File imageFile, {String language = 'kor'}) async {
    try {
      // Step 1: Extract text using Azure DI Read (Korean supported, ~2-5s)
      debugPrint('[SmartOCR] Step 1: Azure DI Read starting...');
      String? referenceText;
      try {
        referenceText = await _azure
            .extractText(imageFile)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          debugPrint('[SmartOCR] Azure DI timed out after 15s');
          return null;
        });
        debugPrint('[SmartOCR] Azure DI result: ${referenceText != null ? "${referenceText.length} chars" : "null"}');
        if (referenceText != null) {
          debugPrint('[SmartOCR] Azure DI text: $referenceText');
        }
      } catch (e) {
        debugPrint('[SmartOCR] Azure DI error: $e');
      }

      // Step 2: Send image + Azure text to Gemini for field structuring
      debugPrint('[SmartOCR] Step 2: Gemini Vision starting...');
      final result = await _gemini
          .scanBusinessCard(imageFile, referenceText: referenceText)
          .timeout(const Duration(seconds: 20));
      debugPrint('[SmartOCR] Gemini result: name=${result.name}, company=${result.company}, phone=${result.phone}');
      return result;
    } catch (e) {
      debugPrint('[SmartOCR] Gemini failed: $e');
      debugPrint('[SmartOCR] Step 3: Falling back to OCR.space...');
      return _fallback.scanBusinessCard(imageFile, language: language);
    }
  }
}