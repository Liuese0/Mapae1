class CardCategory {
  final String id;
  final String userId;
  final String name;
  final String? teamId; // if category belongs to a team
  final int sortOrder;
  final DateTime createdAt;

  const CardCategory({
    required this.id,
    required this.userId,
    required this.name,
    this.teamId,
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory CardCategory.fromJson(Map<String, dynamic> json) {
    return CardCategory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      teamId: json['team_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'team_id': teamId,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CardCategory copyWith({
    String? id,
    String? userId,
    String? name,
    String? teamId,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CardCategory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      teamId: teamId ?? this.teamId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
