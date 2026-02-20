enum TeamRole { owner, member, observer }

class Team {
  final String id;
  final String name;
  final String ownerId;
  final String? description;
  final String? imageUrl;
  final String? shareCode;
  final bool shareCodeEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Team({
    required this.id,
    required this.name,
    required this.ownerId,
    this.description,
    this.imageUrl,
    this.shareCode,
    this.shareCodeEnabled = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      shareCode: json['share_code'] as String?,
      shareCodeEnabled: json['share_code_enabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'owner_id': ownerId,
      'description': description,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class TeamMember {
  final String id;
  final String teamId;
  final String userId;
  final TeamRole role;
  final String? userName;
  final DateTime joinedAt;

  const TeamMember({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.role,
    this.userName,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String,
      role: TeamRole.values.firstWhere(
            (r) => r.name == json['role'],
        orElse: () => TeamRole.observer,
      ),
      userName: json['user_name'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'user_id': userId,
      'role': role.name,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}