/// CRM 연락처 상태 (파이프라인 단계)
enum CrmStatus {
  lead,     // 리드
  contact,  // 연락
  meeting,  // 미팅
  proposal, // 제안
  contract, // 계약
  closed,   // 완료
}

extension CrmStatusX on CrmStatus {
  String get label {
    switch (this) {
      case CrmStatus.lead:
        return '리드';
      case CrmStatus.contact:
        return '연락';
      case CrmStatus.meeting:
        return '미팅';
      case CrmStatus.proposal:
        return '제안';
      case CrmStatus.contract:
        return '계약';
      case CrmStatus.closed:
        return '완료';
    }
  }

  String get icon {
    switch (this) {
      case CrmStatus.lead:
        return '🔍';
      case CrmStatus.contact:
        return '📞';
      case CrmStatus.meeting:
        return '🤝';
      case CrmStatus.proposal:
        return '📋';
      case CrmStatus.contract:
        return '📝';
      case CrmStatus.closed:
        return '✅';
    }
  }
}

/// CRM 연락처 - 팀 공유 명함 기반 CRM 관리
class CrmContact {
  final String id;
  final String teamId;
  final String? sharedCardId;
  final String createdBy;
  final String? name;
  final String? company;
  final String? position;
  final String? department;
  final String? email;
  final String? phone;
  final String? mobile;
  final CrmStatus status;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CrmContact({
    required this.id,
    required this.teamId,
    this.sharedCardId,
    required this.createdBy,
    this.name,
    this.company,
    this.position,
    this.department,
    this.email,
    this.phone,
    this.mobile,
    this.status = CrmStatus.lead,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrmContact.fromJson(Map<String, dynamic> json) {
    return CrmContact(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      sharedCardId: json['shared_card_id'] as String?,
      createdBy: json['created_by'] as String,
      name: json['name'] as String?,
      company: json['company'] as String?,
      position: json['position'] as String?,
      department: json['department'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      mobile: json['mobile'] as String?,
      status: CrmStatus.values.firstWhere(
            (s) => s.name == json['status'],
        orElse: () => CrmStatus.lead,
      ),
      memo: json['memo'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'team_id': teamId,
      'shared_card_id': sharedCardId,
      'created_by': createdBy,
      'name': name,
      'company': company,
      'position': position,
      'department': department,
      'email': email,
      'phone': phone,
      'mobile': mobile,
      'status': status.name,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CrmContact copyWith({
    String? id,
    String? teamId,
    String? sharedCardId,
    String? createdBy,
    String? name,
    String? company,
    String? position,
    String? department,
    String? email,
    String? phone,
    String? mobile,
    CrmStatus? status,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CrmContact(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      sharedCardId: sharedCardId ?? this.sharedCardId,
      createdBy: createdBy ?? this.createdBy,
      name: name ?? this.name,
      company: company ?? this.company,
      position: position ?? this.position,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      status: status ?? this.status,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// CRM 활동 노트
class CrmNote {
  final String id;
  final String contactId;
  final String authorId;
  final String? authorName;
  final String content;
  final DateTime createdAt;

  const CrmNote({
    required this.id,
    required this.contactId,
    required this.authorId,
    this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory CrmNote.fromJson(Map<String, dynamic> json) {
    return CrmNote(
      id: json['id'] as String,
      contactId: json['contact_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'contact_id': contactId,
      'author_id': authorId,
      'author_name': authorName,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}