class HealthStatus {
  final String status;
  final bool modelLoaded;
  final String? device;
  final String? modelError;

  const HealthStatus({
    required this.status,
    required this.modelLoaded,
    this.device,
    this.modelError,
  });

  bool get isOk => status == 'ok' && modelLoaded;

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      modelLoaded: json['models_loaded'] as bool? ?? false,
      device: json['device'] as String?,
      modelError: json['model_error'] as String?,
    );
  }
}
