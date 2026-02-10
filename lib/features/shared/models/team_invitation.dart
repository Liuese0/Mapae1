enum InvitationStatus { pending, accepted, declined }

class TeamInvitation {
  final String id;
  final String teamId;
  final String inviterId;
  final String inviteeId;
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 조인된 추가 정보 (UI 표시용)
  final String? teamName;
  final String? inviterName;
  final String? inviteeName;
  final String? inviteeEmail;

  const TeamInvitation({
    required this.id,
    required this.teamId,
    required this.inviterId,
    required this.inviteeId,
    this.status = InvitationStatus.pending,
    required this.createdAt,
    required this.updatedAt,
    this.teamName,
    this.inviterName,
    this.inviteeName,
    this.inviteeEmail,
  });

  factory TeamInvitation.fromJson(Map<String, dynamic> json) {
    return TeamInvitation(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      inviterId: json['inviter_id'] as String,
      inviteeId: json['invitee_id'] as String,
      status: InvitationStatus.values.firstWhere(
            (s) => s.name == json['status'],
        orElse: () => InvitationStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      teamName: json['teams'] != null
          ? (json['teams'] as Map<String, dynamic>)['name'] as String?
          : json['team_name'] as String?,
      inviterName: json['inviter'] != null
          ? (json['inviter'] as Map<String, dynamic>)['name'] as String?
          : json['inviter_name'] as String?,
      inviteeName: json['invitee'] != null
          ? (json['invitee'] as Map<String, dynamic>)['name'] as String?
          : json['invitee_name'] as String?,
      inviteeEmail: json['invitee'] != null
          ? (json['invitee'] as Map<String, dynamic>)['email'] as String?
          : json['invitee_email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'inviter_id': inviterId,
      'invitee_id': inviteeId,
      'status': status.name,
    };
  }
}