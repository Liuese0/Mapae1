import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import 'image_processing_service.dart';

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
  final double confidence;

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
    this.confidence = 0.0,
  });
}

class OcrService {
  final Dio _dio = Dio();
  final ImageProcessingService _imageProcessor = ImageProcessingService();

  /// Scan a business card image and extract text using OCR.space API.
  /// Supports Korean, English, and Chinese.
  static const int _maxFileSizeBytes = 1024 * 1024; // 1MB OCR.space limit

  /// Compress the image file until it fits within the OCR.space size limit.
  Future<File> _compressIfNeeded(File imageFile) async {
    var fileSize = await imageFile.length();
    if (fileSize <= _maxFileSizeBytes) return imageFile;

    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/ocr_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Progressively lower quality until under 1MB
    for (final quality in [70, 50, 30, 15]) {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1200,
        minHeight: 1200,
      );
      if (result != null) {
        final compressed = File(result.path);
        fileSize = await compressed.length();
        if (fileSize <= _maxFileSizeBytes) return compressed;
      }
    }

    throw Exception('이미지 크기를 줄일 수 없습니다. 더 작은 이미지를 사용해주세요.');
  }

  /// Lightweight preprocessing for OCR accuracy:
  /// resolution normalization and contrast stretching only.
  /// Falls back to original image on any failure or timeout.
  Future<File> _preprocessForOcr(File imageFile) async {
    try {
      return await _imageProcessor
          .preprocessForOcr(imageFile)
          .timeout(const Duration(seconds: 5), onTimeout: () => imageFile);
    } catch (_) {
      return imageFile;
    }
  }

  Future<OcrResult> scanBusinessCard(File imageFile, {String language = 'kor'}) async {
    final String ocrLang = _mapLanguage(language);

    // Engine 1 supports all languages including Korean, Chinese, etc.
    // Engine 2 only supports limited languages (mainly Latin-based).
    final String ocrEngine = (ocrLang == 'eng') ? '2' : '1';

    // Step 1: Preprocess image for OCR (white balance, shadow removal, contrast, sharpening)
    final preprocessedFile = await _preprocessForOcr(imageFile);

    // Step 2: Compress image if it exceeds OCR.space 1MB limit
    final processedFile = await _compressIfNeeded(preprocessedFile);

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        processedFile.path,
        filename: processedFile.path.split('/').last,
      ),
      'language': ocrLang,
      'isOverlayRequired': 'true',
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
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;

      // Check for API-level errors
      final isErrored = data['IsErroredOnProcessing'] as bool? ?? false;
      if (isErrored) {
        final rawError = data['ErrorMessage'];
        final errorMessage = rawError is List
            ? rawError.join(', ')
            : (rawError?.toString() ?? 'OCR processing failed');
        throw Exception(errorMessage);
      }

      final results = data['ParsedResults'] as List?;

      if (results != null && results.isNotEmpty) {
        // Check for individual result errors
        final exitCode = results[0]['FileParseExitCode'] as int?;
        if (exitCode != null && exitCode != 1) {
          final rawErrMsg = results[0]['ErrorMessage'];
          final errorMsg = rawErrMsg is List
              ? rawErrMsg.join(', ')
              : (rawErrMsg?.toString() ?? 'Failed to parse image');
          throw Exception(errorMsg);
        }

        final rawText = results[0]['ParsedText'] as String? ?? '';
        if (rawText.trim().isEmpty) {
          throw Exception('No text detected in image');
        }

        // Extract confidence if available
        final textOverlay = results[0]['TextOverlay'];
        double confidence = 0.0;
        if (textOverlay != null && textOverlay['Lines'] is List) {
          final lines = textOverlay['Lines'] as List;
          double totalConf = 0;
          int wordCount = 0;
          for (final line in lines) {
            if (line['Words'] is List) {
              for (final word in line['Words']) {
                if (word['WordConfidence'] != null) {
                  totalConf += (word['WordConfidence'] as num).toDouble();
                  wordCount++;
                }
              }
            }
          }
          if (wordCount > 0) confidence = totalConf / wordCount;
        }

        // Clean raw text: remove common OCR artifacts
        final cleanedText = _cleanOcrArtifacts(rawText);

        return _parseBusinessCardText(cleanedText, confidence: confidence);
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

  /// Clean common OCR artifacts from raw text.
  String _cleanOcrArtifacts(String rawText) {
    var cleaned = rawText;

    // Remove common OCR noise characters
    cleaned = cleaned.replaceAll(RegExp(r'[|\\{}\[\]<>~`]'), '');

    // Fix common OCR misreads
    cleaned = cleaned.replaceAll(RegExp(r'(?<=\d)O(?=\d)'), '0'); // O → 0 in numbers
    cleaned = cleaned.replaceAll(RegExp(r'(?<=\d)l(?=\d)'), '1'); // l → 1 in numbers
    cleaned = cleaned.replaceAll(RegExp(r'(?<=\d)I(?=\d)'), '1'); // I → 1 in numbers

    // Clean excessive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Remove lines that are just dots, dashes, or single characters
    final lines = cleaned.split('\n');
    final filteredLines = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false;
      if (trimmed.length <= 1 && !RegExp(r'[가-힣a-zA-Z0-9]').hasMatch(trimmed)) {
        return false;
      }
      // Remove lines that are only punctuation/symbols
      if (RegExp(r'^[^가-힣a-zA-Z0-9]+$').hasMatch(trimmed)) return false;
      return true;
    });

    return filteredLines.join('\n');
  }

  /// Parse the raw OCR text into structured business card fields.
  OcrResult _parseBusinessCardText(String rawText, {double confidence = 0.0}) {
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

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
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

      // Phone patterns (include dot as separator for formats like 010.1234.5678)
      final phoneRegex = RegExp(r'[\d\-\.\(\)\+\s]{7,}');
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

      // Address indicators (merge consecutive address lines)
      if (_isAddressLine(line)) {
        if (address == null) {
          address = line;
          // Look ahead for continuation lines
          while (i + 1 < lines.length && _isAddressLine(lines[i + 1])) {
            i++;
            address = '$address ${lines[i]}';
          }
        } else {
          // Append to existing address if already found
          address = '$address $line';
        }
        continue;
      }

      unmatched.add(line);
    }

    // Classify unmatched lines using heuristics instead of relying on order
    final List<String> remaining = [];
    for (final line in unmatched) {
      if (company == null && _isCompanyName(line)) {
        company = line;
      } else if (_isPositionTitle(line)) {
        // Line may contain both position and name (e.g. "대리 홍길동")
        final split = _splitPositionAndName(line);
        if (split != null) {
          if (position == null) position = split['position'];
          if (name == null) name = split['name'];
        } else if (position == null) {
          position = line;
        } else {
          remaining.add(line);
        }
      } else if (department == null && _isDepartmentName(line)) {
        department = line;
      } else {
        remaining.add(line);
      }
    }

    // Among remaining lines, find the one that looks like a person name
    if (remaining.isNotEmpty) {
      int nameIdx = -1;
      for (int i = 0; i < remaining.length; i++) {
        if (_isLikelyPersonName(remaining[i])) {
          nameIdx = i;
          break;
        }
      }

      if (nameIdx >= 0 && name == null) {
        name = remaining[nameIdx];
        final leftover = [...remaining]..removeAt(nameIdx);
        for (final line in leftover) {
          if (company == null) {
            company = line;
          } else if (position == null) {
            position = line;
          } else if (department == null) {
            department = line;
          }
        }
      } else if (name == null) {
        // No clear name found — assign remaining to unfilled fields in order
        for (final line in remaining) {
          if (name == null) {
            name = line;
          } else if (company == null) {
            company = line;
          } else if (position == null) {
            position = line;
          } else if (department == null) {
            department = line;
          }
        }
      }
    }

    return OcrResult(
      name: name,
      company: company,
      position: position,
      department: department,
      email: email,
      phone: phone != null ? _cleanPhoneNumber(phone) : null,
      mobile: mobile != null ? _cleanPhoneNumber(mobile) : null,
      fax: fax != null ? _cleanPhoneNumber(fax) : null,
      address: address,
      website: website,
      rawText: rawText,
      confidence: confidence,
    );
  }

  /// Strip separators from phone numbers, keeping only digits and leading +.
  String _cleanPhoneNumber(String number) {
    final trimmed = number.trim();
    final prefix = trimmed.startsWith('+') ? '+' : '';
    return prefix + trimmed.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Try to split a line that contains both a position title and a person name.
  /// Returns {'position': ..., 'name': ...} or null if it can't be split.
  Map<String, String>? _splitPositionAndName(String line) {
    final allPositionKeywords = [
      // Longer keywords first to match greedily (대표이사 before 대표)
      '대표이사', '본부장', '센터장',
      '대표', '이사', '부장', '차장', '과장', '대리', '사원',
      '팀장', '실장', '원장', '소장', '교수', '박사',
      '매니저', '디렉터', '엔지니어',
      'president', 'director', 'manager', 'engineer', 'developer',
      'designer', 'analyst', 'consultant', 'specialist', 'officer',
      'ceo', 'cto', 'cfo', 'coo', 'vp', 'head',
      '总裁', '总经理', '经理', '主任', '工程师',
    ];

    final lower = line.toLowerCase().trim();
    for (final kw in allPositionKeywords) {
      if (!lower.contains(kw.toLowerCase())) continue;
      // Remove the keyword and see if there's a remainder
      final remainder = line
          .replaceAll(RegExp(RegExp.escape(kw), caseSensitive: false), '')
          .trim();
      // If removing the keyword leaves something behind, treat it as the name
      if (remainder.isNotEmpty && remainder != line.trim()) {
        return {'position': kw, 'name': remainder};
      }
    }
    return null;
  }

  /// Check if a line looks like a company/organization name.
  bool _isCompanyName(String line) {
    final companyIndicators = [
      // Korean
      '주식회사', '(주)', '㈜', '법인', '재단', '협회', '그룹', '홀딩스',
      // English
      'inc', 'corp', 'ltd', 'llc', 'co.', 'company', 'group', 'holdings',
      'enterprise', 'associates', 'partners', 'foundation',
      // Chinese
      '公司', '集团', '有限', '股份',
    ];
    final lower = line.toLowerCase();
    return companyIndicators.any((kw) => lower.contains(kw));
  }

  /// Check if a line looks like a job title / position.
  bool _isPositionTitle(String line) {
    final positionIndicators = [
      // Korean
      '대표', '이사', '부장', '차장', '과장', '대리', '사원', '팀장',
      '실장', '본부장', '센터장', '원장', '소장', '교수', '박사',
      '매니저', '디렉터', '엔지니어',
      // English
      'ceo', 'cto', 'cfo', 'coo', 'vp', 'president', 'director',
      'manager', 'engineer', 'developer', 'designer', 'analyst',
      'consultant', 'specialist', 'officer', 'head',
      // Chinese
      '总裁', '总经理', '经理', '主任', '工程师',
    ];
    final lower = line.toLowerCase();
    return positionIndicators.any((kw) => lower.contains(kw));
  }

  /// Check if a line looks like a department name.
  bool _isDepartmentName(String line) {
    final deptIndicators = [
      // Korean
      '부', '팀', '실', '과', '본부', '센터', '사업부', '연구소', '지점',
      // English
      'department', 'division', 'team', 'unit', 'branch', 'office',
      // Chinese
      '部门', '部', '处', '科', '办公室',
    ];
    final lower = line.toLowerCase();
    // For short Korean suffixes (부, 팀, 실, 과), check they appear at the end
    if (RegExp(r'[부팀실과]$').hasMatch(line.trim()) && line.trim().length >= 2) {
      return true;
    }
    return deptIndicators
        .where((kw) => kw.length > 1)
        .any((kw) => lower.contains(kw));
  }

  /// Check if a line is likely a person's name rather than an organization.
  bool _isLikelyPersonName(String line) {
    final trimmed = line.trim();
    // Korean names are typically 2-4 characters (syllables)
    final koreanOnly = trimmed.replaceAll(RegExp(r'[^가-힣]'), '');
    if (koreanOnly.length >= 2 && koreanOnly.length <= 4 && trimmed.length <= 5) {
      return true;
    }
    // English names: 2-3 words, each starting with uppercase
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2 &&
        words.length <= 3 &&
        words.every((w) => w.isNotEmpty && w[0] == w[0].toUpperCase()) &&
        !_isCompanyName(trimmed) &&
        !_isPositionTitle(trimmed)) {
      return true;
    }
    return false;
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