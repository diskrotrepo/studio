class ModelCapabilities {
  ModelCapabilities({
    required this.model,
    required this.enabled,
    required this.taskTypes,
    required this.parameters,
    required this.features,
  });

  factory ModelCapabilities.fromJson(Map<String, dynamic> json) {
    return ModelCapabilities(
      model: json['model'] as String,
      enabled: json['enabled'] as bool? ?? true,
      taskTypes: (json['task_types'] as List<dynamic>).cast<String>(),
      parameters: (json['parameters'] as List<dynamic>).cast<String>(),
      features: (json['features'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as bool)),
    );
  }

  final String model;
  final bool enabled;
  final List<String> taskTypes;
  final List<String> parameters;
  final Map<String, bool> features;

  bool supportsTaskType(String taskType) => taskTypes.contains(taskType);
  bool supportsParameter(String param) => parameters.contains(param);
  bool hasFeature(String feature) => features[feature] ?? false;
}
