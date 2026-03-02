/// Summary of a completed training run, persisted as training_summary.json.
class TrainingSummary {
  final TrainingSummaryModel model;
  final TrainingSummaryTraining training;
  final TrainingSummaryDataset dataset;
  final TrainingSummaryResults results;
  final List<LossHistoryEntry> lossHistory;
  final TrainingSummaryArtifacts artifacts;
  final String? completedAt;

  const TrainingSummary({
    required this.model,
    required this.training,
    required this.dataset,
    required this.results,
    required this.lossHistory,
    required this.artifacts,
    this.completedAt,
  });

  factory TrainingSummary.fromJson(Map<String, dynamic> json) {
    return TrainingSummary(
      model: TrainingSummaryModel.fromJson(
          json['model'] as Map<String, dynamic>),
      training: TrainingSummaryTraining.fromJson(
          json['training'] as Map<String, dynamic>),
      dataset: TrainingSummaryDataset.fromJson(
          json['dataset'] as Map<String, dynamic>),
      results: TrainingSummaryResults.fromJson(
          json['results'] as Map<String, dynamic>),
      lossHistory: (json['loss_history'] as List<dynamic>?)
              ?.map(
                  (e) => LossHistoryEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      artifacts: TrainingSummaryArtifacts.fromJson(
          json['artifacts'] as Map<String, dynamic>),
      completedAt: json['completed_at'] as String?,
    );
  }
}

class TrainingSummaryModel {
  final String type;
  final int parametersTotal;
  final int parametersTrainable;
  final int dModel;
  final int nHeads;
  final int nLayers;
  final int seqLength;
  final int vocabSize;
  final double? dropout;

  const TrainingSummaryModel({
    required this.type,
    required this.parametersTotal,
    required this.parametersTrainable,
    required this.dModel,
    required this.nHeads,
    required this.nLayers,
    required this.seqLength,
    required this.vocabSize,
    this.dropout,
  });

  factory TrainingSummaryModel.fromJson(Map<String, dynamic> json) {
    return TrainingSummaryModel(
      type: json['type'] as String,
      parametersTotal: json['parameters_total'] as int,
      parametersTrainable: json['parameters_trainable'] as int,
      dModel: json['d_model'] as int,
      nHeads: json['n_heads'] as int,
      nLayers: json['n_layers'] as int,
      seqLength: json['seq_length'] as int,
      vocabSize: json['vocab_size'] as int,
      dropout: (json['dropout'] as num?)?.toDouble(),
    );
  }
}

class TrainingSummaryTraining {
  final String device;
  final int worldSize;
  final int batchSizePerGpu;
  final int gradientAccumulation;
  final int effectiveBatchSize;
  final double learningRate;
  final String scheduler;
  final double? weightDecay;
  final double? warmupPct;
  final LoraConfig? lora;
  final int? frozenLayers;

  const TrainingSummaryTraining({
    required this.device,
    required this.worldSize,
    required this.batchSizePerGpu,
    required this.gradientAccumulation,
    required this.effectiveBatchSize,
    required this.learningRate,
    required this.scheduler,
    this.weightDecay,
    this.warmupPct,
    this.lora,
    this.frozenLayers,
  });

  factory TrainingSummaryTraining.fromJson(Map<String, dynamic> json) {
    return TrainingSummaryTraining(
      device: json['device'] as String,
      worldSize: json['world_size'] as int,
      batchSizePerGpu: json['batch_size_per_gpu'] as int,
      gradientAccumulation: json['gradient_accumulation'] as int,
      effectiveBatchSize: json['effective_batch_size'] as int,
      learningRate: (json['learning_rate'] as num).toDouble(),
      scheduler: json['scheduler'] as String,
      weightDecay: (json['weight_decay'] as num?)?.toDouble(),
      warmupPct: (json['warmup_pct'] as num?)?.toDouble(),
      lora: json['lora'] != null
          ? LoraConfig.fromJson(json['lora'] as Map<String, dynamic>)
          : null,
      frozenLayers: json['frozen_layers'] as int?,
    );
  }
}

class LoraConfig {
  final int rank;
  final double alpha;

  const LoraConfig({required this.rank, required this.alpha});

  factory LoraConfig.fromJson(Map<String, dynamic> json) {
    return LoraConfig(
      rank: json['rank'] as int,
      alpha: (json['alpha'] as num).toDouble(),
    );
  }
}

class TrainingSummaryDataset {
  final int trainSamples;
  final int valSamples;
  final int totalSequences;
  final String mode;

  const TrainingSummaryDataset({
    required this.trainSamples,
    required this.valSamples,
    required this.totalSequences,
    required this.mode,
  });

  factory TrainingSummaryDataset.fromJson(Map<String, dynamic> json) {
    return TrainingSummaryDataset(
      trainSamples: json['train_samples'] as int,
      valSamples: json['val_samples'] as int,
      totalSequences: json['total_sequences'] as int,
      mode: json['mode'] as String,
    );
  }
}

class TrainingSummaryResults {
  final int epochsCompleted;
  final int epochsTotal;
  final bool earlyStopped;
  final double bestLoss;
  final int bestEpoch;
  final double? bestPerplexity;
  final double finalTrainLoss;
  final double? finalValLoss;
  final double? finalPerplexity;
  final double wallTimeSeconds;
  final double avgEpochTimeSeconds;
  final int avgThroughputTokS;

  const TrainingSummaryResults({
    required this.epochsCompleted,
    required this.epochsTotal,
    required this.earlyStopped,
    required this.bestLoss,
    required this.bestEpoch,
    this.bestPerplexity,
    required this.finalTrainLoss,
    this.finalValLoss,
    this.finalPerplexity,
    required this.wallTimeSeconds,
    required this.avgEpochTimeSeconds,
    required this.avgThroughputTokS,
  });

  factory TrainingSummaryResults.fromJson(Map<String, dynamic> json) {
    return TrainingSummaryResults(
      epochsCompleted: json['epochs_completed'] as int,
      epochsTotal: json['epochs_total'] as int,
      earlyStopped: json['early_stopped'] as bool,
      bestLoss: (json['best_loss'] as num).toDouble(),
      bestEpoch: json['best_epoch'] as int,
      bestPerplexity: (json['best_perplexity'] as num?)?.toDouble(),
      finalTrainLoss: (json['final_train_loss'] as num).toDouble(),
      finalValLoss: (json['final_val_loss'] as num?)?.toDouble(),
      finalPerplexity: (json['final_perplexity'] as num?)?.toDouble(),
      wallTimeSeconds: (json['wall_time_seconds'] as num).toDouble(),
      avgEpochTimeSeconds: (json['avg_epoch_time_seconds'] as num).toDouble(),
      avgThroughputTokS: json['avg_throughput_tok_s'] as int,
    );
  }
}

class LossHistoryEntry {
  final int epoch;
  final double trainLoss;
  final double? valLoss;

  const LossHistoryEntry({
    required this.epoch,
    required this.trainLoss,
    this.valLoss,
  });

  factory LossHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LossHistoryEntry(
      epoch: json['epoch'] as int,
      trainLoss: (json['train_loss'] as num).toDouble(),
      valLoss: (json['val_loss'] as num?)?.toDouble(),
    );
  }
}

class TrainingSummaryArtifacts {
  final String? bestModel;
  final String? stepLosses;

  const TrainingSummaryArtifacts({this.bestModel, this.stepLosses});

  factory TrainingSummaryArtifacts.fromJson(Map<String, dynamic> json) {
    return TrainingSummaryArtifacts(
      bestModel: json['best_model'] as String?,
      stepLosses: json['step_losses'] as String?,
    );
  }
}
