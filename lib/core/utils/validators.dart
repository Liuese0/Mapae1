/// 입력 검증 유틸리티.
///
/// 폼 필드의 검증과 보안을 위한 정적 메서드를 제공합니다.
class Validators {
  Validators._();

  // ──────────────── 길이 제한 상수 ────────────────

  static const int maxNameLength = 50;
  static const int maxCompanyLength = 100;
  static const int maxPositionLength = 50;
  static const int maxDepartmentLength = 50;
  static const int maxEmailLength = 100;
  static const int maxPhoneLength = 30;
  static const int maxAddressLength = 200;
  static const int maxWebsiteLength = 200;
  static const int maxMemoLength = 500;
  static const int maxTeamNameLength = 50;

  // ──────────────── 이메일 검증 ────────────────

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );

  static bool isValidEmail(String email) {
    return email.isNotEmpty && _emailRegex.hasMatch(email);
  }

  // ──────────────── 전화번호 검증 ────────────────

  static final RegExp _phoneRegex = RegExp(
    r'^[\d\s\-+().]+$',
  );

  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 7 && digits.length <= 15 && _phoneRegex.hasMatch(phone);
  }

  // ──────────────── 비밀번호 강도 ────────────────

  /// 비밀번호 강도를 0~3으로 반환 (0: 너무 짧음, 1: 약함, 2: 보통, 3: 강함)
  static int passwordStrength(String password) {
    if (password.length < 6) return 0;

    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 1) return 1;
    if (score <= 2) return 2;
    return 3;
  }

  // ──────────────── HTML 태그 제거 ────────────────

  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');

  /// XSS 방지를 위해 HTML 태그를 제거합니다.
  static String stripHtmlTags(String input) {
    return input.replaceAll(_htmlTagRegex, '');
  }

  // ──────────────── 문자열 정제 ────────────────

  /// 문자열의 HTML 태그를 제거하고 길이를 제한합니다.
  static String sanitize(String input, {int? maxLength}) {
    var result = stripHtmlTags(input.trim());
    if (maxLength != null && result.length > maxLength) {
      result = result.substring(0, maxLength);
    }
    return result;
  }

  // ──────────────── 폼 검증 헬퍼 (FormField validator용) ────────────────

  /// 필수 필드 검증기 생성
  static String? Function(String?) required(String errorMessage) {
    return (value) {
      if (value == null || value.trim().isEmpty) return errorMessage;
      return null;
    };
  }

  /// 이메일 형식 검증기 생성
  static String? Function(String?) email({
    required String emptyError,
    required String invalidError,
  }) {
    return (value) {
      if (value == null || value.isEmpty) return emptyError;
      if (!isValidEmail(value)) return invalidError;
      return null;
    };
  }

  /// 최소 길이 검증기 생성
  static String? Function(String?) minLength(int min, String errorMessage) {
    return (value) {
      if (value != null && value.length < min) return errorMessage;
      return null;
    };
  }

  /// 최대 길이 검증기 생성
  static String? Function(String?) maxLength(int max, String errorMessage) {
    return (value) {
      if (value != null && value.length > max) return errorMessage;
      return null;
    };
  }
}