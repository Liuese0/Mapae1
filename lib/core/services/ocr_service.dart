import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class OcrResult {
  final String? name;
  final String? company;
  final String? position;
  final String? department;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? fax;
  final String? address;
  final String? website;
  final String rawText;

  const OcrResult({
    this.name,
    this.company,
    this.position,
    this.department,
    this.email,
    this.phone,
    this.mobile,
    this.fax,
    this.address,
    this.website,
    required this.rawText,
  });
}

class OcrService {
  final Dio _dio = Dio();

  /// Scan a business card image and extract text using OCR.space API.
  /// Supports Korean, English, and Chinese.
  Future<OcrResult> scanBusinessCard(File imageFile, {String language = 'kor'}) async {
    final String ocrLang = _mapLanguage(language);

    // Engine 1 supports all languages including Korean, Chinese, etc.
    // Engine 2 only supports limited languages (mainly Latin-based).
    final String ocrEngine = (ocrLang == 'eng') ? '2' : '1';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      ),
      'language': ocrLang,
      'isOverlayRequired': 'false',
      'detectOrientation': 'true',
      'scale': 'true',
      'OCREngine': ocrEngine,
    });

    final response = await _dio.post(
      AppConstants.ocrApiUrl,
      data: formData,
      options: Options(
        headers: {
          'apikey': AppConstants.ocrApiKey,
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;

      // Check for API-level errors
      final isErrored = data['IsErroredOnProcessing'] as bool? ?? false;
      if (isErrored) {
        final errorMessage = data['ErrorMessage'] as String? ?? 'OCR processing failed';
        throw Exception(errorMessage);
      }

      final results = data['ParsedResults'] as List?;

      if (results != null && results.isNotEmpty) {
        // Check for individual result errors
        final exitCode = results[0]['FileParseExitCode'] as int?;
        if (exitCode != null && exitCode != 1) {
          final errorMsg = results[0]['ErrorMessage'] as String? ?? 'Failed to parse image';
          throw Exception(errorMsg);
        }

        final rawText = results[0]['ParsedText'] as String? ?? '';
        if (rawText.trim().isEmpty) {
          throw Exception('No text detected in image');
        }
        return _parseBusinessCardText(rawText);
      }
    }

    throw Exception('OCR request failed');
  }

  String _mapLanguage(String locale) {
    switch (locale) {
      case 'ko':
        return 'kor';
      case 'zh':
        return 'chs'; // Simplified Chinese
      case 'en':
      default:
        return 'eng';
    }
  }

  /// Parse the raw OCR text into structured business card fields.
  OcrResult _parseBusinessCardText(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? email;
    String? phone;
    String? mobile;
    String? fax;
    String? website;
    String? address;
    String? name;
    String? company;
    String? position;
    String? department;

    final List<String> unmatched = [];

    for (final line in lines) {
      // Email
      final emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
      final emailMatch = emailRegex.firstMatch(line);
      if (emailMatch != null && email == null) {
        email = emailMatch.group(0);
        continue;
      }

      // Website
      if (RegExp(r'(https?://|www\.)', caseSensitive: false).hasMatch(line) &&
          website == null) {
        website = line.replaceAll(RegExp(r'^(홈페이지|웹사이트|Web|Website|网站)[:\s]*',
            caseSensitive: false), '').trim();
        continue;
      }

      // Phone patterns
      final phoneRegex = RegExp(r'[\d\-\(\)\+\s]{7,}');
      if (phoneRegex.hasMatch(line)) {
        final cleaned = line.toLowerCase();
        if (cleaned.contains('fax') || cleaned.contains('팩스') || cleaned.contains('传真')) {
          fax = phoneRegex.firstMatch(line)?.group(0)?.trim();
        } else if (cleaned.contains('mobile') ||
            cleaned.contains('휴대') ||
            cleaned.contains('핸드폰') ||
            cleaned.contains('手机') ||
            cleaned.contains('cell')) {
          mobile = phoneRegex.firstMatch(line)?.group(0)?.trim();
        } else if (cleaned.contains('tel') ||
            cleaned.contains('전화') ||
            cleaned.contains('电话') ||
            cleaned.contains('phone')) {
          phone ??= phoneRegex.firstMatch(line)?.group(0)?.trim();
        } else {
          // Generic phone number
          if (phone == null) {
            phone = phoneRegex.firstMatch(line)?.group(0)?.trim();
          } else if (mobile == null) {
            mobile = phoneRegex.firstMatch(line)?.group(0)?.trim();
          }
        }
        continue;
      }

      // Address indicators
      if (_isAddressLine(line) && address == null) {
        address = line;
        continue;
      }

      unmatched.add(line);
    }

    // Heuristic: first unmatched line is likely the name,
    // second could be company, third could be position
    if (unmatched.isNotEmpty) {
      name = unmatched[0];
    }
    if (unmatched.length > 1) {
      company = unmatched[1];
    }
    if (unmatched.length > 2) {
      position = unmatched[2];
    }
    if (unmatched.length > 3) {
      department = unmatched[3];
    }

    return OcrResult(
      name: name,
      company: company,
      position: position,
      department: department,
      email: email,
      phone: phone,
      mobile: mobile,
      fax: fax,
      address: address,
      website: website,
      rawText: rawText,
    );
  }

  bool _isAddressLine(String line) {
    final addressKeywords = [
      // Korean
      '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
      '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
      '시', '구', '동', '로', '길', '층',
      // English
      'street', 'st.', 'ave', 'avenue', 'road', 'rd.', 'suite', 'floor',
      'building', 'bldg',
      // Chinese
      '省', '市', '区', '路', '号', '楼', '室',
    ];

    final lower = line.toLowerCase();
    return addressKeywords.any((kw) => lower.contains(kw.toLowerCase()));
  }
}