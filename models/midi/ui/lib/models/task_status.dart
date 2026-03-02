import 'generation_params.dart';
import 'training_metrics.dart';
import 'training_summary.dart';

enum TaskState { pending, processing, complete, failed, unknown }

class TaskStatus {
  final String taskId;
  final TaskState status;
  final String? downloadUrl;
  final String? mp3DownloadUrl;
  final String? expiresAt;
  final String? error;

  // Progress info from backend
  final double? progress; // 0.0 - 1.0
  final String? message;
  final TrainingMetrics? metrics;
  final TrainingSummary? trainingSummary;
  final List<String>? outputLines;

  // Client-side metadata
  final DateTime submittedAt;
  final DateTime? completedAt;
  final String generationType;
  final String? tagsUsed;
  final GenerationParams? params;
  final bool hasBeenPlayed;
  final bool isFavorite;

  const TaskStatus({
    required this.taskId,
    required this.status,
    this.downloadUrl,
    this.mp3DownloadUrl,
    this.expiresAt,
    this.error,
    this.progress,
    this.message,
    this.metrics,
    this.trainingSummary,
    this.outputLines,
    required this.submittedAt,
    this.completedAt,
    required this.generationType,
    this.tagsUsed,
    this.params,
    this.hasBeenPlayed = false,
    this.isFavorite = false,
  });

  bool get isTerminal => status == TaskState.complete || status == TaskState.failed;

  factory TaskStatus.fromJson(
    Map<String, dynamic> json, {
    required DateTime submittedAt,
    required String generationType,
    String? tagsUsed,
    GenerationParams? params,
  }) {
    return TaskStatus(
      taskId: json['task_id'] as String,
      status: _parseState(json['status'] as String? ?? 'pending'),
      downloadUrl: json['download_url'] as String?,
      mp3DownloadUrl: json['mp3_download_url'] as String?,
      expiresAt: json['expires_at'] as String?,
      error: json['error'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      message: json['message'] as String?,
      submittedAt: submittedAt,
      generationType: generationType,
      tagsUsed: tagsUsed,
      params: params,
    );
  }

  TaskStatus withUpdate(Map<String, dynamic> json) {
    final newStatus = _parseState(json['status'] as String? ?? 'pending');
    final isNowTerminal =
        newStatus == TaskState.complete || newStatus == TaskState.failed;
    return TaskStatus(
      taskId: json['task_id'] as String,
      status: newStatus,
      downloadUrl: json['download_url'] as String?,
      mp3DownloadUrl: json['mp3_download_url'] as String?,
      expiresAt: json['expires_at'] as String?,
      error: json['error'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      message: json['message'] as String?,
      metrics: json['metrics'] != null
          ? TrainingMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : metrics,
      trainingSummary: json['training_summary'] != null
          ? TrainingSummary.fromJson(
              json['training_summary'] as Map<String, dynamic>)
          : trainingSummary,
      outputLines: json['output'] != null
          ? (json['output'] as List<dynamic>).cast<String>()
          : outputLines,
      submittedAt: submittedAt,
      completedAt: completedAt ?? (isNowTerminal ? DateTime.now() : null),
      generationType: generationType,
      tagsUsed: tagsUsed,
      params: params,
      hasBeenPlayed: hasBeenPlayed,
      isFavorite: isFavorite,
    );
  }

  TaskStatus copyWith({
    bool? hasBeenPlayed,
    bool? isFavorite,
    String? mp3DownloadUrl,
    TrainingSummary? trainingSummary,
  }) {
    return TaskStatus(
      taskId: taskId,
      status: status,
      downloadUrl: downloadUrl,
      mp3DownloadUrl: mp3DownloadUrl ?? this.mp3DownloadUrl,
      expiresAt: expiresAt,
      error: error,
      progress: progress,
      message: message,
      metrics: metrics,
      trainingSummary: trainingSummary ?? this.trainingSummary,
      outputLines: outputLines,
      submittedAt: submittedAt,
      completedAt: completedAt,
      generationType: generationType,
      tagsUsed: tagsUsed,
      params: params,
      hasBeenPlayed: hasBeenPlayed ?? this.hasBeenPlayed,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'status': status.name,
      'download_url': downloadUrl,
      'mp3_download_url': mp3DownloadUrl,
      'expires_at': expiresAt,
      'error': error,
      'progress': progress,
      'message': message,
      'submitted_at': submittedAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      'generation_type': generationType,
      'tags_used': tagsUsed,
      if (params != null) 'params': params!.toJson(),
      'has_been_played': hasBeenPlayed,
      'is_favorite': isFavorite,
    };
  }

  factory TaskStatus.fromPersistedJson(Map<String, dynamic> json) {
    return TaskStatus(
      taskId: json['task_id'] as String,
      status: _parseState(json['status'] as String? ?? 'unknown'),
      downloadUrl: json['download_url'] as String?,
      mp3DownloadUrl: json['mp3_download_url'] as String?,
      expiresAt: json['expires_at'] as String?,
      error: json['error'] as String?,
      progress: (json['progress'] as num?)?.toDouble(),
      message: json['message'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      generationType: json['generation_type'] as String,
      tagsUsed: json['tags_used'] as String?,
      params: json['params'] != null
          ? GenerationParams.fromJson(json['params'] as Map<String, dynamic>)
          : null,
      hasBeenPlayed: json['has_been_played'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  static TaskState _parseState(String s) {
    return switch (s) {
      'pending' => TaskState.pending,
      'processing' => TaskState.processing,
      'complete' => TaskState.complete,
      'failed' => TaskState.failed,
      _ => TaskState.unknown,
    };
  }
}
