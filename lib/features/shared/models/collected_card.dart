class CollectedCard {
  final String id;
  final String userId;
  final String? name;
  final String? company;
  final String? position;
  final String? department;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? fax;
  final String? address;
  final String? website;
  final String? snsUrl;
  final String? memo;
  final String? imageUrl;
  final String? categoryId;
  final String? categoryName;
  final String? sourceCardId; // reference to original BusinessCard if shared
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollectedCard({
    required this.id,
    required this.userId,
    this.name,
    this.company,
    this.position,
    this.department,
    this.email,
    this.phone,
    this.mobile,
    this.fax,
    this.address,
    this.website,
    this.snsUrl,
    this.memo,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    this.sourceCardId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CollectedCard.fromJson(Map<String, dynamic> json) {
    return CollectedCard(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String?,
      company: json['company'] as String?,
      position: json['position'] as String?,
      department: json['department'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      mobile: json['mobile'] as String?,
      fax: json['fax'] as String?,
      address: json['address'] as String?,
      website: json['website'] as String?,
      snsUrl: json['sns_url'] as String?,
      memo: json['memo'] as String?,
      imageUrl: json['image_url'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      sourceCardId: json['source_card_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'name': name,
      'company': company,
      'position': position,
      'department': department,
      'email': email,
      'phone': phone,
      'mobile': mobile,
      'fax': fax,
      'address': address,
      'website': website,
      'sns_url': snsUrl,
      'memo': memo,
      'image_url': imageUrl,
      'category_id': categoryId,
      'source_card_id': sourceCardId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CollectedCard copyWith({
    String? id,
    String? userId,
    String? name,
    String? company,
    String? position,
    String? department,
    String? email,
    String? phone,
    String? mobile,
    String? fax,
    String? address,
    String? website,
    String? snsUrl,
    String? memo,
    String? imageUrl,
    String? categoryId,
    String? categoryName,
    String? sourceCardId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectedCard(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      company: company ?? this.company,
      position: position ?? this.position,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      fax: fax ?? this.fax,
      address: address ?? this.address,
      website: website ?? this.website,
      snsUrl: snsUrl ?? this.snsUrl,
      memo: memo ?? this.memo,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      sourceCardId: sourceCardId ?? this.sourceCardId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}