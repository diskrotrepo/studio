class Workspace {
  Workspace({
    required this.id,
    required this.name,
    required this.isDefault,
    this.createdAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        id: json['id'] as String,
        name: json['name'] as String,
        isDefault: json['is_default'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  final String id;
  final String name;
  final bool isDefault;
  final DateTime? createdAt;

  Workspace copyWith({String? name}) => Workspace(
        id: id,
        name: name ?? this.name,
        isDefault: isDefault,
        createdAt: createdAt,
      );
}
