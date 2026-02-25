class BlockListEntry {
  final int? id;
  final String phoneNumber;
  final String? label;
  final DateTime createdAt;

  BlockListEntry({
    this.id,
    required this.phoneNumber,
    this.label,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'phone_number': phoneNumber,
        'label': label,
        'created_at': createdAt.toIso8601String(),
      };

  factory BlockListEntry.fromMap(Map<String, dynamic> map) => BlockListEntry(
        id: map['id'] as int?,
        phoneNumber: map['phone_number'] as String,
        label: map['label'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'phone_number': phoneNumber,
        'label': label,
        'created_at': createdAt.toIso8601String(),
      };

  factory BlockListEntry.fromJson(Map<String, dynamic> json) => BlockListEntry(
        phoneNumber: json['phone_number'] as String,
        label: json['label'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
