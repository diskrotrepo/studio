class TrainingMetrics {
  final int epoch;
  final int totalEpochs;
  final double trainLoss;
  final double? valLoss;
  final String? lr;
  final double? gradNormAvg;
  final double? gradNormMax;
  final double? nonPadPct;
  final double? trainTimeS;
  final double? valTimeS;
  final int? throughputTokS;
  final double? gpuMemGb;
  final String? phase;
  final double? perplexity;
  final double? lossDelta;
  final double? lossDeltaPct;
  final String? lossDirection;
  final double? trend5ep;
  final List<String> flags;

  const TrainingMetrics({
    required this.epoch,
    required this.totalEpochs,
    required this.trainLoss,
    this.valLoss,
    this.lr,
    this.gradNormAvg,
    this.gradNormMax,
    this.nonPadPct,
    this.trainTimeS,
    this.valTimeS,
    this.throughputTokS,
    this.gpuMemGb,
    this.phase,
    this.perplexity,
    this.lossDelta,
    this.lossDeltaPct,
    this.lossDirection,
    this.trend5ep,
    this.flags = const [],
  });

  factory TrainingMetrics.fromJson(Map<String, dynamic> json) {
    return TrainingMetrics(
      epoch: json['epoch'] as int,
      totalEpochs: json['total_epochs'] as int,
      trainLoss: (json['train_loss'] as num).toDouble(),
      valLoss: (json['val_loss'] as num?)?.toDouble(),
      lr: json['lr'] as String?,
      gradNormAvg: (json['grad_norm_avg'] as num?)?.toDouble(),
      gradNormMax: (json['grad_norm_max'] as num?)?.toDouble(),
      nonPadPct: (json['non_pad_pct'] as num?)?.toDouble(),
      trainTimeS: (json['train_time_s'] as num?)?.toDouble(),
      valTimeS: (json['val_time_s'] as num?)?.toDouble(),
      throughputTokS: json['throughput_tok_s'] as int?,
      gpuMemGb: (json['gpu_mem_gb'] as num?)?.toDouble(),
      phase: json['phase'] as String?,
      perplexity: (json['perplexity'] as num?)?.toDouble(),
      lossDelta: (json['loss_delta'] as num?)?.toDouble(),
      lossDeltaPct: (json['loss_delta_pct'] as num?)?.toDouble(),
      lossDirection: json['loss_direction'] as String?,
      trend5ep: (json['trend_5ep'] as num?)?.toDouble(),
      flags: (json['flags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  double get epochProgress => totalEpochs > 0 ? epoch / totalEpochs : 0.0;
}
