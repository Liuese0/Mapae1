/// 전화번호 정규화 유틸리티
///
/// 공백, 하이픈, 괄호, 국가코드를 제거하여 비교 가능한 형태로 변환합니다.
/// 예: "+82-10-1234-5678" → "01012345678"
///     "010 1234 5678" → "01012345678"
String normalizePhone(String raw) {
  // 숫자와 + 기호만 남기기
  var digits = raw.replaceAll(RegExp(r'[^\d+]'), '');

  // 한국 국가코드 처리
  if (digits.startsWith('+82')) {
    digits = '0${digits.substring(3)}';
  } else if (digits.startsWith('82') && digits.length > 10) {
    digits = '0${digits.substring(2)}';
  }

  // + 기호 제거 (다른 국가코드)
  digits = digits.replaceAll('+', '');

  return digits;
}