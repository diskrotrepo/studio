class TaskStatus {
  TaskStatus({
    required this.taskId,
    required this.status,
    required this.taskType,
    this.result,
    this.error,
    this.prompt,
    this.model,
    this.title,
    this.lyrics,
    this.rating,
    this.lyricSheetId,
    this.createdAt,
    this.parameters,
  });

  factory TaskStatus.fromJson(Map<String, dynamic> json) => TaskStatus(
    taskId: json['task_id'] as String,
    status: json['status'] as String,
    taskType: json['task_type'] as String? ?? 'unknown',
    result: json['result'] as Map<String, dynamic>?,
    error: json['error'] as String?,
    model: json['model'] as String?,
    title: json['title'] as String?,
    rating: json['rating'] as int?,
  );

  factory TaskStatus.fromSongJson(Map<String, dynamic> json) => TaskStatus(
    taskId: json['task_id'] as String,
    status: json['status'] as String? ?? 'complete',
    taskType: json['task_type'] as String? ?? 'unknown',
    result: json['result'] as Map<String, dynamic>?,
    prompt: json['prompt'] as String?,
    model: json['model'] as String?,
    title: json['title'] as String?,
    lyrics: json['lyrics'] as String?,
    rating: json['rating'] as int?,
    lyricSheetId: json['lyric_sheet_id'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
    parameters: json['parameters'] as Map<String, dynamic>?,
  );

  final String taskId;
  final String status;
  final String taskType;
  final Map<String, dynamic>? result;
  final String? error;
  final String? prompt;
  final String? model;
  final String? title;
  final String? lyrics;
  final int? rating;
  final String? lyricSheetId;
  final DateTime? createdAt;
  final Map<String, dynamic>? parameters;

  bool get isProcessing => status == 'processing';
  bool get isUploading => status == 'uploading';
  bool get isComplete => status == 'complete';
  bool get isFailed => status == 'failed';

  /// Whether this task is still active and should be polled.
  bool get isActive => isProcessing || isUploading;

  TaskStatus copyWith({
    String? title,
    String? lyrics,
    bool clearLyrics = false,
    int? rating,
    bool clearRating = false,
    String? lyricSheetId,
    bool clearLyricSheetId = false,
    Map<String, dynamic>? parameters,
  }) =>
      TaskStatus(
        taskId: taskId,
        status: status,
        taskType: taskType,
        result: result,
        error: error,
        prompt: prompt,
        model: model,
        title: title ?? this.title,
        lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
        rating: clearRating ? null : (rating ?? this.rating),
        lyricSheetId: clearLyricSheetId
            ? null
            : (lyricSheetId ?? this.lyricSheetId),
        createdAt: createdAt,
        parameters: parameters ?? this.parameters,
      );
}
