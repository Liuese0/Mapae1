/// 수신 전화 시 표시할 명함 정보 DTO
class CallerInfo {
  final String name;
  final String? company;
  final String? position;
  final String? imageUrl;
  /// 'collected' 또는 'crm'
  final String source;

  const CallerInfo({
    required this.name,
    this.company,
    this.position,
    this.imageUrl,
    required this.source,
  });
}