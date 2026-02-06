enum TagFieldType { text, date, select }

class TagTemplate {
  final String id;
  final String userId;
  final String name;
  final List<TagTemplateField> fields;
  final DateTime createdAt;

  const TagTemplate({
    required this.id,
    required this.userId,
    required this.name,
    required this.fields,
    required this.createdAt,
  });

  factory TagTemplate.fromJson(Map<String, dynamic> json) {
    return TagTemplate(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      fields: (json['fields'] as List<dynamic>?)
              ?.map((f) => TagTemplateField.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'fields': fields.map((f) => f.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class TagTemplateField {
  final String id;
  final String name;
  final TagFieldType type;
  final List<String>? options; // for select type
  final int sortOrder;

  const TagTemplateField({
    required this.id,
    required this.name,
    required this.type,
    this.options,
    this.sortOrder = 0,
  });

  factory TagTemplateField.fromJson(Map<String, dynamic> json) {
    return TagTemplateField(
      id: json['id'] as String,
      name: json['name'] as String,
      type: TagFieldType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TagFieldType.text,
      ),
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'options': options,
      'sort_order': sortOrder,
    };
  }
}

class ContextTag {
  final String id;
  final String cardId;
  final String? templateId;
  final Map<String, dynamic> values; // field_id -> value
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContextTag({
    required this.id,
    required this.cardId,
    this.templateId,
    required this.values,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContextTag.fromJson(Map<String, dynamic> json) {
    return ContextTag(
      id: json['id'] as String,
      cardId: json['card_id'] as String,
      templateId: json['template_id'] as String?,
      values: json['values'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'card_id': cardId,
      'template_id': templateId,
      'values': values,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
