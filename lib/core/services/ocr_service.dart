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
  final String? instagram;
  final String rawText;
  final double confidence;
  final Map<String, String> extraFields;

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
    this.instagram,
    required this.rawText,
    this.confidence = 0.0,
    this.extraFields = const {},
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
          .timeout(const Duration(seconds: 10), onTimeout: () => imageFile);
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

    // Retry up to 2 times on timeout/network errors
    Response? response;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        response = await _dio.post(
          AppConstants.ocrApiUrl,
          data: formData,
          options: Options(
            headers: {
              'apikey': AppConstants.ocrApiKey,
            },
            sendTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        break; // Success, exit retry loop
      } on DioException catch (e) {
        final isRetryable = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (!isRetryable || attempt == 2) rethrow;
        // Wait before retry: 2s, 4s
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }

    if (response != null && response.statusCode == 200) {
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

  // ─────────────────────────────────────────────────────────
  // OCR Artifact Cleaning
  // ─────────────────────────────────────────────────────────

  /// Clean common OCR artifacts from raw text.
  String _cleanOcrArtifacts(String rawText) {
    var cleaned = rawText;

    // Remove common OCR noise characters
    cleaned = cleaned.replaceAll(RegExp(r'[|\\{}\[\]<>~`]'), '');

    // Fix O/l/I in digit sequences (broader context than just between digits)
    // O at start or within digit-like sequences → 0
    cleaned = cleaned.replaceAll(RegExp(r'(?<=\d)O'), '0');
    cleaned = cleaned.replaceAll(RegExp(r'O(?=\d)'), '0');
    // l/I within digit sequences → 1
    cleaned = cleaned.replaceAll(RegExp(r'(?<=\d)[lI]'), '1');
    cleaned = cleaned.replaceAll(RegExp(r'[lI](?=\d)'), '1');

    // Korean phone number prefix OCR errors: O10 → 010, O2 → 02
    cleaned = cleaned.replaceAll(RegExp(r'\bO(10|11|16|17|18|19)[-.\s]'), '0\$1-');
    cleaned = cleaned.replaceAll(RegExp(r'\bO(2|31|32|33|41|42|43|44|51|52|53|54|55|61|62|63|64)[-.\s]'), '0\$1-');

    // "rn" → "m" in common OCR misreads (only in known words)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\b(corn|cornpany|cornrnunication|nurnber|rnail|rnobile|rnanager|rnaster)', caseSensitive: false),
          (m) => m.group(0)!.replaceAll('rn', 'm').replaceAll('Rn', 'M'),
    );

    // Remove stray Chinese characters mixed into Korean text (common OCR misread).
    // When a line is mostly Korean (가-힣) and contains isolated Chinese characters
    // (1-2 chars surrounded by Korean), replace them with empty to let the user
    // correct manually, rather than displaying wrong characters.
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<=[가-힣])([\u4e00-\u9fff]{1,2})(?=[가-힣])'),
          (m) => '',
    );

    // Clean excessive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Remove lines that are just dots, dashes, or single characters
    final lines = cleaned.split('\n');
    final filteredLines = lines.where((line) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) return false;
      if (trimmed.length <= 1 && !RegExp(r'[가-힣a-zA-Z0-9\u4e00-\u9fff]').hasMatch(trimmed)) {
        return false;
      }
      // Remove lines that are only punctuation/symbols
      if (RegExp(r'^[^가-힣a-zA-Z0-9\u4e00-\u9fff]+$').hasMatch(trimmed)) return false;
      return true;
    });

    return filteredLines.join('\n');
  }

  // ─────────────────────────────────────────────────────────
  // Email Helpers
  // ─────────────────────────────────────────────────────────

  static final _emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');

  /// Common email domain typo corrections
  static const _domainCorrections = {
    'gamil.com': 'gmail.com',
    'gmai1.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'grnail.com': 'gmail.com',
    'naver.corn': 'naver.com',
    'naver.c0m': 'naver.com',
    'daurn.net': 'daum.net',
    'hanrnail.net': 'hanmail.net',
    'hotrnail.com': 'hotmail.com',
    'out1ook.com': 'outlook.com',
    'outl00k.com': 'outlook.com',
    'yahoo.corn': 'yahoo.com',
  };

  /// Extract and clean email from a line.
  String? _extractEmail(String line) {
    final match = _emailRegex.firstMatch(line);
    if (match == null) return null;
    var email = match.group(0)!.toLowerCase();

    // Correct common domain typos
    for (final entry in _domainCorrections.entries) {
      if (email.endsWith('@${entry.key}')) {
        email = email.replaceFirst(entry.key, entry.value);
        break;
      }
    }

    // Remove trailing dots
    email = email.replaceAll(RegExp(r'\.+$'), '');

    // Fix l/1 confusion in email local part:
    // At letter-digit boundaries, 'l' is likely '1' (e.g., "poplivel" → "poplive1")
    final atIdx = email.indexOf('@');
    if (atIdx > 0) {
      var local = email.substring(0, atIdx);
      final domain = email.substring(atIdx);
      // 'l' at end of local part preceded by a letter → likely '1'
      // (e.g., "abcl@" → "abc1@", "live1l@" → "live11@")
      local = local.replaceAllMapped(
        RegExp(r'(?<=[a-z])l$'),
            (m) => '1',
      );
      // 'l' between a letter and digits → likely '1' (e.g., "abel23" → "abe123")
      local = local.replaceAllMapped(
        RegExp(r'(?<=[a-z])l(?=\d)'),
            (m) => '1',
      );
      email = '$local$domain';
    }

    return email;
  }

  // ─────────────────────────────────────────────────────────
  // Phone Number Helpers
  // ─────────────────────────────────────────────────────────

  static final _phoneRegex = RegExp(r'[\d\-\.\(\)\+\s]{7,}');

  /// Classify a phone number as 'mobile', 'phone', or 'fax' based on
  /// Korean number patterns. Returns null if cannot determine.
  String? _classifyKoreanPhoneNumber(String digits) {
    final cleaned = digits.replaceAll(RegExp(r'[^\d+]'), '');
    // Remove +82 prefix for classification
    final normalized = cleaned.startsWith('+82')
        ? '0${cleaned.substring(3)}'
        : cleaned;

    // Mobile: 010, 011, 016, 017, 018, 019
    if (RegExp(r'^01[016789]').hasMatch(normalized)) return 'mobile';
    // Internet fax: 0504, 0505, 0506
    if (RegExp(r'^050[456]').hasMatch(normalized)) return 'fax';
    // Landline: 02 (Seoul), 031-064 (regional)
    if (RegExp(r'^0[2-6]\d').hasMatch(normalized)) return 'phone';

    return null;
  }

  /// Extract all phone numbers from a single line. Some lines have multiple
  /// numbers separated by labels or spaces.
  List<MapEntry<String, String>> _extractPhoneNumbers(String line) {
    final results = <MapEntry<String, String>>[];
    final matches = _phoneRegex.allMatches(line);

    for (final match in matches) {
      final number = match.group(0)!.trim();
      final digits = number.replaceAll(RegExp(r'[^\d+]'), '');
      if (digits.replaceAll('+', '').length < 7) continue;

      // Check label context around this specific match
      final beforeStart = (match.start - 15).clamp(0, line.length);
      final context = line.substring(beforeStart, match.end).toLowerCase();

      String type;
      if (context.contains('fax') || context.contains('팩스') || context.contains('传真') ||
          RegExp(r'\bf\.\s*$|^f\s', caseSensitive: false).hasMatch(context)) {
        type = 'fax';
      } else if (context.contains('mobile') || context.contains('휴대') || context.contains('핸드폰') ||
          context.contains('手机') || context.contains('cell') ||
          RegExp(r'\bm\.\s*$|^m\s|h\.?p', caseSensitive: false).hasMatch(context)) {
        type = 'mobile';
      } else if (context.contains('tel') || context.contains('전화') || context.contains('电话') ||
          context.contains('phone') || context.contains('직통') ||
          RegExp(r'\bt\.\s*$|^t\s', caseSensitive: false).hasMatch(context)) {
        type = 'phone';
      } else {
        // Classify by Korean number pattern
        type = _classifyKoreanPhoneNumber(number) ?? 'phone';
      }

      results.add(MapEntry(type, number));
    }

    return results;
  }

  /// Strip separators from phone numbers, keeping only digits and leading +.
  String _cleanPhoneNumber(String number) {
    final trimmed = number.trim();
    final prefix = trimmed.startsWith('+') ? '+' : '';
    return prefix + trimmed.replaceAll(RegExp(r'[^\d]'), '');
  }

  // ─────────────────────────────────────────────────────────
  // Field Detection Helpers
  // ─────────────────────────────────────────────────────────

  /// All position keywords used for detection and splitting, ordered longest first.
  static const List<String> _positionKeywords = [
    // Korean - longer keywords first for greedy matching
    '대표이사', '부대표', '전무이사', '상무이사', '본부장', '센터장',
    '수석연구원', '책임연구원', '선임연구원', '주임연구원', '연구원',
    '수석', '책임', '선임', '주임',
    '대표', '전무', '상무', '이사', '부장', '차장', '과장', '대리', '사원',
    '팀장', '실장', '원장', '소장', '교수', '박사', '위원', '간사',
    '매니저', '디렉터', '엔지니어', '컨설턴트',
    '기자', '편집장', '국장', '기획자', '연구위원',
    // English
    'president', 'vice president', 'director', 'manager', 'engineer',
    'developer', 'designer', 'analyst', 'consultant', 'specialist',
    'officer', 'head', 'lead', 'senior', 'associate', 'assistant',
    'supervisor', 'coordinator', 'advisor', 'architect',
    'ceo', 'cto', 'cfo', 'coo', 'vp', 'evp', 'svp',
    'partner', 'founder', 'co-founder', 'chairman',
    // Chinese
    '总裁', '总经理', '副总经理', '经理', '副经理', '主任', '工程师',
    '董事长', '董事', '顾问',
  ];

  /// Check if a line looks like a job title / position.
  bool _isPositionTitle(String line) {
    final lower = line.toLowerCase().trim();
    return _positionKeywords.any((kw) => lower.contains(kw.toLowerCase()));
  }

  /// Check if a line looks like a company/organization name.
  bool _isCompanyName(String line) {
    final companyIndicators = [
      // Korean
      '주식회사', '(주)', '㈜', '법인', '재단', '협회', '그룹', '홀딩스',
      '센터', '연구소', '학교', '대학교', '병원', '은행', '증권', '보험', '건설',
      '엔터테인먼트', '미디어', '네트워크', '테크', '소프트',
      // English
      'inc', 'corp', 'ltd', 'llc', 'co.', 'company', 'group', 'holdings',
      'enterprise', 'associates', 'partners', 'foundation',
      'technologies', 'solutions', 'consulting', 'systems', 'studio', 'labs',
      'bank', 'securities', 'insurance', 'media', 'network',
      // Chinese
      '公司', '集团', '有限', '股份', '银行', '医院', '大学', '研究所', '技术',
    ];
    final lower = line.toLowerCase();
    return companyIndicators.any((kw) => lower.contains(kw));
  }

  /// Department indicators with proper matching rules.
  bool _isDepartmentName(String line) {
    final trimmed = line.trim();
    final lower = trimmed.toLowerCase();

    // Multi-char Korean department keywords (safe to match anywhere)
    const longDeptKeywords = [
      '본부', '센터', '사업부', '연구소', '지점', '사무소', '기획실',
      '영업부', '개발부', '인사부', '총무부', '마케팅', '홍보부',
    ];
    if (longDeptKeywords.any((kw) => lower.contains(kw))) return true;

    // Short Korean suffixes: must be at end and total length >= 3
    // to avoid matching "부" in "부장" or "과" in "과장"
    if (trimmed.length >= 3 && RegExp(r'[부팀실과국]$').hasMatch(trimmed)) {
      // Make sure this isn't a position keyword
      if (!_isPositionTitle(trimmed)) return true;
    }

    // English
    const engDeptKeywords = ['department', 'division', 'team', 'unit', 'branch', 'office'];
    if (engDeptKeywords.any((kw) => lower.contains(kw))) return true;

    // Chinese
    const cnDeptKeywords = ['部门', '处', '科', '办公室'];
    if (cnDeptKeywords.any((kw) => lower.contains(kw))) return true;

    return false;
  }

  /// Check if a line is likely a person's name rather than an organization.
  bool _isLikelyPersonName(String line) {
    final trimmed = line.trim();

    // Reject if it's a company or department
    if (_isCompanyName(trimmed) || _isDepartmentName(trimmed)) return false;

    // Korean names are typically 2-4 characters (syllables)
    final koreanOnly = trimmed.replaceAll(RegExp(r'[^가-힣]'), '');
    if (koreanOnly.length >= 2 && koreanOnly.length <= 4 && trimmed.length <= 5) {
      return true;
    }

    // Korean name + position on same line (e.g. "홍길동 과장", "대리 홍길동")
    if (koreanOnly.length >= 2 && koreanOnly.length <= 4 && trimmed.length <= 15) {
      var stripped = trimmed;
      for (final kw in _positionKeywords) {
        stripped = stripped.replaceAll(RegExp(RegExp.escape(kw), caseSensitive: false), '').trim();
      }
      final strippedKorean = stripped.replaceAll(RegExp(r'[^가-힣]'), '');
      if (strippedKorean.length >= 2 && strippedKorean.length <= 4) {
        return true;
      }
    }

    // Chinese names: 2-4 Chinese characters only
    final chineseOnly = trimmed.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
    if (chineseOnly.length >= 2 && chineseOnly.length <= 4 && trimmed.length <= 5) {
      return true;
    }

    // English names: 2-3 words, each starting with uppercase, no digits
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2 &&
        words.length <= 3 &&
        words.every((w) => w.isNotEmpty && w[0] == w[0].toUpperCase() && !RegExp(r'\d').hasMatch(w)) &&
        !_isPositionTitle(trimmed)) {
      return true;
    }

    // English name with comma: "Smith, John"
    if (trimmed.contains(',') && !trimmed.contains('@')) {
      final parts = trimmed.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length == 2 &&
          parts.every((p) => p.split(' ').every((w) => w.isNotEmpty && w[0] == w[0].toUpperCase()))) {
        return true;
      }
    }

    return false;
  }

  bool _isAddressLine(String line) {
    final lower = line.toLowerCase();

    // Postal code patterns: Korean 5-digit, Chinese 6-digit
    if (RegExp(r'\b\d{5,6}\b').hasMatch(line) && !_emailRegex.hasMatch(line) && !_phoneRegex.hasMatch(line)) {
      // Could be a postal code line — check with other indicators
      final addressKeywords = ['시', '구', '동', '로', '길', 'street', 'road', '省', '市'];
      if (addressKeywords.any((kw) => lower.contains(kw))) return true;
    }

    final addressKeywords = [
      // Korean - provinces and cities
      '서울', '부산', '대구', '인천', '광주', '대전', '울산', '세종',
      '경기', '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
      // Korean - address components
      '특별시', '광역시', '특별자치',
      '번지', '호',
      // Korean - short suffixes (checked with context)
      '시', '구', '동', '로', '길', '층',
      // English
      'street', 'st.', 'ave', 'avenue', 'road', 'rd.', 'suite', 'floor',
      'building', 'bldg', 'zip', 'postal', 'p.o. box',
      // Chinese
      '省', '市', '区', '路', '号', '楼', '室', '街', '巷',
    ];

    return addressKeywords.any((kw) => lower.contains(kw.toLowerCase()));
  }

  // ─────────────────────────────────────────────────────────
  // Name / Position / Department Splitting
  // ─────────────────────────────────────────────────────────

  /// Try to split a line that contains both a position title and a person name.
  /// Handles "직급 이름", "이름 직급", "이름, 직급", "Name, Title" orders.
  Map<String, String>? _splitPositionAndName(String line) {
    final trimmed = line.trim();

    // Handle comma-separated: "홍길동, 과장" or "Manager, John Smith"
    if (trimmed.contains(',')) {
      final parts = trimmed.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length == 2) {
        // Check which part is position
        if (_isPositionTitle(parts[0]) && !_isPositionTitle(parts[1])) {
          return {'position': parts[0], 'name': parts[1]};
        }
        if (_isPositionTitle(parts[1]) && !_isPositionTitle(parts[0])) {
          return {'position': parts[1], 'name': parts[0]};
        }
      }
    }

    final lower = trimmed.toLowerCase();

    for (final kw in _positionKeywords) {
      final kwLower = kw.toLowerCase();
      if (!lower.contains(kwLower)) continue;

      // Remove the matched keyword and clean up
      final remainder = trimmed
          .replaceFirst(RegExp(RegExp.escape(kw), caseSensitive: false), '')
          .replaceAll(RegExp(r'[\s,/·]+'), ' ')
          .trim();

      if (remainder.isEmpty || remainder == trimmed) continue;

      // Validate the remainder looks like a name
      if (remainder.length <= 12 || _isLikelyPersonName(remainder)) {
        // For short Korean remainder, verify it's actually a name-like string
        final koreanOnly = remainder.replaceAll(RegExp(r'[^가-힣]'), '');
        if (koreanOnly.length >= 2 && koreanOnly.length <= 4) {
          return {'position': kw, 'name': remainder};
        }
        // For English remainder
        if (remainder.split(' ').length <= 3 && RegExp(r'^[A-Z]').hasMatch(remainder)) {
          return {'position': kw, 'name': remainder};
        }
        // For Chinese remainder
        final chineseOnly = remainder.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
        if (chineseOnly.length >= 2 && chineseOnly.length <= 4) {
          return {'position': kw, 'name': remainder};
        }
        // Generic fallback for short remainders
        if (remainder.length <= 10) {
          return {'position': kw, 'name': remainder};
        }
      }
    }
    return null;
  }

  /// Try to split a line that contains both department and position.
  /// e.g. "영업팀 과장" → department=영업팀, position=과장
  /// e.g. "Sales Team Manager" → department=Sales Team, position=Manager
  Map<String, String>? _splitDepartmentAndPosition(String line) {
    final trimmed = line.trim();

    // Try each position keyword
    for (final kw in _positionKeywords) {
      final kwLower = kw.toLowerCase();
      final lower = trimmed.toLowerCase();
      if (!lower.contains(kwLower)) continue;

      final remainder = trimmed
          .replaceFirst(RegExp(RegExp.escape(kw), caseSensitive: false), '')
          .replaceAll(RegExp(r'[\s,/·]+'), ' ')
          .trim();

      if (remainder.isEmpty || remainder == trimmed) continue;

      // Check if the remainder is a department name
      if (_isDepartmentName(remainder)) {
        return {'department': remainder, 'position': kw};
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // Main Parsing Logic (4-pass)
  // ─────────────────────────────────────────────────────────

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

    // ── Pass 1: Extract definite pattern matches (email, website, phone, address) ──
    final List<String> pass1Unmatched = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Email
      final extractedEmail = _extractEmail(line);
      if (extractedEmail != null && email == null) {
        email = extractedEmail;
        // Check if the rest of the line contains address info
        final remainder = line
            .replaceAll(_emailRegex.firstMatch(line)!.group(0)!, '')
            .replaceAll(RegExp(r'^[:\s,E\-mail]+|[:\s,]+$', caseSensitive: false), '')
            .trim();
        if (remainder.isNotEmpty && _isAddressLine(remainder) && address == null) {
          address = remainder;
        }
        continue;
      }

      // Website
      if (RegExp(r'(https?://|www\.)', caseSensitive: false).hasMatch(line) && website == null) {
        website = line.replaceAll(
          RegExp(r'^(홈페이지|웹사이트|홈 페이지|Web|Website|网站|Homepage)[:\s]*', caseSensitive: false),
          '',
        ).trim();
        // Ensure https:// prefix
        if (!website.startsWith('http') && website.startsWith('www.')) {
          website = 'https://$website';
        }
        continue;
      }

      // Phone numbers — extract all from the line
      final phoneMatches = _extractPhoneNumbers(line);
      if (phoneMatches.isNotEmpty) {
        for (final entry in phoneMatches) {
          switch (entry.key) {
            case 'fax':
              fax ??= entry.value;
              break;
            case 'mobile':
              mobile ??= entry.value;
              break;
            case 'phone':
            default:
              if (phone == null) {
                phone = entry.value;
              } else if (mobile == null && entry.key != 'phone') {
                mobile = entry.value;
              }
              break;
          }
        }
        continue;
      }

      // Address (merge consecutive address lines)
      if (_isAddressLine(line)) {
        var addressPart = line;
        // Strip out any embedded email
        final embeddedEmail = _emailRegex.firstMatch(addressPart);
        if (embeddedEmail != null) {
          email ??= _extractEmail(addressPart);
          addressPart = addressPart
              .replaceAll(embeddedEmail.group(0)!, '')
              .replaceAll(RegExp(r'^[:\s,]+|[:\s,]+$'), '')
              .trim();
        }
        // Strip out any embedded phone
        final embeddedPhone = _phoneRegex.firstMatch(addressPart);
        if (embeddedPhone != null) {
          final phoneNum = embeddedPhone.group(0)!.trim();
          final phoneDigits = phoneNum.replaceAll(RegExp(r'[^\d+]'), '');
          if (phoneDigits.replaceAll('+', '').length >= 7) {
            final pType = _classifyKoreanPhoneNumber(phoneNum) ?? 'phone';
            if (pType == 'mobile') {
              mobile ??= phoneNum;
            } else {
              phone ??= phoneNum;
            }
            addressPart = addressPart
                .replaceAll(embeddedPhone.group(0)!, '')
                .replaceAll(RegExp(r'^[:\s,]+|[:\s,]+$'), '')
                .trim();
          }
        }

        if (addressPart.isNotEmpty) {
          // Strip address label prefixes
          addressPart = addressPart.replaceAll(
            RegExp(r'^(주소|Address|地址|Add|ADDR)[:\s.]*', caseSensitive: false),
            '',
          ).trim();

          if (address == null) {
            address = addressPart;
            // Look ahead for continuation lines
            while (i + 1 < lines.length) {
              final nextLine = lines[i + 1];
              // Continue if next line looks like address continuation
              // (has address keywords OR is short and doesn't match other patterns)
              if (_isAddressLine(nextLine) ||
                  (_isAddressContinuation(nextLine) && !_emailRegex.hasMatch(nextLine))) {
                i++;
                address = '$address ${lines[i]}';
              } else {
                break;
              }
            }
          } else {
            address = '$address $addressPart';
          }
        }
        continue;
      }

      pass1Unmatched.add(line);
    }

    // ── Pass 2: Classify unmatched lines (company → department → position) ──
    final List<String> pass2Remaining = [];
    for (final line in pass1Unmatched) {
      if (company == null && _isCompanyName(line)) {
        company = line;
      } else if (_isDepartmentName(line) && _isPositionTitle(line)) {
        // Line contains both department and position: "영업팀 과장"
        final split = _splitDepartmentAndPosition(line);
        if (split != null) {
          department ??= split['department'];
          position ??= split['position'];
        } else {
          // Ambiguous — prefer position if department already found
          if (department != null && position == null) {
            position = line;
          } else if (department == null) {
            department = line;
          } else {
            pass2Remaining.add(line);
          }
        }
      } else if (_isPositionTitle(line)) {
        // Check if line contains position + name
        final split = _splitPositionAndName(line);
        if (split != null) {
          position ??= split['position'];
          name ??= split['name'];
        } else if (position == null) {
          position = line;
        } else {
          pass2Remaining.add(line);
        }
      } else if (department == null && _isDepartmentName(line)) {
        department = line;
      } else {
        pass2Remaining.add(line);
      }
    }

    // ── Pass 3: Extract name from remaining lines ──
    final List<String> pass3Leftover = [];
    if (pass2Remaining.isNotEmpty) {
      // First, find the most likely person name
      int nameIdx = -1;
      for (int i = 0; i < pass2Remaining.length; i++) {
        if (_isLikelyPersonName(pass2Remaining[i])) {
          nameIdx = i;
          break;
        }
      }

      if (nameIdx >= 0 && name == null) {
        final candidate = pass2Remaining[nameIdx];
        // Try to split off position keywords even from name candidates
        final split = _splitPositionAndName(candidate);
        if (split != null) {
          name = split['name'];
          position ??= split['position'];
        } else {
          name = candidate;
        }
        // Process remaining lines
        for (int i = 0; i < pass2Remaining.length; i++) {
          if (i == nameIdx) continue;
          pass3Leftover.add(pass2Remaining[i]);
        }
      } else {
        pass3Leftover.addAll(pass2Remaining);
      }
    }

    // ── Pass 4: Fill remaining fields with position-based heuristics ──
    // Lines closer to the top of the card are more likely company names
    for (final line in pass3Leftover) {
      if (name == null) {
        // Try splitting in case it's a combined name+position
        final split = _splitPositionAndName(line);
        if (split != null) {
          name = split['name'];
          position ??= split['position'];
        } else {
          name = line;
        }
      } else if (company == null) {
        company = line;
      } else if (position == null) {
        position = line;
      } else {
        department ??= line;
      }
    }

    // ── Post-processing: strip label prefixes from fields ──
    name = _stripLabel(name, ['이름', 'Name', '姓名']);
    company = _stripLabel(company, ['회사', '회사명', 'Company', '公司']);
    position = _stripLabel(position, ['직급', '직위', 'Title', 'Position', '职位']);
    department = _stripLabel(department, ['부서', 'Department', 'Dept', '部门']);
    address = _stripLabel(address, ['주소', 'Address', 'Add', 'ADDR', '地址']);

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

  /// Check if a line is likely a continuation of an address (not a new field).
  bool _isAddressContinuation(String line) {
    final trimmed = line.trim();
    // Short lines with numbers + text could be address continuation (e.g., "5층", "123호")
    if (trimmed.length <= 20 && RegExp(r'\d').hasMatch(trimmed) && !_emailRegex.hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  /// Remove common field label prefixes from a value.
  String? _stripLabel(String? value, List<String> labels) {
    if (value == null) return null;
    var result = value;
    for (final label in labels) {
      result = result.replaceAll(
        RegExp('^$label[:\\s.]*', caseSensitive: false),
        '',
      ).trim();
    }
    return result.isEmpty ? null : result;
  }
}