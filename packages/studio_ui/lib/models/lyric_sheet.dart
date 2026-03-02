class LyricSheet {
  LyricSheet({
    required this.id,
    required this.title,
    required this.content,
    this.createdAt,
  });

  factory LyricSheet.fromJson(Map<String, dynamic> json) => LyricSheet(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );

  final String id;
  final String title;
  final String content;
  final DateTime? createdAt;

  LyricSheet copyWith({String? title, String? content}) => LyricSheet(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
      );
}
