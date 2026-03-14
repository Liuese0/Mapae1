import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// Azure AI Document Intelligence Read model (prebuilt-read, v4.0 GA).
/// Extracts text from business card images with Korean language support.
/// Used as the OCR layer in the hybrid pipeline (Azure OCR + Gemini NLP).
class AzureOcrService {
  final Dio _dio = Dio();

  static const _apiVersion = '2024-11-30';
  static const _maxPollAttempts = 30;
  static const _pollInterval = Duration(seconds: 1);

  /// Extract text from an image file using Azure DI Read model.
  /// Returns the extracted text, or null if extraction fails.
  Future<String?> extractText(File imageFile) async {
    final endpoint = AppConstants.azureDiEndpoint;
    final key = AppConstants.azureDiKey;

    if (endpoint.isEmpty || key.isEmpty) {
      debugPrint('[AzureOCR] Endpoint or key is empty, skipping');
      return null;
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      debugPrint('[AzureOCR] Image size: ${imageBytes.length} bytes');
      final base64Image = base64Encode(imageBytes);

      // Step 1: Submit analysis request
      final analyzeUrl =
          '$endpoint/documentintelligence/documentModels/prebuilt-read:analyze?api-version=$_apiVersion';
      debugPrint('[AzureOCR] POST $analyzeUrl');

      final response = await _dio.post(
        analyzeUrl,
        data: {'base64Source': base64Image},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Ocp-Apim-Subscription-Key': key,
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 202) {
        debugPrint('[AzureOCR] Submit failed: status=${response.statusCode}, body=${response.data}');
        return null;
      }

      // Step 2: Get result URL from Operation-Location header
      final operationLocation = response.headers.value('operation-location');
      if (operationLocation == null) return null;

      // Step 3: Poll for results
      for (var i = 0; i < _maxPollAttempts; i++) {
        await Future.delayed(_pollInterval);

        final resultResponse = await _dio.get(
          operationLocation,
          options: Options(
            headers: {'Ocp-Apim-Subscription-Key': key},
          ),
        );

        final data = resultResponse.data as Map<String, dynamic>;
        final status = data['status'] as String?;

        if (status == 'succeeded') {
          return _extractTextFromResult(data);
        } else if (status == 'failed') {
          return null;
        }
        // status is 'running' or 'notStarted' — continue polling
      }

      debugPrint('[AzureOCR] Polling timed out after $_maxPollAttempts attempts');
      return null; // Timeout
    } catch (e) {
      debugPrint('[AzureOCR] Error: $e');
      return null;
    }
  }

  /// Extract concatenated text from Azure DI analysis result.
  String? _extractTextFromResult(Map<String, dynamic> data) {
    try {
      final analyzeResult = data['analyzeResult'] as Map<String, dynamic>?;
      if (analyzeResult == null) return null;

      // Get full content text (all pages concatenated)
      final content = analyzeResult['content'] as String?;
      if (content != null && content.trim().isNotEmpty) {
        return content.trim();
      }

      // Fallback: concatenate from pages
      final pages = analyzeResult['pages'] as List?;
      if (pages == null || pages.isEmpty) return null;

      final buffer = StringBuffer();
      for (final page in pages) {
        final lines = page['lines'] as List?;
        if (lines == null) continue;
        for (final line in lines) {
          final text = line['content'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            buffer.writeln(text.trim());
          }
        }
      }

      final result = buffer.toString().trim();
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }
}