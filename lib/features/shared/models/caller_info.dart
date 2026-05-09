/// 수신 전화 시 표시할 명함 정보 DTO
class CallerInfo {
  final String name;
  final String? company;
  final String? position;
  final String? department;
  final String? email;
  final String? imageUrl;
  final String? memo;

  /// 'collected' 또는 'crm'
  final String source;

  const CallerInfo({
    required this.name,
    this.company,
    this.position,
    this.department,
    this.email,
    this.imageUrl,
    this.memo,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    if (company != null) 'company': company,
    if (position != null) 'position': position,
    if (department != null) 'department': department,
    if (email != null) 'email': email,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (memo != null) 'memo': memo,
    'source': source,
  };

  factory CallerInfo.fromJson(Map<String, dynamic> json) => CallerInfo(
    name: (json['name'] as String?) ?? '',
    company: json['company'] as String?,
    position: json['position'] as String?,
    department: json['department'] as String?,
    email: json['email'] as String?,
    imageUrl: json['imageUrl'] as String?,
    memo: json['memo'] as String?,
    source: (json['source'] as String?) ?? 'collected',
  );
}