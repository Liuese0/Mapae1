class AppUser {
  final String id;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final String locale; // 'ko', 'en', 'zh'
  final bool isDarkMode;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    this.name,
    this.email,
    this.avatarUrl,
    this.locale = 'ko',
    this.isDarkMode = false,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      locale: json['locale'] as String? ?? 'ko',
      isDarkMode: json['is_dark_mode'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'locale': locale,
      'is_dark_mode': isDarkMode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? locale,
    bool? isDarkMode,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      locale: locale ?? this.locale,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
