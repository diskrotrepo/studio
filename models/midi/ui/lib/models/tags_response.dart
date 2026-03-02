class TagsResponse {
  final List<String> genres;
  final List<String> moods;
  final List<String> tempos;

  const TagsResponse({
    required this.genres,
    required this.moods,
    required this.tempos,
  });

  factory TagsResponse.fromJson(Map<String, dynamic> json) {
    return TagsResponse(
      genres: (json['genres'] as List<dynamic>?)?.cast<String>() ?? [],
      moods: (json['moods'] as List<dynamic>?)?.cast<String>() ?? [],
      tempos: (json['tempos'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  bool get isEmpty => genres.isEmpty && moods.isEmpty && tempos.isEmpty;
}
