// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UserTable extends User with TableInfo<$UserTable, UserEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => Uuid().v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<PgDateTime> createdAt =
      GeneratedColumn<PgDateTime>(
        'created_at',
        aliasedName,
        false,
        type: PgTypes.timestampNoTimezone,
        requiredDuringInsert: false,
        clientDefault: () => DateTimeExt(DateTime.now()).toPgDateTime(),
      );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, createdAt, userId, displayName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        PgTypes.timestampNoTimezone,
        data['${effectivePrefix}created_at'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
    );
  }

  @override
  $UserTable createAlias(String alias) {
    return $UserTable(attachedDatabase, alias);
  }
}

class UserEntity extends DataClass implements Insertable<UserEntity> {
  final String id;
  final PgDateTime createdAt;
  final String userId;
  final String displayName;
  const UserEntity({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.displayName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<PgDateTime>(
      createdAt,
      PgTypes.timestampNoTimezone,
    );
    map['user_id'] = Variable<String>(userId);
    map['display_name'] = Variable<String>(displayName);
    return map;
  }

  UserCompanion toCompanion(bool nullToAbsent) {
    return UserCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      userId: Value(userId),
      displayName: Value(displayName),
    );
  }

  factory UserEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserEntity(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<PgDateTime>(json['createdAt']),
      userId: serializer.fromJson<String>(json['userId']),
      displayName: serializer.fromJson<String>(json['displayName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<PgDateTime>(createdAt),
      'userId': serializer.toJson<String>(userId),
      'displayName': serializer.toJson<String>(displayName),
    };
  }

  UserEntity copyWith({
    String? id,
    PgDateTime? createdAt,
    String? userId,
    String? displayName,
  }) => UserEntity(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    userId: userId ?? this.userId,
    displayName: displayName ?? this.displayName,
  );
  UserEntity copyWithCompanion(UserCompanion data) {
    return UserEntity(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserEntity(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, userId, displayName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserEntity &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.userId == this.userId &&
          other.displayName == this.displayName);
}

class UserCompanion extends UpdateCompanion<UserEntity> {
  final Value<String> id;
  final Value<PgDateTime> createdAt;
  final Value<String> userId;
  final Value<String> displayName;
  final Value<int> rowid;
  const UserCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String userId,
    required String displayName,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       displayName = Value(displayName);
  static Insertable<UserEntity> custom({
    Expression<String>? id,
    Expression<PgDateTime>? createdAt,
    Expression<String>? userId,
    Expression<String>? displayName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (userId != null) 'user_id': userId,
      if (displayName != null) 'display_name': displayName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserCompanion copyWith({
    Value<String>? id,
    Value<PgDateTime>? createdAt,
    Value<String>? userId,
    Value<String>? displayName,
    Value<int>? rowid,
  }) {
    return UserCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<PgDateTime>(
        createdAt.value,
        PgTypes.timestampNoTimezone,
      );
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AudioGenerationTaskTable extends AudioGenerationTask
    with TableInfo<$AudioGenerationTaskTable, AudioGenerationTaskEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioGenerationTaskTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => Uuid().v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<PgDateTime> createdAt =
      GeneratedColumn<PgDateTime>(
        'created_at',
        aliasedName,
        false,
        type: PgTypes.timestampNoTimezone,
        requiredDuringInsert: false,
        clientDefault: () => DateTimeExt(DateTime.now()).toPgDateTime(),
      );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskTypeMeta = const VerificationMeta(
    'taskType',
  );
  @override
  late final GeneratedColumn<String> taskType = GeneratedColumn<String>(
    'task_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricsMeta = const VerificationMeta('lyrics');
  @override
  late final GeneratedColumn<String> lyrics = GeneratedColumn<String>(
    'lyrics',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _negativePromptMeta = const VerificationMeta(
    'negativePrompt',
  );
  @override
  late final GeneratedColumn<String> negativePrompt = GeneratedColumn<String>(
    'negative_prompt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _srcAudioPathMeta = const VerificationMeta(
    'srcAudioPath',
  );
  @override
  late final GeneratedColumn<String> srcAudioPath = GeneratedColumn<String>(
    'src_audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _infillStartMeta = const VerificationMeta(
    'infillStart',
  );
  @override
  late final GeneratedColumn<double> infillStart = GeneratedColumn<double>(
    'infill_start',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _infillEndMeta = const VerificationMeta(
    'infillEnd',
  );
  @override
  late final GeneratedColumn<double> infillEnd = GeneratedColumn<double>(
    'infill_end',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stemNameMeta = const VerificationMeta(
    'stemName',
  );
  @override
  late final GeneratedColumn<String> stemName = GeneratedColumn<String>(
    'stem_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackClassesMeta = const VerificationMeta(
    'trackClasses',
  );
  @override
  late final GeneratedColumn<String> trackClasses = GeneratedColumn<String>(
    'track_classes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thinkingMeta = const VerificationMeta(
    'thinking',
  );
  @override
  late final GeneratedColumn<bool> thinking = GeneratedColumn<bool>(
    'thinking',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("thinking" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
  );
  static const VerificationMeta _constrainedDecodingMeta =
      const VerificationMeta('constrainedDecoding');
  @override
  late final GeneratedColumn<bool> constrainedDecoding = GeneratedColumn<bool>(
    'constrained_decoding',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("constrained_decoding" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
  );
  static const VerificationMeta _guidanceScaleMeta = const VerificationMeta(
    'guidanceScale',
  );
  @override
  late final GeneratedColumn<double> guidanceScale = GeneratedColumn<double>(
    'guidance_scale',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inferMethodMeta = const VerificationMeta(
    'inferMethod',
  );
  @override
  late final GeneratedColumn<String> inferMethod = GeneratedColumn<String>(
    'infer_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inferenceStepsMeta = const VerificationMeta(
    'inferenceSteps',
  );
  @override
  late final GeneratedColumn<int> inferenceSteps = GeneratedColumn<int>(
    'inference_steps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cfgIntervalStartMeta = const VerificationMeta(
    'cfgIntervalStart',
  );
  @override
  late final GeneratedColumn<double> cfgIntervalStart = GeneratedColumn<double>(
    'cfg_interval_start',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cfgIntervalEndMeta = const VerificationMeta(
    'cfgIntervalEnd',
  );
  @override
  late final GeneratedColumn<double> cfgIntervalEnd = GeneratedColumn<double>(
    'cfg_interval_end',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shiftMeta = const VerificationMeta('shift');
  @override
  late final GeneratedColumn<double> shift = GeneratedColumn<double>(
    'shift',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeSignatureMeta = const VerificationMeta(
    'timeSignature',
  );
  @override
  late final GeneratedColumn<String> timeSignature = GeneratedColumn<String>(
    'time_signature',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _temperatureMeta = const VerificationMeta(
    'temperature',
  );
  @override
  late final GeneratedColumn<double> temperature = GeneratedColumn<double>(
    'temperature',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cfgScaleMeta = const VerificationMeta(
    'cfgScale',
  );
  @override
  late final GeneratedColumn<double> cfgScale = GeneratedColumn<double>(
    'cfg_scale',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topPMeta = const VerificationMeta('topP');
  @override
  late final GeneratedColumn<double> topP = GeneratedColumn<double>(
    'top_p',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repetitionPenaltyMeta = const VerificationMeta(
    'repetitionPenalty',
  );
  @override
  late final GeneratedColumn<double> repetitionPenalty =
      GeneratedColumn<double>(
        'repetition_penalty',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _audioDurationMeta = const VerificationMeta(
    'audioDuration',
  );
  @override
  late final GeneratedColumn<double> audioDuration = GeneratedColumn<double>(
    'audio_duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batchSizeMeta = const VerificationMeta(
    'batchSize',
  );
  @override
  late final GeneratedColumn<int> batchSize = GeneratedColumn<int>(
    'batch_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _useRandomSeedMeta = const VerificationMeta(
    'useRandomSeed',
  );
  @override
  late final GeneratedColumn<bool> useRandomSeed = GeneratedColumn<bool>(
    'use_random_seed',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("use_random_seed" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
  );
  static const VerificationMeta _audioFormatMeta = const VerificationMeta(
    'audioFormat',
  );
  @override
  late final GeneratedColumn<String> audioFormat = GeneratedColumn<String>(
    'audio_format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workspaceIdMeta = const VerificationMeta(
    'workspaceId',
  );
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
    'workspace_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricSheetIdMeta = const VerificationMeta(
    'lyricSheetId',
  );
  @override
  late final GeneratedColumn<String> lyricSheetId = GeneratedColumn<String>(
    'lyric_sheet_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<PgDateTime> completedAt =
      GeneratedColumn<PgDateTime>(
        'completed_at',
        aliasedName,
        true,
        type: PgTypes.timestampNoTimezone,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    userId,
    model,
    taskType,
    prompt,
    lyrics,
    negativePrompt,
    srcAudioPath,
    infillStart,
    infillEnd,
    stemName,
    trackClasses,
    thinking,
    constrainedDecoding,
    guidanceScale,
    inferMethod,
    inferenceSteps,
    cfgIntervalStart,
    cfgIntervalEnd,
    shift,
    timeSignature,
    temperature,
    cfgScale,
    topP,
    repetitionPenalty,
    audioDuration,
    batchSize,
    useRandomSeed,
    audioFormat,
    workspaceId,
    lyricSheetId,
    title,
    rating,
    taskId,
    status,
    result,
    error,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_generation_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioGenerationTaskEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('task_type')) {
      context.handle(
        _taskTypeMeta,
        taskType.isAcceptableOrUnknown(data['task_type']!, _taskTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_taskTypeMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    }
    if (data.containsKey('lyrics')) {
      context.handle(
        _lyricsMeta,
        lyrics.isAcceptableOrUnknown(data['lyrics']!, _lyricsMeta),
      );
    }
    if (data.containsKey('negative_prompt')) {
      context.handle(
        _negativePromptMeta,
        negativePrompt.isAcceptableOrUnknown(
          data['negative_prompt']!,
          _negativePromptMeta,
        ),
      );
    }
    if (data.containsKey('src_audio_path')) {
      context.handle(
        _srcAudioPathMeta,
        srcAudioPath.isAcceptableOrUnknown(
          data['src_audio_path']!,
          _srcAudioPathMeta,
        ),
      );
    }
    if (data.containsKey('infill_start')) {
      context.handle(
        _infillStartMeta,
        infillStart.isAcceptableOrUnknown(
          data['infill_start']!,
          _infillStartMeta,
        ),
      );
    }
    if (data.containsKey('infill_end')) {
      context.handle(
        _infillEndMeta,
        infillEnd.isAcceptableOrUnknown(data['infill_end']!, _infillEndMeta),
      );
    }
    if (data.containsKey('stem_name')) {
      context.handle(
        _stemNameMeta,
        stemName.isAcceptableOrUnknown(data['stem_name']!, _stemNameMeta),
      );
    }
    if (data.containsKey('track_classes')) {
      context.handle(
        _trackClassesMeta,
        trackClasses.isAcceptableOrUnknown(
          data['track_classes']!,
          _trackClassesMeta,
        ),
      );
    }
    if (data.containsKey('thinking')) {
      context.handle(
        _thinkingMeta,
        thinking.isAcceptableOrUnknown(data['thinking']!, _thinkingMeta),
      );
    }
    if (data.containsKey('constrained_decoding')) {
      context.handle(
        _constrainedDecodingMeta,
        constrainedDecoding.isAcceptableOrUnknown(
          data['constrained_decoding']!,
          _constrainedDecodingMeta,
        ),
      );
    }
    if (data.containsKey('guidance_scale')) {
      context.handle(
        _guidanceScaleMeta,
        guidanceScale.isAcceptableOrUnknown(
          data['guidance_scale']!,
          _guidanceScaleMeta,
        ),
      );
    }
    if (data.containsKey('infer_method')) {
      context.handle(
        _inferMethodMeta,
        inferMethod.isAcceptableOrUnknown(
          data['infer_method']!,
          _inferMethodMeta,
        ),
      );
    }
    if (data.containsKey('inference_steps')) {
      context.handle(
        _inferenceStepsMeta,
        inferenceSteps.isAcceptableOrUnknown(
          data['inference_steps']!,
          _inferenceStepsMeta,
        ),
      );
    }
    if (data.containsKey('cfg_interval_start')) {
      context.handle(
        _cfgIntervalStartMeta,
        cfgIntervalStart.isAcceptableOrUnknown(
          data['cfg_interval_start']!,
          _cfgIntervalStartMeta,
        ),
      );
    }
    if (data.containsKey('cfg_interval_end')) {
      context.handle(
        _cfgIntervalEndMeta,
        cfgIntervalEnd.isAcceptableOrUnknown(
          data['cfg_interval_end']!,
          _cfgIntervalEndMeta,
        ),
      );
    }
    if (data.containsKey('shift')) {
      context.handle(
        _shiftMeta,
        shift.isAcceptableOrUnknown(data['shift']!, _shiftMeta),
      );
    }
    if (data.containsKey('time_signature')) {
      context.handle(
        _timeSignatureMeta,
        timeSignature.isAcceptableOrUnknown(
          data['time_signature']!,
          _timeSignatureMeta,
        ),
      );
    }
    if (data.containsKey('temperature')) {
      context.handle(
        _temperatureMeta,
        temperature.isAcceptableOrUnknown(
          data['temperature']!,
          _temperatureMeta,
        ),
      );
    }
    if (data.containsKey('cfg_scale')) {
      context.handle(
        _cfgScaleMeta,
        cfgScale.isAcceptableOrUnknown(data['cfg_scale']!, _cfgScaleMeta),
      );
    }
    if (data.containsKey('top_p')) {
      context.handle(
        _topPMeta,
        topP.isAcceptableOrUnknown(data['top_p']!, _topPMeta),
      );
    }
    if (data.containsKey('repetition_penalty')) {
      context.handle(
        _repetitionPenaltyMeta,
        repetitionPenalty.isAcceptableOrUnknown(
          data['repetition_penalty']!,
          _repetitionPenaltyMeta,
        ),
      );
    }
    if (data.containsKey('audio_duration')) {
      context.handle(
        _audioDurationMeta,
        audioDuration.isAcceptableOrUnknown(
          data['audio_duration']!,
          _audioDurationMeta,
        ),
      );
    }
    if (data.containsKey('batch_size')) {
      context.handle(
        _batchSizeMeta,
        batchSize.isAcceptableOrUnknown(data['batch_size']!, _batchSizeMeta),
      );
    }
    if (data.containsKey('use_random_seed')) {
      context.handle(
        _useRandomSeedMeta,
        useRandomSeed.isAcceptableOrUnknown(
          data['use_random_seed']!,
          _useRandomSeedMeta,
        ),
      );
    }
    if (data.containsKey('audio_format')) {
      context.handle(
        _audioFormatMeta,
        audioFormat.isAcceptableOrUnknown(
          data['audio_format']!,
          _audioFormatMeta,
        ),
      );
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
        _workspaceIdMeta,
        workspaceId.isAcceptableOrUnknown(
          data['workspace_id']!,
          _workspaceIdMeta,
        ),
      );
    }
    if (data.containsKey('lyric_sheet_id')) {
      context.handle(
        _lyricSheetIdMeta,
        lyricSheetId.isAcceptableOrUnknown(
          data['lyric_sheet_id']!,
          _lyricSheetIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AudioGenerationTaskEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioGenerationTaskEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        PgTypes.timestampNoTimezone,
        data['${effectivePrefix}created_at'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      taskType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_type'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      ),
      lyrics: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics'],
      ),
      negativePrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}negative_prompt'],
      ),
      srcAudioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}src_audio_path'],
      ),
      infillStart: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}infill_start'],
      ),
      infillEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}infill_end'],
      ),
      stemName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stem_name'],
      ),
      trackClasses: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_classes'],
      ),
      thinking: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}thinking'],
      ),
      constrainedDecoding: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}constrained_decoding'],
      ),
      guidanceScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}guidance_scale'],
      ),
      inferMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}infer_method'],
      ),
      inferenceSteps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}inference_steps'],
      ),
      cfgIntervalStart: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cfg_interval_start'],
      ),
      cfgIntervalEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cfg_interval_end'],
      ),
      shift: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}shift'],
      ),
      timeSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_signature'],
      ),
      temperature: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature'],
      ),
      cfgScale: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cfg_scale'],
      ),
      topP: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}top_p'],
      ),
      repetitionPenalty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}repetition_penalty'],
      ),
      audioDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}audio_duration'],
      ),
      batchSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}batch_size'],
      ),
      useRandomSeed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_random_seed'],
      ),
      audioFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_format'],
      ),
      workspaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workspace_id'],
      ),
      lyricSheetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyric_sheet_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        PgTypes.timestampNoTimezone,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $AudioGenerationTaskTable createAlias(String alias) {
    return $AudioGenerationTaskTable(attachedDatabase, alias);
  }
}

class AudioGenerationTaskEntity extends DataClass
    implements Insertable<AudioGenerationTaskEntity> {
  final String id;
  final PgDateTime createdAt;
  final String userId;
  final String model;
  final String taskType;
  final String? prompt;
  final String? lyrics;
  final String? negativePrompt;
  final String? srcAudioPath;
  final double? infillStart;
  final double? infillEnd;
  final String? stemName;
  final String? trackClasses;
  final bool? thinking;
  final bool? constrainedDecoding;
  final double? guidanceScale;
  final String? inferMethod;
  final int? inferenceSteps;
  final double? cfgIntervalStart;
  final double? cfgIntervalEnd;
  final double? shift;
  final String? timeSignature;
  final double? temperature;
  final double? cfgScale;
  final double? topP;
  final double? repetitionPenalty;
  final double? audioDuration;
  final int? batchSize;
  final bool? useRandomSeed;
  final String? audioFormat;
  final String? workspaceId;
  final String? lyricSheetId;
  final String? title;
  final int? rating;
  final String taskId;
  final String status;
  final String? result;
  final String? error;
  final PgDateTime? completedAt;
  const AudioGenerationTaskEntity({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.model,
    required this.taskType,
    this.prompt,
    this.lyrics,
    this.negativePrompt,
    this.srcAudioPath,
    this.infillStart,
    this.infillEnd,
    this.stemName,
    this.trackClasses,
    this.thinking,
    this.constrainedDecoding,
    this.guidanceScale,
    this.inferMethod,
    this.inferenceSteps,
    this.cfgIntervalStart,
    this.cfgIntervalEnd,
    this.shift,
    this.timeSignature,
    this.temperature,
    this.cfgScale,
    this.topP,
    this.repetitionPenalty,
    this.audioDuration,
    this.batchSize,
    this.useRandomSeed,
    this.audioFormat,
    this.workspaceId,
    this.lyricSheetId,
    this.title,
    this.rating,
    required this.taskId,
    required this.status,
    this.result,
    this.error,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<PgDateTime>(
      createdAt,
      PgTypes.timestampNoTimezone,
    );
    map['user_id'] = Variable<String>(userId);
    map['model'] = Variable<String>(model);
    map['task_type'] = Variable<String>(taskType);
    if (!nullToAbsent || prompt != null) {
      map['prompt'] = Variable<String>(prompt);
    }
    if (!nullToAbsent || lyrics != null) {
      map['lyrics'] = Variable<String>(lyrics);
    }
    if (!nullToAbsent || negativePrompt != null) {
      map['negative_prompt'] = Variable<String>(negativePrompt);
    }
    if (!nullToAbsent || srcAudioPath != null) {
      map['src_audio_path'] = Variable<String>(srcAudioPath);
    }
    if (!nullToAbsent || infillStart != null) {
      map['infill_start'] = Variable<double>(infillStart);
    }
    if (!nullToAbsent || infillEnd != null) {
      map['infill_end'] = Variable<double>(infillEnd);
    }
    if (!nullToAbsent || stemName != null) {
      map['stem_name'] = Variable<String>(stemName);
    }
    if (!nullToAbsent || trackClasses != null) {
      map['track_classes'] = Variable<String>(trackClasses);
    }
    if (!nullToAbsent || thinking != null) {
      map['thinking'] = Variable<bool>(thinking);
    }
    if (!nullToAbsent || constrainedDecoding != null) {
      map['constrained_decoding'] = Variable<bool>(constrainedDecoding);
    }
    if (!nullToAbsent || guidanceScale != null) {
      map['guidance_scale'] = Variable<double>(guidanceScale);
    }
    if (!nullToAbsent || inferMethod != null) {
      map['infer_method'] = Variable<String>(inferMethod);
    }
    if (!nullToAbsent || inferenceSteps != null) {
      map['inference_steps'] = Variable<int>(inferenceSteps);
    }
    if (!nullToAbsent || cfgIntervalStart != null) {
      map['cfg_interval_start'] = Variable<double>(cfgIntervalStart);
    }
    if (!nullToAbsent || cfgIntervalEnd != null) {
      map['cfg_interval_end'] = Variable<double>(cfgIntervalEnd);
    }
    if (!nullToAbsent || shift != null) {
      map['shift'] = Variable<double>(shift);
    }
    if (!nullToAbsent || timeSignature != null) {
      map['time_signature'] = Variable<String>(timeSignature);
    }
    if (!nullToAbsent || temperature != null) {
      map['temperature'] = Variable<double>(temperature);
    }
    if (!nullToAbsent || cfgScale != null) {
      map['cfg_scale'] = Variable<double>(cfgScale);
    }
    if (!nullToAbsent || topP != null) {
      map['top_p'] = Variable<double>(topP);
    }
    if (!nullToAbsent || repetitionPenalty != null) {
      map['repetition_penalty'] = Variable<double>(repetitionPenalty);
    }
    if (!nullToAbsent || audioDuration != null) {
      map['audio_duration'] = Variable<double>(audioDuration);
    }
    if (!nullToAbsent || batchSize != null) {
      map['batch_size'] = Variable<int>(batchSize);
    }
    if (!nullToAbsent || useRandomSeed != null) {
      map['use_random_seed'] = Variable<bool>(useRandomSeed);
    }
    if (!nullToAbsent || audioFormat != null) {
      map['audio_format'] = Variable<String>(audioFormat);
    }
    if (!nullToAbsent || workspaceId != null) {
      map['workspace_id'] = Variable<String>(workspaceId);
    }
    if (!nullToAbsent || lyricSheetId != null) {
      map['lyric_sheet_id'] = Variable<String>(lyricSheetId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    map['task_id'] = Variable<String>(taskId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<PgDateTime>(
        completedAt,
        PgTypes.timestampNoTimezone,
      );
    }
    return map;
  }

  AudioGenerationTaskCompanion toCompanion(bool nullToAbsent) {
    return AudioGenerationTaskCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      userId: Value(userId),
      model: Value(model),
      taskType: Value(taskType),
      prompt: prompt == null && nullToAbsent
          ? const Value.absent()
          : Value(prompt),
      lyrics: lyrics == null && nullToAbsent
          ? const Value.absent()
          : Value(lyrics),
      negativePrompt: negativePrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(negativePrompt),
      srcAudioPath: srcAudioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(srcAudioPath),
      infillStart: infillStart == null && nullToAbsent
          ? const Value.absent()
          : Value(infillStart),
      infillEnd: infillEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(infillEnd),
      stemName: stemName == null && nullToAbsent
          ? const Value.absent()
          : Value(stemName),
      trackClasses: trackClasses == null && nullToAbsent
          ? const Value.absent()
          : Value(trackClasses),
      thinking: thinking == null && nullToAbsent
          ? const Value.absent()
          : Value(thinking),
      constrainedDecoding: constrainedDecoding == null && nullToAbsent
          ? const Value.absent()
          : Value(constrainedDecoding),
      guidanceScale: guidanceScale == null && nullToAbsent
          ? const Value.absent()
          : Value(guidanceScale),
      inferMethod: inferMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(inferMethod),
      inferenceSteps: inferenceSteps == null && nullToAbsent
          ? const Value.absent()
          : Value(inferenceSteps),
      cfgIntervalStart: cfgIntervalStart == null && nullToAbsent
          ? const Value.absent()
          : Value(cfgIntervalStart),
      cfgIntervalEnd: cfgIntervalEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(cfgIntervalEnd),
      shift: shift == null && nullToAbsent
          ? const Value.absent()
          : Value(shift),
      timeSignature: timeSignature == null && nullToAbsent
          ? const Value.absent()
          : Value(timeSignature),
      temperature: temperature == null && nullToAbsent
          ? const Value.absent()
          : Value(temperature),
      cfgScale: cfgScale == null && nullToAbsent
          ? const Value.absent()
          : Value(cfgScale),
      topP: topP == null && nullToAbsent ? const Value.absent() : Value(topP),
      repetitionPenalty: repetitionPenalty == null && nullToAbsent
          ? const Value.absent()
          : Value(repetitionPenalty),
      audioDuration: audioDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(audioDuration),
      batchSize: batchSize == null && nullToAbsent
          ? const Value.absent()
          : Value(batchSize),
      useRandomSeed: useRandomSeed == null && nullToAbsent
          ? const Value.absent()
          : Value(useRandomSeed),
      audioFormat: audioFormat == null && nullToAbsent
          ? const Value.absent()
          : Value(audioFormat),
      workspaceId: workspaceId == null && nullToAbsent
          ? const Value.absent()
          : Value(workspaceId),
      lyricSheetId: lyricSheetId == null && nullToAbsent
          ? const Value.absent()
          : Value(lyricSheetId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      taskId: Value(taskId),
      status: Value(status),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory AudioGenerationTaskEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioGenerationTaskEntity(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<PgDateTime>(json['createdAt']),
      userId: serializer.fromJson<String>(json['userId']),
      model: serializer.fromJson<String>(json['model']),
      taskType: serializer.fromJson<String>(json['taskType']),
      prompt: serializer.fromJson<String?>(json['prompt']),
      lyrics: serializer.fromJson<String?>(json['lyrics']),
      negativePrompt: serializer.fromJson<String?>(json['negativePrompt']),
      srcAudioPath: serializer.fromJson<String?>(json['srcAudioPath']),
      infillStart: serializer.fromJson<double?>(json['infillStart']),
      infillEnd: serializer.fromJson<double?>(json['infillEnd']),
      stemName: serializer.fromJson<String?>(json['stemName']),
      trackClasses: serializer.fromJson<String?>(json['trackClasses']),
      thinking: serializer.fromJson<bool?>(json['thinking']),
      constrainedDecoding: serializer.fromJson<bool?>(
        json['constrainedDecoding'],
      ),
      guidanceScale: serializer.fromJson<double?>(json['guidanceScale']),
      inferMethod: serializer.fromJson<String?>(json['inferMethod']),
      inferenceSteps: serializer.fromJson<int?>(json['inferenceSteps']),
      cfgIntervalStart: serializer.fromJson<double?>(json['cfgIntervalStart']),
      cfgIntervalEnd: serializer.fromJson<double?>(json['cfgIntervalEnd']),
      shift: serializer.fromJson<double?>(json['shift']),
      timeSignature: serializer.fromJson<String?>(json['timeSignature']),
      temperature: serializer.fromJson<double?>(json['temperature']),
      cfgScale: serializer.fromJson<double?>(json['cfgScale']),
      topP: serializer.fromJson<double?>(json['topP']),
      repetitionPenalty: serializer.fromJson<double?>(
        json['repetitionPenalty'],
      ),
      audioDuration: serializer.fromJson<double?>(json['audioDuration']),
      batchSize: serializer.fromJson<int?>(json['batchSize']),
      useRandomSeed: serializer.fromJson<bool?>(json['useRandomSeed']),
      audioFormat: serializer.fromJson<String?>(json['audioFormat']),
      workspaceId: serializer.fromJson<String?>(json['workspaceId']),
      lyricSheetId: serializer.fromJson<String?>(json['lyricSheetId']),
      title: serializer.fromJson<String?>(json['title']),
      rating: serializer.fromJson<int?>(json['rating']),
      taskId: serializer.fromJson<String>(json['taskId']),
      status: serializer.fromJson<String>(json['status']),
      result: serializer.fromJson<String?>(json['result']),
      error: serializer.fromJson<String?>(json['error']),
      completedAt: serializer.fromJson<PgDateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<PgDateTime>(createdAt),
      'userId': serializer.toJson<String>(userId),
      'model': serializer.toJson<String>(model),
      'taskType': serializer.toJson<String>(taskType),
      'prompt': serializer.toJson<String?>(prompt),
      'lyrics': serializer.toJson<String?>(lyrics),
      'negativePrompt': serializer.toJson<String?>(negativePrompt),
      'srcAudioPath': serializer.toJson<String?>(srcAudioPath),
      'infillStart': serializer.toJson<double?>(infillStart),
      'infillEnd': serializer.toJson<double?>(infillEnd),
      'stemName': serializer.toJson<String?>(stemName),
      'trackClasses': serializer.toJson<String?>(trackClasses),
      'thinking': serializer.toJson<bool?>(thinking),
      'constrainedDecoding': serializer.toJson<bool?>(constrainedDecoding),
      'guidanceScale': serializer.toJson<double?>(guidanceScale),
      'inferMethod': serializer.toJson<String?>(inferMethod),
      'inferenceSteps': serializer.toJson<int?>(inferenceSteps),
      'cfgIntervalStart': serializer.toJson<double?>(cfgIntervalStart),
      'cfgIntervalEnd': serializer.toJson<double?>(cfgIntervalEnd),
      'shift': serializer.toJson<double?>(shift),
      'timeSignature': serializer.toJson<String?>(timeSignature),
      'temperature': serializer.toJson<double?>(temperature),
      'cfgScale': serializer.toJson<double?>(cfgScale),
      'topP': serializer.toJson<double?>(topP),
      'repetitionPenalty': serializer.toJson<double?>(repetitionPenalty),
      'audioDuration': serializer.toJson<double?>(audioDuration),
      'batchSize': serializer.toJson<int?>(batchSize),
      'useRandomSeed': serializer.toJson<bool?>(useRandomSeed),
      'audioFormat': serializer.toJson<String?>(audioFormat),
      'workspaceId': serializer.toJson<String?>(workspaceId),
      'lyricSheetId': serializer.toJson<String?>(lyricSheetId),
      'title': serializer.toJson<String?>(title),
      'rating': serializer.toJson<int?>(rating),
      'taskId': serializer.toJson<String>(taskId),
      'status': serializer.toJson<String>(status),
      'result': serializer.toJson<String?>(result),
      'error': serializer.toJson<String?>(error),
      'completedAt': serializer.toJson<PgDateTime?>(completedAt),
    };
  }

  AudioGenerationTaskEntity copyWith({
    String? id,
    PgDateTime? createdAt,
    String? userId,
    String? model,
    String? taskType,
    Value<String?> prompt = const Value.absent(),
    Value<String?> lyrics = const Value.absent(),
    Value<String?> negativePrompt = const Value.absent(),
    Value<String?> srcAudioPath = const Value.absent(),
    Value<double?> infillStart = const Value.absent(),
    Value<double?> infillEnd = const Value.absent(),
    Value<String?> stemName = const Value.absent(),
    Value<String?> trackClasses = const Value.absent(),
    Value<bool?> thinking = const Value.absent(),
    Value<bool?> constrainedDecoding = const Value.absent(),
    Value<double?> guidanceScale = const Value.absent(),
    Value<String?> inferMethod = const Value.absent(),
    Value<int?> inferenceSteps = const Value.absent(),
    Value<double?> cfgIntervalStart = const Value.absent(),
    Value<double?> cfgIntervalEnd = const Value.absent(),
    Value<double?> shift = const Value.absent(),
    Value<String?> timeSignature = const Value.absent(),
    Value<double?> temperature = const Value.absent(),
    Value<double?> cfgScale = const Value.absent(),
    Value<double?> topP = const Value.absent(),
    Value<double?> repetitionPenalty = const Value.absent(),
    Value<double?> audioDuration = const Value.absent(),
    Value<int?> batchSize = const Value.absent(),
    Value<bool?> useRandomSeed = const Value.absent(),
    Value<String?> audioFormat = const Value.absent(),
    Value<String?> workspaceId = const Value.absent(),
    Value<String?> lyricSheetId = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<int?> rating = const Value.absent(),
    String? taskId,
    String? status,
    Value<String?> result = const Value.absent(),
    Value<String?> error = const Value.absent(),
    Value<PgDateTime?> completedAt = const Value.absent(),
  }) => AudioGenerationTaskEntity(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    userId: userId ?? this.userId,
    model: model ?? this.model,
    taskType: taskType ?? this.taskType,
    prompt: prompt.present ? prompt.value : this.prompt,
    lyrics: lyrics.present ? lyrics.value : this.lyrics,
    negativePrompt: negativePrompt.present
        ? negativePrompt.value
        : this.negativePrompt,
    srcAudioPath: srcAudioPath.present ? srcAudioPath.value : this.srcAudioPath,
    infillStart: infillStart.present ? infillStart.value : this.infillStart,
    infillEnd: infillEnd.present ? infillEnd.value : this.infillEnd,
    stemName: stemName.present ? stemName.value : this.stemName,
    trackClasses: trackClasses.present ? trackClasses.value : this.trackClasses,
    thinking: thinking.present ? thinking.value : this.thinking,
    constrainedDecoding: constrainedDecoding.present
        ? constrainedDecoding.value
        : this.constrainedDecoding,
    guidanceScale: guidanceScale.present
        ? guidanceScale.value
        : this.guidanceScale,
    inferMethod: inferMethod.present ? inferMethod.value : this.inferMethod,
    inferenceSteps: inferenceSteps.present
        ? inferenceSteps.value
        : this.inferenceSteps,
    cfgIntervalStart: cfgIntervalStart.present
        ? cfgIntervalStart.value
        : this.cfgIntervalStart,
    cfgIntervalEnd: cfgIntervalEnd.present
        ? cfgIntervalEnd.value
        : this.cfgIntervalEnd,
    shift: shift.present ? shift.value : this.shift,
    timeSignature: timeSignature.present
        ? timeSignature.value
        : this.timeSignature,
    temperature: temperature.present ? temperature.value : this.temperature,
    cfgScale: cfgScale.present ? cfgScale.value : this.cfgScale,
    topP: topP.present ? topP.value : this.topP,
    repetitionPenalty: repetitionPenalty.present
        ? repetitionPenalty.value
        : this.repetitionPenalty,
    audioDuration: audioDuration.present
        ? audioDuration.value
        : this.audioDuration,
    batchSize: batchSize.present ? batchSize.value : this.batchSize,
    useRandomSeed: useRandomSeed.present
        ? useRandomSeed.value
        : this.useRandomSeed,
    audioFormat: audioFormat.present ? audioFormat.value : this.audioFormat,
    workspaceId: workspaceId.present ? workspaceId.value : this.workspaceId,
    lyricSheetId: lyricSheetId.present ? lyricSheetId.value : this.lyricSheetId,
    title: title.present ? title.value : this.title,
    rating: rating.present ? rating.value : this.rating,
    taskId: taskId ?? this.taskId,
    status: status ?? this.status,
    result: result.present ? result.value : this.result,
    error: error.present ? error.value : this.error,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  AudioGenerationTaskEntity copyWithCompanion(
    AudioGenerationTaskCompanion data,
  ) {
    return AudioGenerationTaskEntity(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      model: data.model.present ? data.model.value : this.model,
      taskType: data.taskType.present ? data.taskType.value : this.taskType,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      lyrics: data.lyrics.present ? data.lyrics.value : this.lyrics,
      negativePrompt: data.negativePrompt.present
          ? data.negativePrompt.value
          : this.negativePrompt,
      srcAudioPath: data.srcAudioPath.present
          ? data.srcAudioPath.value
          : this.srcAudioPath,
      infillStart: data.infillStart.present
          ? data.infillStart.value
          : this.infillStart,
      infillEnd: data.infillEnd.present ? data.infillEnd.value : this.infillEnd,
      stemName: data.stemName.present ? data.stemName.value : this.stemName,
      trackClasses: data.trackClasses.present
          ? data.trackClasses.value
          : this.trackClasses,
      thinking: data.thinking.present ? data.thinking.value : this.thinking,
      constrainedDecoding: data.constrainedDecoding.present
          ? data.constrainedDecoding.value
          : this.constrainedDecoding,
      guidanceScale: data.guidanceScale.present
          ? data.guidanceScale.value
          : this.guidanceScale,
      inferMethod: data.inferMethod.present
          ? data.inferMethod.value
          : this.inferMethod,
      inferenceSteps: data.inferenceSteps.present
          ? data.inferenceSteps.value
          : this.inferenceSteps,
      cfgIntervalStart: data.cfgIntervalStart.present
          ? data.cfgIntervalStart.value
          : this.cfgIntervalStart,
      cfgIntervalEnd: data.cfgIntervalEnd.present
          ? data.cfgIntervalEnd.value
          : this.cfgIntervalEnd,
      shift: data.shift.present ? data.shift.value : this.shift,
      timeSignature: data.timeSignature.present
          ? data.timeSignature.value
          : this.timeSignature,
      temperature: data.temperature.present
          ? data.temperature.value
          : this.temperature,
      cfgScale: data.cfgScale.present ? data.cfgScale.value : this.cfgScale,
      topP: data.topP.present ? data.topP.value : this.topP,
      repetitionPenalty: data.repetitionPenalty.present
          ? data.repetitionPenalty.value
          : this.repetitionPenalty,
      audioDuration: data.audioDuration.present
          ? data.audioDuration.value
          : this.audioDuration,
      batchSize: data.batchSize.present ? data.batchSize.value : this.batchSize,
      useRandomSeed: data.useRandomSeed.present
          ? data.useRandomSeed.value
          : this.useRandomSeed,
      audioFormat: data.audioFormat.present
          ? data.audioFormat.value
          : this.audioFormat,
      workspaceId: data.workspaceId.present
          ? data.workspaceId.value
          : this.workspaceId,
      lyricSheetId: data.lyricSheetId.present
          ? data.lyricSheetId.value
          : this.lyricSheetId,
      title: data.title.present ? data.title.value : this.title,
      rating: data.rating.present ? data.rating.value : this.rating,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      status: data.status.present ? data.status.value : this.status,
      result: data.result.present ? data.result.value : this.result,
      error: data.error.present ? data.error.value : this.error,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioGenerationTaskEntity(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('model: $model, ')
          ..write('taskType: $taskType, ')
          ..write('prompt: $prompt, ')
          ..write('lyrics: $lyrics, ')
          ..write('negativePrompt: $negativePrompt, ')
          ..write('srcAudioPath: $srcAudioPath, ')
          ..write('infillStart: $infillStart, ')
          ..write('infillEnd: $infillEnd, ')
          ..write('stemName: $stemName, ')
          ..write('trackClasses: $trackClasses, ')
          ..write('thinking: $thinking, ')
          ..write('constrainedDecoding: $constrainedDecoding, ')
          ..write('guidanceScale: $guidanceScale, ')
          ..write('inferMethod: $inferMethod, ')
          ..write('inferenceSteps: $inferenceSteps, ')
          ..write('cfgIntervalStart: $cfgIntervalStart, ')
          ..write('cfgIntervalEnd: $cfgIntervalEnd, ')
          ..write('shift: $shift, ')
          ..write('timeSignature: $timeSignature, ')
          ..write('temperature: $temperature, ')
          ..write('cfgScale: $cfgScale, ')
          ..write('topP: $topP, ')
          ..write('repetitionPenalty: $repetitionPenalty, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('batchSize: $batchSize, ')
          ..write('useRandomSeed: $useRandomSeed, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('lyricSheetId: $lyricSheetId, ')
          ..write('title: $title, ')
          ..write('rating: $rating, ')
          ..write('taskId: $taskId, ')
          ..write('status: $status, ')
          ..write('result: $result, ')
          ..write('error: $error, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    createdAt,
    userId,
    model,
    taskType,
    prompt,
    lyrics,
    negativePrompt,
    srcAudioPath,
    infillStart,
    infillEnd,
    stemName,
    trackClasses,
    thinking,
    constrainedDecoding,
    guidanceScale,
    inferMethod,
    inferenceSteps,
    cfgIntervalStart,
    cfgIntervalEnd,
    shift,
    timeSignature,
    temperature,
    cfgScale,
    topP,
    repetitionPenalty,
    audioDuration,
    batchSize,
    useRandomSeed,
    audioFormat,
    workspaceId,
    lyricSheetId,
    title,
    rating,
    taskId,
    status,
    result,
    error,
    completedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioGenerationTaskEntity &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.userId == this.userId &&
          other.model == this.model &&
          other.taskType == this.taskType &&
          other.prompt == this.prompt &&
          other.lyrics == this.lyrics &&
          other.negativePrompt == this.negativePrompt &&
          other.srcAudioPath == this.srcAudioPath &&
          other.infillStart == this.infillStart &&
          other.infillEnd == this.infillEnd &&
          other.stemName == this.stemName &&
          other.trackClasses == this.trackClasses &&
          other.thinking == this.thinking &&
          other.constrainedDecoding == this.constrainedDecoding &&
          other.guidanceScale == this.guidanceScale &&
          other.inferMethod == this.inferMethod &&
          other.inferenceSteps == this.inferenceSteps &&
          other.cfgIntervalStart == this.cfgIntervalStart &&
          other.cfgIntervalEnd == this.cfgIntervalEnd &&
          other.shift == this.shift &&
          other.timeSignature == this.timeSignature &&
          other.temperature == this.temperature &&
          other.cfgScale == this.cfgScale &&
          other.topP == this.topP &&
          other.repetitionPenalty == this.repetitionPenalty &&
          other.audioDuration == this.audioDuration &&
          other.batchSize == this.batchSize &&
          other.useRandomSeed == this.useRandomSeed &&
          other.audioFormat == this.audioFormat &&
          other.workspaceId == this.workspaceId &&
          other.lyricSheetId == this.lyricSheetId &&
          other.title == this.title &&
          other.rating == this.rating &&
          other.taskId == this.taskId &&
          other.status == this.status &&
          other.result == this.result &&
          other.error == this.error &&
          other.completedAt == this.completedAt);
}

class AudioGenerationTaskCompanion
    extends UpdateCompanion<AudioGenerationTaskEntity> {
  final Value<String> id;
  final Value<PgDateTime> createdAt;
  final Value<String> userId;
  final Value<String> model;
  final Value<String> taskType;
  final Value<String?> prompt;
  final Value<String?> lyrics;
  final Value<String?> negativePrompt;
  final Value<String?> srcAudioPath;
  final Value<double?> infillStart;
  final Value<double?> infillEnd;
  final Value<String?> stemName;
  final Value<String?> trackClasses;
  final Value<bool?> thinking;
  final Value<bool?> constrainedDecoding;
  final Value<double?> guidanceScale;
  final Value<String?> inferMethod;
  final Value<int?> inferenceSteps;
  final Value<double?> cfgIntervalStart;
  final Value<double?> cfgIntervalEnd;
  final Value<double?> shift;
  final Value<String?> timeSignature;
  final Value<double?> temperature;
  final Value<double?> cfgScale;
  final Value<double?> topP;
  final Value<double?> repetitionPenalty;
  final Value<double?> audioDuration;
  final Value<int?> batchSize;
  final Value<bool?> useRandomSeed;
  final Value<String?> audioFormat;
  final Value<String?> workspaceId;
  final Value<String?> lyricSheetId;
  final Value<String?> title;
  final Value<int?> rating;
  final Value<String> taskId;
  final Value<String> status;
  final Value<String?> result;
  final Value<String?> error;
  final Value<PgDateTime?> completedAt;
  final Value<int> rowid;
  const AudioGenerationTaskCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.model = const Value.absent(),
    this.taskType = const Value.absent(),
    this.prompt = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.negativePrompt = const Value.absent(),
    this.srcAudioPath = const Value.absent(),
    this.infillStart = const Value.absent(),
    this.infillEnd = const Value.absent(),
    this.stemName = const Value.absent(),
    this.trackClasses = const Value.absent(),
    this.thinking = const Value.absent(),
    this.constrainedDecoding = const Value.absent(),
    this.guidanceScale = const Value.absent(),
    this.inferMethod = const Value.absent(),
    this.inferenceSteps = const Value.absent(),
    this.cfgIntervalStart = const Value.absent(),
    this.cfgIntervalEnd = const Value.absent(),
    this.shift = const Value.absent(),
    this.timeSignature = const Value.absent(),
    this.temperature = const Value.absent(),
    this.cfgScale = const Value.absent(),
    this.topP = const Value.absent(),
    this.repetitionPenalty = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.batchSize = const Value.absent(),
    this.useRandomSeed = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.lyricSheetId = const Value.absent(),
    this.title = const Value.absent(),
    this.rating = const Value.absent(),
    this.taskId = const Value.absent(),
    this.status = const Value.absent(),
    this.result = const Value.absent(),
    this.error = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioGenerationTaskCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String userId,
    required String model,
    required String taskType,
    this.prompt = const Value.absent(),
    this.lyrics = const Value.absent(),
    this.negativePrompt = const Value.absent(),
    this.srcAudioPath = const Value.absent(),
    this.infillStart = const Value.absent(),
    this.infillEnd = const Value.absent(),
    this.stemName = const Value.absent(),
    this.trackClasses = const Value.absent(),
    this.thinking = const Value.absent(),
    this.constrainedDecoding = const Value.absent(),
    this.guidanceScale = const Value.absent(),
    this.inferMethod = const Value.absent(),
    this.inferenceSteps = const Value.absent(),
    this.cfgIntervalStart = const Value.absent(),
    this.cfgIntervalEnd = const Value.absent(),
    this.shift = const Value.absent(),
    this.timeSignature = const Value.absent(),
    this.temperature = const Value.absent(),
    this.cfgScale = const Value.absent(),
    this.topP = const Value.absent(),
    this.repetitionPenalty = const Value.absent(),
    this.audioDuration = const Value.absent(),
    this.batchSize = const Value.absent(),
    this.useRandomSeed = const Value.absent(),
    this.audioFormat = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.lyricSheetId = const Value.absent(),
    this.title = const Value.absent(),
    this.rating = const Value.absent(),
    required String taskId,
    required String status,
    this.result = const Value.absent(),
    this.error = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       model = Value(model),
       taskType = Value(taskType),
       taskId = Value(taskId),
       status = Value(status);
  static Insertable<AudioGenerationTaskEntity> custom({
    Expression<String>? id,
    Expression<PgDateTime>? createdAt,
    Expression<String>? userId,
    Expression<String>? model,
    Expression<String>? taskType,
    Expression<String>? prompt,
    Expression<String>? lyrics,
    Expression<String>? negativePrompt,
    Expression<String>? srcAudioPath,
    Expression<double>? infillStart,
    Expression<double>? infillEnd,
    Expression<String>? stemName,
    Expression<String>? trackClasses,
    Expression<bool>? thinking,
    Expression<bool>? constrainedDecoding,
    Expression<double>? guidanceScale,
    Expression<String>? inferMethod,
    Expression<int>? inferenceSteps,
    Expression<double>? cfgIntervalStart,
    Expression<double>? cfgIntervalEnd,
    Expression<double>? shift,
    Expression<String>? timeSignature,
    Expression<double>? temperature,
    Expression<double>? cfgScale,
    Expression<double>? topP,
    Expression<double>? repetitionPenalty,
    Expression<double>? audioDuration,
    Expression<int>? batchSize,
    Expression<bool>? useRandomSeed,
    Expression<String>? audioFormat,
    Expression<String>? workspaceId,
    Expression<String>? lyricSheetId,
    Expression<String>? title,
    Expression<int>? rating,
    Expression<String>? taskId,
    Expression<String>? status,
    Expression<String>? result,
    Expression<String>? error,
    Expression<PgDateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (userId != null) 'user_id': userId,
      if (model != null) 'model': model,
      if (taskType != null) 'task_type': taskType,
      if (prompt != null) 'prompt': prompt,
      if (lyrics != null) 'lyrics': lyrics,
      if (negativePrompt != null) 'negative_prompt': negativePrompt,
      if (srcAudioPath != null) 'src_audio_path': srcAudioPath,
      if (infillStart != null) 'infill_start': infillStart,
      if (infillEnd != null) 'infill_end': infillEnd,
      if (stemName != null) 'stem_name': stemName,
      if (trackClasses != null) 'track_classes': trackClasses,
      if (thinking != null) 'thinking': thinking,
      if (constrainedDecoding != null)
        'constrained_decoding': constrainedDecoding,
      if (guidanceScale != null) 'guidance_scale': guidanceScale,
      if (inferMethod != null) 'infer_method': inferMethod,
      if (inferenceSteps != null) 'inference_steps': inferenceSteps,
      if (cfgIntervalStart != null) 'cfg_interval_start': cfgIntervalStart,
      if (cfgIntervalEnd != null) 'cfg_interval_end': cfgIntervalEnd,
      if (shift != null) 'shift': shift,
      if (timeSignature != null) 'time_signature': timeSignature,
      if (temperature != null) 'temperature': temperature,
      if (cfgScale != null) 'cfg_scale': cfgScale,
      if (topP != null) 'top_p': topP,
      if (repetitionPenalty != null) 'repetition_penalty': repetitionPenalty,
      if (audioDuration != null) 'audio_duration': audioDuration,
      if (batchSize != null) 'batch_size': batchSize,
      if (useRandomSeed != null) 'use_random_seed': useRandomSeed,
      if (audioFormat != null) 'audio_format': audioFormat,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (lyricSheetId != null) 'lyric_sheet_id': lyricSheetId,
      if (title != null) 'title': title,
      if (rating != null) 'rating': rating,
      if (taskId != null) 'task_id': taskId,
      if (status != null) 'status': status,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioGenerationTaskCompanion copyWith({
    Value<String>? id,
    Value<PgDateTime>? createdAt,
    Value<String>? userId,
    Value<String>? model,
    Value<String>? taskType,
    Value<String?>? prompt,
    Value<String?>? lyrics,
    Value<String?>? negativePrompt,
    Value<String?>? srcAudioPath,
    Value<double?>? infillStart,
    Value<double?>? infillEnd,
    Value<String?>? stemName,
    Value<String?>? trackClasses,
    Value<bool?>? thinking,
    Value<bool?>? constrainedDecoding,
    Value<double?>? guidanceScale,
    Value<String?>? inferMethod,
    Value<int?>? inferenceSteps,
    Value<double?>? cfgIntervalStart,
    Value<double?>? cfgIntervalEnd,
    Value<double?>? shift,
    Value<String?>? timeSignature,
    Value<double?>? temperature,
    Value<double?>? cfgScale,
    Value<double?>? topP,
    Value<double?>? repetitionPenalty,
    Value<double?>? audioDuration,
    Value<int?>? batchSize,
    Value<bool?>? useRandomSeed,
    Value<String?>? audioFormat,
    Value<String?>? workspaceId,
    Value<String?>? lyricSheetId,
    Value<String?>? title,
    Value<int?>? rating,
    Value<String>? taskId,
    Value<String>? status,
    Value<String?>? result,
    Value<String?>? error,
    Value<PgDateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return AudioGenerationTaskCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      model: model ?? this.model,
      taskType: taskType ?? this.taskType,
      prompt: prompt ?? this.prompt,
      lyrics: lyrics ?? this.lyrics,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      srcAudioPath: srcAudioPath ?? this.srcAudioPath,
      infillStart: infillStart ?? this.infillStart,
      infillEnd: infillEnd ?? this.infillEnd,
      stemName: stemName ?? this.stemName,
      trackClasses: trackClasses ?? this.trackClasses,
      thinking: thinking ?? this.thinking,
      constrainedDecoding: constrainedDecoding ?? this.constrainedDecoding,
      guidanceScale: guidanceScale ?? this.guidanceScale,
      inferMethod: inferMethod ?? this.inferMethod,
      inferenceSteps: inferenceSteps ?? this.inferenceSteps,
      cfgIntervalStart: cfgIntervalStart ?? this.cfgIntervalStart,
      cfgIntervalEnd: cfgIntervalEnd ?? this.cfgIntervalEnd,
      shift: shift ?? this.shift,
      timeSignature: timeSignature ?? this.timeSignature,
      temperature: temperature ?? this.temperature,
      cfgScale: cfgScale ?? this.cfgScale,
      topP: topP ?? this.topP,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
      audioDuration: audioDuration ?? this.audioDuration,
      batchSize: batchSize ?? this.batchSize,
      useRandomSeed: useRandomSeed ?? this.useRandomSeed,
      audioFormat: audioFormat ?? this.audioFormat,
      workspaceId: workspaceId ?? this.workspaceId,
      lyricSheetId: lyricSheetId ?? this.lyricSheetId,
      title: title ?? this.title,
      rating: rating ?? this.rating,
      taskId: taskId ?? this.taskId,
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<PgDateTime>(
        createdAt.value,
        PgTypes.timestampNoTimezone,
      );
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (taskType.present) {
      map['task_type'] = Variable<String>(taskType.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (lyrics.present) {
      map['lyrics'] = Variable<String>(lyrics.value);
    }
    if (negativePrompt.present) {
      map['negative_prompt'] = Variable<String>(negativePrompt.value);
    }
    if (srcAudioPath.present) {
      map['src_audio_path'] = Variable<String>(srcAudioPath.value);
    }
    if (infillStart.present) {
      map['infill_start'] = Variable<double>(infillStart.value);
    }
    if (infillEnd.present) {
      map['infill_end'] = Variable<double>(infillEnd.value);
    }
    if (stemName.present) {
      map['stem_name'] = Variable<String>(stemName.value);
    }
    if (trackClasses.present) {
      map['track_classes'] = Variable<String>(trackClasses.value);
    }
    if (thinking.present) {
      map['thinking'] = Variable<bool>(thinking.value);
    }
    if (constrainedDecoding.present) {
      map['constrained_decoding'] = Variable<bool>(constrainedDecoding.value);
    }
    if (guidanceScale.present) {
      map['guidance_scale'] = Variable<double>(guidanceScale.value);
    }
    if (inferMethod.present) {
      map['infer_method'] = Variable<String>(inferMethod.value);
    }
    if (inferenceSteps.present) {
      map['inference_steps'] = Variable<int>(inferenceSteps.value);
    }
    if (cfgIntervalStart.present) {
      map['cfg_interval_start'] = Variable<double>(cfgIntervalStart.value);
    }
    if (cfgIntervalEnd.present) {
      map['cfg_interval_end'] = Variable<double>(cfgIntervalEnd.value);
    }
    if (shift.present) {
      map['shift'] = Variable<double>(shift.value);
    }
    if (timeSignature.present) {
      map['time_signature'] = Variable<String>(timeSignature.value);
    }
    if (temperature.present) {
      map['temperature'] = Variable<double>(temperature.value);
    }
    if (cfgScale.present) {
      map['cfg_scale'] = Variable<double>(cfgScale.value);
    }
    if (topP.present) {
      map['top_p'] = Variable<double>(topP.value);
    }
    if (repetitionPenalty.present) {
      map['repetition_penalty'] = Variable<double>(repetitionPenalty.value);
    }
    if (audioDuration.present) {
      map['audio_duration'] = Variable<double>(audioDuration.value);
    }
    if (batchSize.present) {
      map['batch_size'] = Variable<int>(batchSize.value);
    }
    if (useRandomSeed.present) {
      map['use_random_seed'] = Variable<bool>(useRandomSeed.value);
    }
    if (audioFormat.present) {
      map['audio_format'] = Variable<String>(audioFormat.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (lyricSheetId.present) {
      map['lyric_sheet_id'] = Variable<String>(lyricSheetId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<PgDateTime>(
        completedAt.value,
        PgTypes.timestampNoTimezone,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioGenerationTaskCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('model: $model, ')
          ..write('taskType: $taskType, ')
          ..write('prompt: $prompt, ')
          ..write('lyrics: $lyrics, ')
          ..write('negativePrompt: $negativePrompt, ')
          ..write('srcAudioPath: $srcAudioPath, ')
          ..write('infillStart: $infillStart, ')
          ..write('infillEnd: $infillEnd, ')
          ..write('stemName: $stemName, ')
          ..write('trackClasses: $trackClasses, ')
          ..write('thinking: $thinking, ')
          ..write('constrainedDecoding: $constrainedDecoding, ')
          ..write('guidanceScale: $guidanceScale, ')
          ..write('inferMethod: $inferMethod, ')
          ..write('inferenceSteps: $inferenceSteps, ')
          ..write('cfgIntervalStart: $cfgIntervalStart, ')
          ..write('cfgIntervalEnd: $cfgIntervalEnd, ')
          ..write('shift: $shift, ')
          ..write('timeSignature: $timeSignature, ')
          ..write('temperature: $temperature, ')
          ..write('cfgScale: $cfgScale, ')
          ..write('topP: $topP, ')
          ..write('repetitionPenalty: $repetitionPenalty, ')
          ..write('audioDuration: $audioDuration, ')
          ..write('batchSize: $batchSize, ')
          ..write('useRandomSeed: $useRandomSeed, ')
          ..write('audioFormat: $audioFormat, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('lyricSheetId: $lyricSheetId, ')
          ..write('title: $title, ')
          ..write('rating: $rating, ')
          ..write('taskId: $taskId, ')
          ..write('status: $status, ')
          ..write('result: $result, ')
          ..write('error: $error, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingEntity(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingEntity extends DataClass
    implements Insertable<AppSettingEntity> {
  final String key;
  final String? value;
  const AppSettingEntity({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory AppSettingEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingEntity(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  AppSettingEntity copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => AppSettingEntity(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  AppSettingEntity copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingEntity(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingEntity(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingEntity &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingEntity> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<AppSettingEntity> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServerBackendsTable extends ServerBackends
    with TableInfo<$ServerBackendsTable, ServerBackendEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServerBackendsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => Uuid().v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<PgDateTime> createdAt =
      GeneratedColumn<PgDateTime>(
        'created_at',
        aliasedName,
        false,
        type: PgTypes.timestampNoTimezone,
        requiredDuringInsert: false,
        clientDefault: () => DateTimeExt(DateTime.now()).toPgDateTime(),
      );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiHostMeta = const VerificationMeta(
    'apiHost',
  );
  @override
  late final GeneratedColumn<String> apiHost = GeneratedColumn<String>(
    'api_host',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secureMeta = const VerificationMeta('secure');
  @override
  late final GeneratedColumn<bool> secure = GeneratedColumn<bool>(
    'secure',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("secure" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("is_active" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    name,
    apiHost,
    secure,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'server_backends';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServerBackendEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('api_host')) {
      context.handle(
        _apiHostMeta,
        apiHost.isAcceptableOrUnknown(data['api_host']!, _apiHostMeta),
      );
    } else if (isInserting) {
      context.missing(_apiHostMeta);
    }
    if (data.containsKey('secure')) {
      context.handle(
        _secureMeta,
        secure.isAcceptableOrUnknown(data['secure']!, _secureMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ServerBackendEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServerBackendEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        PgTypes.timestampNoTimezone,
        data['${effectivePrefix}created_at'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      apiHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_host'],
      )!,
      secure: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}secure'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $ServerBackendsTable createAlias(String alias) {
    return $ServerBackendsTable(attachedDatabase, alias);
  }
}

class ServerBackendEntity extends DataClass
    implements Insertable<ServerBackendEntity> {
  final String id;
  final PgDateTime createdAt;
  final String name;
  final String apiHost;
  final bool secure;
  final bool isActive;
  const ServerBackendEntity({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.apiHost,
    required this.secure,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<PgDateTime>(
      createdAt,
      PgTypes.timestampNoTimezone,
    );
    map['name'] = Variable<String>(name);
    map['api_host'] = Variable<String>(apiHost);
    map['secure'] = Variable<bool>(secure);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ServerBackendsCompanion toCompanion(bool nullToAbsent) {
    return ServerBackendsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      name: Value(name),
      apiHost: Value(apiHost),
      secure: Value(secure),
      isActive: Value(isActive),
    );
  }

  factory ServerBackendEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServerBackendEntity(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<PgDateTime>(json['createdAt']),
      name: serializer.fromJson<String>(json['name']),
      apiHost: serializer.fromJson<String>(json['apiHost']),
      secure: serializer.fromJson<bool>(json['secure']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<PgDateTime>(createdAt),
      'name': serializer.toJson<String>(name),
      'apiHost': serializer.toJson<String>(apiHost),
      'secure': serializer.toJson<bool>(secure),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  ServerBackendEntity copyWith({
    String? id,
    PgDateTime? createdAt,
    String? name,
    String? apiHost,
    bool? secure,
    bool? isActive,
  }) => ServerBackendEntity(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    name: name ?? this.name,
    apiHost: apiHost ?? this.apiHost,
    secure: secure ?? this.secure,
    isActive: isActive ?? this.isActive,
  );
  ServerBackendEntity copyWithCompanion(ServerBackendsCompanion data) {
    return ServerBackendEntity(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      name: data.name.present ? data.name.value : this.name,
      apiHost: data.apiHost.present ? data.apiHost.value : this.apiHost,
      secure: data.secure.present ? data.secure.value : this.secure,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServerBackendEntity(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('name: $name, ')
          ..write('apiHost: $apiHost, ')
          ..write('secure: $secure, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, name, apiHost, secure, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServerBackendEntity &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.name == this.name &&
          other.apiHost == this.apiHost &&
          other.secure == this.secure &&
          other.isActive == this.isActive);
}

class ServerBackendsCompanion extends UpdateCompanion<ServerBackendEntity> {
  final Value<String> id;
  final Value<PgDateTime> createdAt;
  final Value<String> name;
  final Value<String> apiHost;
  final Value<bool> secure;
  final Value<bool> isActive;
  final Value<int> rowid;
  const ServerBackendsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.name = const Value.absent(),
    this.apiHost = const Value.absent(),
    this.secure = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServerBackendsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String name,
    required String apiHost,
    this.secure = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       apiHost = Value(apiHost);
  static Insertable<ServerBackendEntity> custom({
    Expression<String>? id,
    Expression<PgDateTime>? createdAt,
    Expression<String>? name,
    Expression<String>? apiHost,
    Expression<bool>? secure,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (name != null) 'name': name,
      if (apiHost != null) 'api_host': apiHost,
      if (secure != null) 'secure': secure,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServerBackendsCompanion copyWith({
    Value<String>? id,
    Value<PgDateTime>? createdAt,
    Value<String>? name,
    Value<String>? apiHost,
    Value<bool>? secure,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return ServerBackendsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      apiHost: apiHost ?? this.apiHost,
      secure: secure ?? this.secure,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<PgDateTime>(
        createdAt.value,
        PgTypes.timestampNoTimezone,
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (apiHost.present) {
      map['api_host'] = Variable<String>(apiHost.value);
    }
    if (secure.present) {
      map['secure'] = Variable<bool>(secure.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServerBackendsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('name: $name, ')
          ..write('apiHost: $apiHost, ')
          ..write('secure: $secure, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeerConnectionsTable extends PeerConnections
    with TableInfo<$PeerConnectionsTable, PeerConnectionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeerConnectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => Uuid().v4(),
  );
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<String> publicKey = GeneratedColumn<String>(
    'public_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<PgDateTime> firstSeenAt =
      GeneratedColumn<PgDateTime>(
        'first_seen_at',
        aliasedName,
        false,
        type: PgTypes.timestampNoTimezone,
        requiredDuringInsert: false,
        clientDefault: () => DateTimeExt(DateTime.now()).toPgDateTime(),
      );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<PgDateTime> lastSeenAt =
      GeneratedColumn<PgDateTime>(
        'last_seen_at',
        aliasedName,
        false,
        type: PgTypes.timestampNoTimezone,
        requiredDuringInsert: false,
        clientDefault: () => DateTimeExt(DateTime.now()).toPgDateTime(),
      );
  static const VerificationMeta _requestCountMeta = const VerificationMeta(
    'requestCount',
  );
  @override
  late final GeneratedColumn<int> requestCount = GeneratedColumn<int>(
    'request_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _blockedMeta = const VerificationMeta(
    'blocked',
  );
  @override
  late final GeneratedColumn<bool> blocked = GeneratedColumn<bool>(
    'blocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("blocked" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    publicKey,
    firstSeenAt,
    lastSeenAt,
    requestCount,
    blocked,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peer_connections';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerConnectionEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_publicKeyMeta);
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('request_count')) {
      context.handle(
        _requestCountMeta,
        requestCount.isAcceptableOrUnknown(
          data['request_count']!,
          _requestCountMeta,
        ),
      );
    }
    if (data.containsKey('blocked')) {
      context.handle(
        _blockedMeta,
        blocked.isAcceptableOrUnknown(data['blocked']!, _blockedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeerConnectionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerConnectionEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      publicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}public_key'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        PgTypes.timestampNoTimezone,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        PgTypes.timestampNoTimezone,
        data['${effectivePrefix}last_seen_at'],
      )!,
      requestCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}request_count'],
      )!,
      blocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}blocked'],
      )!,
    );
  }

  @override
  $PeerConnectionsTable createAlias(String alias) {
    return $PeerConnectionsTable(attachedDatabase, alias);
  }
}

class PeerConnectionEntity extends DataClass
    implements Insertable<PeerConnectionEntity> {
  final String id;
  final String publicKey;
  final PgDateTime firstSeenAt;
  final PgDateTime lastSeenAt;
  final int requestCount;
  final bool blocked;
  const PeerConnectionEntity({
    required this.id,
    required this.publicKey,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.requestCount,
    required this.blocked,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['public_key'] = Variable<String>(publicKey);
    map['first_seen_at'] = Variable<PgDateTime>(
      firstSeenAt,
      PgTypes.timestampNoTimezone,
    );
    map['last_seen_at'] = Variable<PgDateTime>(
      lastSeenAt,
      PgTypes.timestampNoTimezone,
    );
    map['request_count'] = Variable<int>(requestCount);
    map['blocked'] = Variable<bool>(blocked);
    return map;
  }

  PeerConnectionsCompanion toCompanion(bool nullToAbsent) {
    return PeerConnectionsCompanion(
      id: Value(id),
      publicKey: Value(publicKey),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
      requestCount: Value(requestCount),
      blocked: Value(blocked),
    );
  }

  factory PeerConnectionEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerConnectionEntity(
      id: serializer.fromJson<String>(json['id']),
      publicKey: serializer.fromJson<String>(json['publicKey']),
      firstSeenAt: serializer.fromJson<PgDateTime>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<PgDateTime>(json['lastSeenAt']),
      requestCount: serializer.fromJson<int>(json['requestCount']),
      blocked: serializer.fromJson<bool>(json['blocked']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'publicKey': serializer.toJson<String>(publicKey),
      'firstSeenAt': serializer.toJson<PgDateTime>(firstSeenAt),
      'lastSeenAt': serializer.toJson<PgDateTime>(lastSeenAt),
      'requestCount': serializer.toJson<int>(requestCount),
      'blocked': serializer.toJson<bool>(blocked),
    };
  }

  PeerConnectionEntity copyWith({
    String? id,
    String? publicKey,
    PgDateTime? firstSeenAt,
    PgDateTime? lastSeenAt,
    int? requestCount,
    bool? blocked,
  }) => PeerConnectionEntity(
    id: id ?? this.id,
    publicKey: publicKey ?? this.publicKey,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    requestCount: requestCount ?? this.requestCount,
    blocked: blocked ?? this.blocked,
  );
  PeerConnectionEntity copyWithCompanion(PeerConnectionsCompanion data) {
    return PeerConnectionEntity(
      id: data.id.present ? data.id.value : this.id,
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      requestCount: data.requestCount.present
          ? data.requestCount.value
          : this.requestCount,
      blocked: data.blocked.present ? data.blocked.value : this.blocked,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerConnectionEntity(')
          ..write('id: $id, ')
          ..write('publicKey: $publicKey, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('requestCount: $requestCount, ')
          ..write('blocked: $blocked')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    publicKey,
    firstSeenAt,
    lastSeenAt,
    requestCount,
    blocked,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerConnectionEntity &&
          other.id == this.id &&
          other.publicKey == this.publicKey &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.requestCount == this.requestCount &&
          other.blocked == this.blocked);
}

class PeerConnectionsCompanion extends UpdateCompanion<PeerConnectionEntity> {
  final Value<String> id;
  final Value<String> publicKey;
  final Value<PgDateTime> firstSeenAt;
  final Value<PgDateTime> lastSeenAt;
  final Value<int> requestCount;
  final Value<bool> blocked;
  final Value<int> rowid;
  const PeerConnectionsCompanion({
    this.id = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.requestCount = const Value.absent(),
    this.blocked = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeerConnectionsCompanion.insert({
    this.id = const Value.absent(),
    required String publicKey,
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.requestCount = const Value.absent(),
    this.blocked = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : publicKey = Value(publicKey);
  static Insertable<PeerConnectionEntity> custom({
    Expression<String>? id,
    Expression<String>? publicKey,
    Expression<PgDateTime>? firstSeenAt,
    Expression<PgDateTime>? lastSeenAt,
    Expression<int>? requestCount,
    Expression<bool>? blocked,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (publicKey != null) 'public_key': publicKey,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (requestCount != null) 'request_count': requestCount,
      if (blocked != null) 'blocked': blocked,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeerConnectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? publicKey,
    Value<PgDateTime>? firstSeenAt,
    Value<PgDateTime>? lastSeenAt,
    Value<int>? requestCount,
    Value<bool>? blocked,
    Value<int>? rowid,
  }) {
    return PeerConnectionsCompanion(
      id: id ?? this.id,
      publicKey: publicKey ?? this.publicKey,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      requestCount: requestCount ?? this.requestCount,
      blocked: blocked ?? this.blocked,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<String>(publicKey.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<PgDateTime>(
        firstSeenAt.value,
        PgTypes.timestampNoTimezone,
      );
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<PgDateTime>(
        lastSeenAt.value,
        PgTypes.timestampNoTimezone,
      );
    }
    if (requestCount.present) {
      map['request_count'] = Variable<int>(requestCount.value);
    }
    if (blocked.present) {
      map['blocked'] = Variable<bool>(blocked.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeerConnectionsCompanion(')
          ..write('id: $id, ')
          ..write('publicKey: $publicKey, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('requestCount: $requestCount, ')
          ..write('blocked: $blocked, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkspacesTable extends Workspaces
    with TableInfo<$WorkspacesTable, WorkspaceEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => Uuid().v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<PgDateTime> createdAt =
      GeneratedColumn<PgDateTime>(
        'created_at',
        aliasedName,
        false,
        type: PgTypes.timestampNoTimezone,
        requiredDuringInsert: false,
        clientDefault: () => DateTimeExt(DateTime.now()).toPgDateTime(),
      );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintsDependsOnDialect({
      SqlDialect.sqlite: 'CHECK ("is_default" IN (0, 1))',
      SqlDialect.postgres: '',
    }),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    userId,
    name,
    isDefault,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkspaceEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkspaceEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        PgTypes.timestampNoTimezone,
        data['${effectivePrefix}created_at'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
    );
  }

  @override
  $WorkspacesTable createAlias(String alias) {
    return $WorkspacesTable(attachedDatabase, alias);
  }
}

class WorkspaceEntity extends DataClass implements Insertable<WorkspaceEntity> {
  final String id;
  final PgDateTime createdAt;
  final String userId;
  final String name;
  final bool isDefault;
  const WorkspaceEntity({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.name,
    required this.isDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<PgDateTime>(
      createdAt,
      PgTypes.timestampNoTimezone,
    );
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    map['is_default'] = Variable<bool>(isDefault);
    return map;
  }

  WorkspacesCompanion toCompanion(bool nullToAbsent) {
    return WorkspacesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      userId: Value(userId),
      name: Value(name),
      isDefault: Value(isDefault),
    );
  }

  factory WorkspaceEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceEntity(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<PgDateTime>(json['createdAt']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<PgDateTime>(createdAt),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'isDefault': serializer.toJson<bool>(isDefault),
    };
  }

  WorkspaceEntity copyWith({
    String? id,
    PgDateTime? createdAt,
    String? userId,
    String? name,
    bool? isDefault,
  }) => WorkspaceEntity(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    isDefault: isDefault ?? this.isDefault,
  );
  WorkspaceEntity copyWithCompanion(WorkspacesCompanion data) {
    return WorkspaceEntity(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceEntity(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, userId, name, isDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceEntity &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.isDefault == this.isDefault);
}

class WorkspacesCompanion extends UpdateCompanion<WorkspaceEntity> {
  final Value<String> id;
  final Value<PgDateTime> createdAt;
  final Value<String> userId;
  final Value<String> name;
  final Value<bool> isDefault;
  final Value<int> rowid;
  const WorkspacesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkspacesCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String userId,
    required String name,
    this.isDefault = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       name = Value(name);
  static Insertable<WorkspaceEntity> custom({
    Expression<String>? id,
    Expression<PgDateTime>? createdAt,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<bool>? isDefault,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (isDefault != null) 'is_default': isDefault,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkspacesCompanion copyWith({
    Value<String>? id,
    Value<PgDateTime>? createdAt,
    Value<String>? userId,
    Value<String>? name,
    Value<bool>? isDefault,
    Value<int>? rowid,
  }) {
    return WorkspacesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<PgDateTime>(
        createdAt.value,
        PgTypes.timestampNoTimezone,
      );
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspacesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('isDefault: $isDefault, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricSheetsTable extends LyricSheets
    with TableInfo<$LyricSheetsTable, LyricSheetEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricSheetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => Uuid().v4(),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<PgDateTime> createdAt =
      GeneratedColumn<PgDateTime>(
        'created_at',
        aliasedName,
        false,
        type: PgTypes.timestampNoTimezone,
        requiredDuringInsert: false,
        clientDefault: () => DateTimeExt(DateTime.now()).toPgDateTime(),
      );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, createdAt, userId, title, content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyric_sheets';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricSheetEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LyricSheetEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricSheetEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        PgTypes.timestampNoTimezone,
        data['${effectivePrefix}created_at'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
    );
  }

  @override
  $LyricSheetsTable createAlias(String alias) {
    return $LyricSheetsTable(attachedDatabase, alias);
  }
}

class LyricSheetEntity extends DataClass
    implements Insertable<LyricSheetEntity> {
  final String id;
  final PgDateTime createdAt;
  final String userId;
  final String title;
  final String content;
  const LyricSheetEntity({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.title,
    required this.content,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<PgDateTime>(
      createdAt,
      PgTypes.timestampNoTimezone,
    );
    map['user_id'] = Variable<String>(userId);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    return map;
  }

  LyricSheetsCompanion toCompanion(bool nullToAbsent) {
    return LyricSheetsCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      userId: Value(userId),
      title: Value(title),
      content: Value(content),
    );
  }

  factory LyricSheetEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricSheetEntity(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<PgDateTime>(json['createdAt']),
      userId: serializer.fromJson<String>(json['userId']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<PgDateTime>(createdAt),
      'userId': serializer.toJson<String>(userId),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
    };
  }

  LyricSheetEntity copyWith({
    String? id,
    PgDateTime? createdAt,
    String? userId,
    String? title,
    String? content,
  }) => LyricSheetEntity(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    content: content ?? this.content,
  );
  LyricSheetEntity copyWithCompanion(LyricSheetsCompanion data) {
    return LyricSheetEntity(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      userId: data.userId.present ? data.userId.value : this.userId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricSheetEntity(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, createdAt, userId, title, content);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricSheetEntity &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.userId == this.userId &&
          other.title == this.title &&
          other.content == this.content);
}

class LyricSheetsCompanion extends UpdateCompanion<LyricSheetEntity> {
  final Value<String> id;
  final Value<PgDateTime> createdAt;
  final Value<String> userId;
  final Value<String> title;
  final Value<String> content;
  final Value<int> rowid;
  const LyricSheetsCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.userId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricSheetsCompanion.insert({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    required String userId,
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId);
  static Insertable<LyricSheetEntity> custom({
    Expression<String>? id,
    Expression<PgDateTime>? createdAt,
    Expression<String>? userId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (userId != null) 'user_id': userId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricSheetsCompanion copyWith({
    Value<String>? id,
    Value<PgDateTime>? createdAt,
    Value<String>? userId,
    Value<String>? title,
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return LyricSheetsCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<PgDateTime>(
        createdAt.value,
        PgTypes.timestampNoTimezone,
      );
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricSheetsCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('userId: $userId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$Database extends GeneratedDatabase {
  _$Database(QueryExecutor e) : super(e);
  $DatabaseManager get managers => $DatabaseManager(this);
  late final $UserTable user = $UserTable(this);
  late final $AudioGenerationTaskTable audioGenerationTask =
      $AudioGenerationTaskTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $ServerBackendsTable serverBackends = $ServerBackendsTable(this);
  late final $PeerConnectionsTable peerConnections = $PeerConnectionsTable(
    this,
  );
  late final $WorkspacesTable workspaces = $WorkspacesTable(this);
  late final $LyricSheetsTable lyricSheets = $LyricSheetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    user,
    audioGenerationTask,
    appSettings,
    serverBackends,
    peerConnections,
    workspaces,
    lyricSheets,
  ];
}

typedef $$UserTableCreateCompanionBuilder =
    UserCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      required String userId,
      required String displayName,
      Value<int> rowid,
    });
typedef $$UserTableUpdateCompanionBuilder =
    UserCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      Value<String> userId,
      Value<String> displayName,
      Value<int> rowid,
    });

class $$UserTableFilterComposer extends Composer<_$Database, $UserTable> {
  $$UserTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserTableOrderingComposer extends Composer<_$Database, $UserTable> {
  $$UserTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserTableAnnotationComposer extends Composer<_$Database, $UserTable> {
  $$UserTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<PgDateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );
}

class $$UserTableTableManager
    extends
        RootTableManager<
          _$Database,
          $UserTable,
          UserEntity,
          $$UserTableFilterComposer,
          $$UserTableOrderingComposer,
          $$UserTableAnnotationComposer,
          $$UserTableCreateCompanionBuilder,
          $$UserTableUpdateCompanionBuilder,
          (UserEntity, BaseReferences<_$Database, $UserTable, UserEntity>),
          UserEntity,
          PrefetchHooks Function()
        > {
  $$UserTableTableManager(_$Database db, $UserTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserCompanion(
                id: id,
                createdAt: createdAt,
                userId: userId,
                displayName: displayName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                required String userId,
                required String displayName,
                Value<int> rowid = const Value.absent(),
              }) => UserCompanion.insert(
                id: id,
                createdAt: createdAt,
                userId: userId,
                displayName: displayName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $UserTable,
      UserEntity,
      $$UserTableFilterComposer,
      $$UserTableOrderingComposer,
      $$UserTableAnnotationComposer,
      $$UserTableCreateCompanionBuilder,
      $$UserTableUpdateCompanionBuilder,
      (UserEntity, BaseReferences<_$Database, $UserTable, UserEntity>),
      UserEntity,
      PrefetchHooks Function()
    >;
typedef $$AudioGenerationTaskTableCreateCompanionBuilder =
    AudioGenerationTaskCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      required String userId,
      required String model,
      required String taskType,
      Value<String?> prompt,
      Value<String?> lyrics,
      Value<String?> negativePrompt,
      Value<String?> srcAudioPath,
      Value<double?> infillStart,
      Value<double?> infillEnd,
      Value<String?> stemName,
      Value<String?> trackClasses,
      Value<bool?> thinking,
      Value<bool?> constrainedDecoding,
      Value<double?> guidanceScale,
      Value<String?> inferMethod,
      Value<int?> inferenceSteps,
      Value<double?> cfgIntervalStart,
      Value<double?> cfgIntervalEnd,
      Value<double?> shift,
      Value<String?> timeSignature,
      Value<double?> temperature,
      Value<double?> cfgScale,
      Value<double?> topP,
      Value<double?> repetitionPenalty,
      Value<double?> audioDuration,
      Value<int?> batchSize,
      Value<bool?> useRandomSeed,
      Value<String?> audioFormat,
      Value<String?> workspaceId,
      Value<String?> lyricSheetId,
      Value<String?> title,
      Value<int?> rating,
      required String taskId,
      required String status,
      Value<String?> result,
      Value<String?> error,
      Value<PgDateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$AudioGenerationTaskTableUpdateCompanionBuilder =
    AudioGenerationTaskCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      Value<String> userId,
      Value<String> model,
      Value<String> taskType,
      Value<String?> prompt,
      Value<String?> lyrics,
      Value<String?> negativePrompt,
      Value<String?> srcAudioPath,
      Value<double?> infillStart,
      Value<double?> infillEnd,
      Value<String?> stemName,
      Value<String?> trackClasses,
      Value<bool?> thinking,
      Value<bool?> constrainedDecoding,
      Value<double?> guidanceScale,
      Value<String?> inferMethod,
      Value<int?> inferenceSteps,
      Value<double?> cfgIntervalStart,
      Value<double?> cfgIntervalEnd,
      Value<double?> shift,
      Value<String?> timeSignature,
      Value<double?> temperature,
      Value<double?> cfgScale,
      Value<double?> topP,
      Value<double?> repetitionPenalty,
      Value<double?> audioDuration,
      Value<int?> batchSize,
      Value<bool?> useRandomSeed,
      Value<String?> audioFormat,
      Value<String?> workspaceId,
      Value<String?> lyricSheetId,
      Value<String?> title,
      Value<int?> rating,
      Value<String> taskId,
      Value<String> status,
      Value<String?> result,
      Value<String?> error,
      Value<PgDateTime?> completedAt,
      Value<int> rowid,
    });

class $$AudioGenerationTaskTableFilterComposer
    extends Composer<_$Database, $AudioGenerationTaskTable> {
  $$AudioGenerationTaskTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyrics => $composableBuilder(
    column: $table.lyrics,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get negativePrompt => $composableBuilder(
    column: $table.negativePrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get srcAudioPath => $composableBuilder(
    column: $table.srcAudioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get infillStart => $composableBuilder(
    column: $table.infillStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get infillEnd => $composableBuilder(
    column: $table.infillEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stemName => $composableBuilder(
    column: $table.stemName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackClasses => $composableBuilder(
    column: $table.trackClasses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get thinking => $composableBuilder(
    column: $table.thinking,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get constrainedDecoding => $composableBuilder(
    column: $table.constrainedDecoding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get guidanceScale => $composableBuilder(
    column: $table.guidanceScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inferMethod => $composableBuilder(
    column: $table.inferMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inferenceSteps => $composableBuilder(
    column: $table.inferenceSteps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cfgIntervalStart => $composableBuilder(
    column: $table.cfgIntervalStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cfgIntervalEnd => $composableBuilder(
    column: $table.cfgIntervalEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get shift => $composableBuilder(
    column: $table.shift,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cfgScale => $composableBuilder(
    column: $table.cfgScale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get topP => $composableBuilder(
    column: $table.topP,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get repetitionPenalty => $composableBuilder(
    column: $table.repetitionPenalty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batchSize => $composableBuilder(
    column: $table.batchSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useRandomSeed => $composableBuilder(
    column: $table.useRandomSeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyricSheetId => $composableBuilder(
    column: $table.lyricSheetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<PgDateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioGenerationTaskTableOrderingComposer
    extends Composer<_$Database, $AudioGenerationTaskTable> {
  $$AudioGenerationTaskTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskType => $composableBuilder(
    column: $table.taskType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyrics => $composableBuilder(
    column: $table.lyrics,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get negativePrompt => $composableBuilder(
    column: $table.negativePrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get srcAudioPath => $composableBuilder(
    column: $table.srcAudioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get infillStart => $composableBuilder(
    column: $table.infillStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get infillEnd => $composableBuilder(
    column: $table.infillEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stemName => $composableBuilder(
    column: $table.stemName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackClasses => $composableBuilder(
    column: $table.trackClasses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get thinking => $composableBuilder(
    column: $table.thinking,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get constrainedDecoding => $composableBuilder(
    column: $table.constrainedDecoding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get guidanceScale => $composableBuilder(
    column: $table.guidanceScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inferMethod => $composableBuilder(
    column: $table.inferMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inferenceSteps => $composableBuilder(
    column: $table.inferenceSteps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cfgIntervalStart => $composableBuilder(
    column: $table.cfgIntervalStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cfgIntervalEnd => $composableBuilder(
    column: $table.cfgIntervalEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get shift => $composableBuilder(
    column: $table.shift,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cfgScale => $composableBuilder(
    column: $table.cfgScale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get topP => $composableBuilder(
    column: $table.topP,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get repetitionPenalty => $composableBuilder(
    column: $table.repetitionPenalty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batchSize => $composableBuilder(
    column: $table.batchSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useRandomSeed => $composableBuilder(
    column: $table.useRandomSeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyricSheetId => $composableBuilder(
    column: $table.lyricSheetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<PgDateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioGenerationTaskTableAnnotationComposer
    extends Composer<_$Database, $AudioGenerationTaskTable> {
  $$AudioGenerationTaskTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<PgDateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get taskType =>
      $composableBuilder(column: $table.taskType, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get lyrics =>
      $composableBuilder(column: $table.lyrics, builder: (column) => column);

  GeneratedColumn<String> get negativePrompt => $composableBuilder(
    column: $table.negativePrompt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get srcAudioPath => $composableBuilder(
    column: $table.srcAudioPath,
    builder: (column) => column,
  );

  GeneratedColumn<double> get infillStart => $composableBuilder(
    column: $table.infillStart,
    builder: (column) => column,
  );

  GeneratedColumn<double> get infillEnd =>
      $composableBuilder(column: $table.infillEnd, builder: (column) => column);

  GeneratedColumn<String> get stemName =>
      $composableBuilder(column: $table.stemName, builder: (column) => column);

  GeneratedColumn<String> get trackClasses => $composableBuilder(
    column: $table.trackClasses,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get thinking =>
      $composableBuilder(column: $table.thinking, builder: (column) => column);

  GeneratedColumn<bool> get constrainedDecoding => $composableBuilder(
    column: $table.constrainedDecoding,
    builder: (column) => column,
  );

  GeneratedColumn<double> get guidanceScale => $composableBuilder(
    column: $table.guidanceScale,
    builder: (column) => column,
  );

  GeneratedColumn<String> get inferMethod => $composableBuilder(
    column: $table.inferMethod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inferenceSteps => $composableBuilder(
    column: $table.inferenceSteps,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cfgIntervalStart => $composableBuilder(
    column: $table.cfgIntervalStart,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cfgIntervalEnd => $composableBuilder(
    column: $table.cfgIntervalEnd,
    builder: (column) => column,
  );

  GeneratedColumn<double> get shift =>
      $composableBuilder(column: $table.shift, builder: (column) => column);

  GeneratedColumn<String> get timeSignature => $composableBuilder(
    column: $table.timeSignature,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperature => $composableBuilder(
    column: $table.temperature,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cfgScale =>
      $composableBuilder(column: $table.cfgScale, builder: (column) => column);

  GeneratedColumn<double> get topP =>
      $composableBuilder(column: $table.topP, builder: (column) => column);

  GeneratedColumn<double> get repetitionPenalty => $composableBuilder(
    column: $table.repetitionPenalty,
    builder: (column) => column,
  );

  GeneratedColumn<double> get audioDuration => $composableBuilder(
    column: $table.audioDuration,
    builder: (column) => column,
  );

  GeneratedColumn<int> get batchSize =>
      $composableBuilder(column: $table.batchSize, builder: (column) => column);

  GeneratedColumn<bool> get useRandomSeed => $composableBuilder(
    column: $table.useRandomSeed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioFormat => $composableBuilder(
    column: $table.audioFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workspaceId => $composableBuilder(
    column: $table.workspaceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lyricSheetId => $composableBuilder(
    column: $table.lyricSheetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<PgDateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$AudioGenerationTaskTableTableManager
    extends
        RootTableManager<
          _$Database,
          $AudioGenerationTaskTable,
          AudioGenerationTaskEntity,
          $$AudioGenerationTaskTableFilterComposer,
          $$AudioGenerationTaskTableOrderingComposer,
          $$AudioGenerationTaskTableAnnotationComposer,
          $$AudioGenerationTaskTableCreateCompanionBuilder,
          $$AudioGenerationTaskTableUpdateCompanionBuilder,
          (
            AudioGenerationTaskEntity,
            BaseReferences<
              _$Database,
              $AudioGenerationTaskTable,
              AudioGenerationTaskEntity
            >,
          ),
          AudioGenerationTaskEntity,
          PrefetchHooks Function()
        > {
  $$AudioGenerationTaskTableTableManager(
    _$Database db,
    $AudioGenerationTaskTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioGenerationTaskTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioGenerationTaskTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AudioGenerationTaskTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> taskType = const Value.absent(),
                Value<String?> prompt = const Value.absent(),
                Value<String?> lyrics = const Value.absent(),
                Value<String?> negativePrompt = const Value.absent(),
                Value<String?> srcAudioPath = const Value.absent(),
                Value<double?> infillStart = const Value.absent(),
                Value<double?> infillEnd = const Value.absent(),
                Value<String?> stemName = const Value.absent(),
                Value<String?> trackClasses = const Value.absent(),
                Value<bool?> thinking = const Value.absent(),
                Value<bool?> constrainedDecoding = const Value.absent(),
                Value<double?> guidanceScale = const Value.absent(),
                Value<String?> inferMethod = const Value.absent(),
                Value<int?> inferenceSteps = const Value.absent(),
                Value<double?> cfgIntervalStart = const Value.absent(),
                Value<double?> cfgIntervalEnd = const Value.absent(),
                Value<double?> shift = const Value.absent(),
                Value<String?> timeSignature = const Value.absent(),
                Value<double?> temperature = const Value.absent(),
                Value<double?> cfgScale = const Value.absent(),
                Value<double?> topP = const Value.absent(),
                Value<double?> repetitionPenalty = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<int?> batchSize = const Value.absent(),
                Value<bool?> useRandomSeed = const Value.absent(),
                Value<String?> audioFormat = const Value.absent(),
                Value<String?> workspaceId = const Value.absent(),
                Value<String?> lyricSheetId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<PgDateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioGenerationTaskCompanion(
                id: id,
                createdAt: createdAt,
                userId: userId,
                model: model,
                taskType: taskType,
                prompt: prompt,
                lyrics: lyrics,
                negativePrompt: negativePrompt,
                srcAudioPath: srcAudioPath,
                infillStart: infillStart,
                infillEnd: infillEnd,
                stemName: stemName,
                trackClasses: trackClasses,
                thinking: thinking,
                constrainedDecoding: constrainedDecoding,
                guidanceScale: guidanceScale,
                inferMethod: inferMethod,
                inferenceSteps: inferenceSteps,
                cfgIntervalStart: cfgIntervalStart,
                cfgIntervalEnd: cfgIntervalEnd,
                shift: shift,
                timeSignature: timeSignature,
                temperature: temperature,
                cfgScale: cfgScale,
                topP: topP,
                repetitionPenalty: repetitionPenalty,
                audioDuration: audioDuration,
                batchSize: batchSize,
                useRandomSeed: useRandomSeed,
                audioFormat: audioFormat,
                workspaceId: workspaceId,
                lyricSheetId: lyricSheetId,
                title: title,
                rating: rating,
                taskId: taskId,
                status: status,
                result: result,
                error: error,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                required String userId,
                required String model,
                required String taskType,
                Value<String?> prompt = const Value.absent(),
                Value<String?> lyrics = const Value.absent(),
                Value<String?> negativePrompt = const Value.absent(),
                Value<String?> srcAudioPath = const Value.absent(),
                Value<double?> infillStart = const Value.absent(),
                Value<double?> infillEnd = const Value.absent(),
                Value<String?> stemName = const Value.absent(),
                Value<String?> trackClasses = const Value.absent(),
                Value<bool?> thinking = const Value.absent(),
                Value<bool?> constrainedDecoding = const Value.absent(),
                Value<double?> guidanceScale = const Value.absent(),
                Value<String?> inferMethod = const Value.absent(),
                Value<int?> inferenceSteps = const Value.absent(),
                Value<double?> cfgIntervalStart = const Value.absent(),
                Value<double?> cfgIntervalEnd = const Value.absent(),
                Value<double?> shift = const Value.absent(),
                Value<String?> timeSignature = const Value.absent(),
                Value<double?> temperature = const Value.absent(),
                Value<double?> cfgScale = const Value.absent(),
                Value<double?> topP = const Value.absent(),
                Value<double?> repetitionPenalty = const Value.absent(),
                Value<double?> audioDuration = const Value.absent(),
                Value<int?> batchSize = const Value.absent(),
                Value<bool?> useRandomSeed = const Value.absent(),
                Value<String?> audioFormat = const Value.absent(),
                Value<String?> workspaceId = const Value.absent(),
                Value<String?> lyricSheetId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                required String taskId,
                required String status,
                Value<String?> result = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<PgDateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioGenerationTaskCompanion.insert(
                id: id,
                createdAt: createdAt,
                userId: userId,
                model: model,
                taskType: taskType,
                prompt: prompt,
                lyrics: lyrics,
                negativePrompt: negativePrompt,
                srcAudioPath: srcAudioPath,
                infillStart: infillStart,
                infillEnd: infillEnd,
                stemName: stemName,
                trackClasses: trackClasses,
                thinking: thinking,
                constrainedDecoding: constrainedDecoding,
                guidanceScale: guidanceScale,
                inferMethod: inferMethod,
                inferenceSteps: inferenceSteps,
                cfgIntervalStart: cfgIntervalStart,
                cfgIntervalEnd: cfgIntervalEnd,
                shift: shift,
                timeSignature: timeSignature,
                temperature: temperature,
                cfgScale: cfgScale,
                topP: topP,
                repetitionPenalty: repetitionPenalty,
                audioDuration: audioDuration,
                batchSize: batchSize,
                useRandomSeed: useRandomSeed,
                audioFormat: audioFormat,
                workspaceId: workspaceId,
                lyricSheetId: lyricSheetId,
                title: title,
                rating: rating,
                taskId: taskId,
                status: status,
                result: result,
                error: error,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioGenerationTaskTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $AudioGenerationTaskTable,
      AudioGenerationTaskEntity,
      $$AudioGenerationTaskTableFilterComposer,
      $$AudioGenerationTaskTableOrderingComposer,
      $$AudioGenerationTaskTableAnnotationComposer,
      $$AudioGenerationTaskTableCreateCompanionBuilder,
      $$AudioGenerationTaskTableUpdateCompanionBuilder,
      (
        AudioGenerationTaskEntity,
        BaseReferences<
          _$Database,
          $AudioGenerationTaskTable,
          AudioGenerationTaskEntity
        >,
      ),
      AudioGenerationTaskEntity,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$Database, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$Database, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$Database, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$Database,
          $AppSettingsTable,
          AppSettingEntity,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingEntity,
            BaseReferences<_$Database, $AppSettingsTable, AppSettingEntity>,
          ),
          AppSettingEntity,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$Database db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $AppSettingsTable,
      AppSettingEntity,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingEntity,
        BaseReferences<_$Database, $AppSettingsTable, AppSettingEntity>,
      ),
      AppSettingEntity,
      PrefetchHooks Function()
    >;
typedef $$ServerBackendsTableCreateCompanionBuilder =
    ServerBackendsCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      required String name,
      required String apiHost,
      Value<bool> secure,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$ServerBackendsTableUpdateCompanionBuilder =
    ServerBackendsCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      Value<String> name,
      Value<String> apiHost,
      Value<bool> secure,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$ServerBackendsTableFilterComposer
    extends Composer<_$Database, $ServerBackendsTable> {
  $$ServerBackendsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiHost => $composableBuilder(
    column: $table.apiHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get secure => $composableBuilder(
    column: $table.secure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServerBackendsTableOrderingComposer
    extends Composer<_$Database, $ServerBackendsTable> {
  $$ServerBackendsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiHost => $composableBuilder(
    column: $table.apiHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get secure => $composableBuilder(
    column: $table.secure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServerBackendsTableAnnotationComposer
    extends Composer<_$Database, $ServerBackendsTable> {
  $$ServerBackendsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<PgDateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get apiHost =>
      $composableBuilder(column: $table.apiHost, builder: (column) => column);

  GeneratedColumn<bool> get secure =>
      $composableBuilder(column: $table.secure, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$ServerBackendsTableTableManager
    extends
        RootTableManager<
          _$Database,
          $ServerBackendsTable,
          ServerBackendEntity,
          $$ServerBackendsTableFilterComposer,
          $$ServerBackendsTableOrderingComposer,
          $$ServerBackendsTableAnnotationComposer,
          $$ServerBackendsTableCreateCompanionBuilder,
          $$ServerBackendsTableUpdateCompanionBuilder,
          (
            ServerBackendEntity,
            BaseReferences<
              _$Database,
              $ServerBackendsTable,
              ServerBackendEntity
            >,
          ),
          ServerBackendEntity,
          PrefetchHooks Function()
        > {
  $$ServerBackendsTableTableManager(_$Database db, $ServerBackendsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServerBackendsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServerBackendsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServerBackendsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> apiHost = const Value.absent(),
                Value<bool> secure = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerBackendsCompanion(
                id: id,
                createdAt: createdAt,
                name: name,
                apiHost: apiHost,
                secure: secure,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                required String name,
                required String apiHost,
                Value<bool> secure = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServerBackendsCompanion.insert(
                id: id,
                createdAt: createdAt,
                name: name,
                apiHost: apiHost,
                secure: secure,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServerBackendsTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $ServerBackendsTable,
      ServerBackendEntity,
      $$ServerBackendsTableFilterComposer,
      $$ServerBackendsTableOrderingComposer,
      $$ServerBackendsTableAnnotationComposer,
      $$ServerBackendsTableCreateCompanionBuilder,
      $$ServerBackendsTableUpdateCompanionBuilder,
      (
        ServerBackendEntity,
        BaseReferences<_$Database, $ServerBackendsTable, ServerBackendEntity>,
      ),
      ServerBackendEntity,
      PrefetchHooks Function()
    >;
typedef $$PeerConnectionsTableCreateCompanionBuilder =
    PeerConnectionsCompanion Function({
      Value<String> id,
      required String publicKey,
      Value<PgDateTime> firstSeenAt,
      Value<PgDateTime> lastSeenAt,
      Value<int> requestCount,
      Value<bool> blocked,
      Value<int> rowid,
    });
typedef $$PeerConnectionsTableUpdateCompanionBuilder =
    PeerConnectionsCompanion Function({
      Value<String> id,
      Value<String> publicKey,
      Value<PgDateTime> firstSeenAt,
      Value<PgDateTime> lastSeenAt,
      Value<int> requestCount,
      Value<bool> blocked,
      Value<int> rowid,
    });

class $$PeerConnectionsTableFilterComposer
    extends Composer<_$Database, $PeerConnectionsTable> {
  $$PeerConnectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<PgDateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<PgDateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeerConnectionsTableOrderingComposer
    extends Composer<_$Database, $PeerConnectionsTable> {
  $$PeerConnectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<PgDateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<PgDateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get blocked => $composableBuilder(
    column: $table.blocked,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeerConnectionsTableAnnotationComposer
    extends Composer<_$Database, $PeerConnectionsTable> {
  $$PeerConnectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<PgDateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<PgDateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requestCount => $composableBuilder(
    column: $table.requestCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get blocked =>
      $composableBuilder(column: $table.blocked, builder: (column) => column);
}

class $$PeerConnectionsTableTableManager
    extends
        RootTableManager<
          _$Database,
          $PeerConnectionsTable,
          PeerConnectionEntity,
          $$PeerConnectionsTableFilterComposer,
          $$PeerConnectionsTableOrderingComposer,
          $$PeerConnectionsTableAnnotationComposer,
          $$PeerConnectionsTableCreateCompanionBuilder,
          $$PeerConnectionsTableUpdateCompanionBuilder,
          (
            PeerConnectionEntity,
            BaseReferences<
              _$Database,
              $PeerConnectionsTable,
              PeerConnectionEntity
            >,
          ),
          PeerConnectionEntity,
          PrefetchHooks Function()
        > {
  $$PeerConnectionsTableTableManager(_$Database db, $PeerConnectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeerConnectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeerConnectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeerConnectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> publicKey = const Value.absent(),
                Value<PgDateTime> firstSeenAt = const Value.absent(),
                Value<PgDateTime> lastSeenAt = const Value.absent(),
                Value<int> requestCount = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerConnectionsCompanion(
                id: id,
                publicKey: publicKey,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                requestCount: requestCount,
                blocked: blocked,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String publicKey,
                Value<PgDateTime> firstSeenAt = const Value.absent(),
                Value<PgDateTime> lastSeenAt = const Value.absent(),
                Value<int> requestCount = const Value.absent(),
                Value<bool> blocked = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerConnectionsCompanion.insert(
                id: id,
                publicKey: publicKey,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                requestCount: requestCount,
                blocked: blocked,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeerConnectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $PeerConnectionsTable,
      PeerConnectionEntity,
      $$PeerConnectionsTableFilterComposer,
      $$PeerConnectionsTableOrderingComposer,
      $$PeerConnectionsTableAnnotationComposer,
      $$PeerConnectionsTableCreateCompanionBuilder,
      $$PeerConnectionsTableUpdateCompanionBuilder,
      (
        PeerConnectionEntity,
        BaseReferences<_$Database, $PeerConnectionsTable, PeerConnectionEntity>,
      ),
      PeerConnectionEntity,
      PrefetchHooks Function()
    >;
typedef $$WorkspacesTableCreateCompanionBuilder =
    WorkspacesCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      required String userId,
      required String name,
      Value<bool> isDefault,
      Value<int> rowid,
    });
typedef $$WorkspacesTableUpdateCompanionBuilder =
    WorkspacesCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      Value<String> userId,
      Value<String> name,
      Value<bool> isDefault,
      Value<int> rowid,
    });

class $$WorkspacesTableFilterComposer
    extends Composer<_$Database, $WorkspacesTable> {
  $$WorkspacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkspacesTableOrderingComposer
    extends Composer<_$Database, $WorkspacesTable> {
  $$WorkspacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkspacesTableAnnotationComposer
    extends Composer<_$Database, $WorkspacesTable> {
  $$WorkspacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<PgDateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);
}

class $$WorkspacesTableTableManager
    extends
        RootTableManager<
          _$Database,
          $WorkspacesTable,
          WorkspaceEntity,
          $$WorkspacesTableFilterComposer,
          $$WorkspacesTableOrderingComposer,
          $$WorkspacesTableAnnotationComposer,
          $$WorkspacesTableCreateCompanionBuilder,
          $$WorkspacesTableUpdateCompanionBuilder,
          (
            WorkspaceEntity,
            BaseReferences<_$Database, $WorkspacesTable, WorkspaceEntity>,
          ),
          WorkspaceEntity,
          PrefetchHooks Function()
        > {
  $$WorkspacesTableTableManager(_$Database db, $WorkspacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion(
                id: id,
                createdAt: createdAt,
                userId: userId,
                name: name,
                isDefault: isDefault,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                required String userId,
                required String name,
                Value<bool> isDefault = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkspacesCompanion.insert(
                id: id,
                createdAt: createdAt,
                userId: userId,
                name: name,
                isDefault: isDefault,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkspacesTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $WorkspacesTable,
      WorkspaceEntity,
      $$WorkspacesTableFilterComposer,
      $$WorkspacesTableOrderingComposer,
      $$WorkspacesTableAnnotationComposer,
      $$WorkspacesTableCreateCompanionBuilder,
      $$WorkspacesTableUpdateCompanionBuilder,
      (
        WorkspaceEntity,
        BaseReferences<_$Database, $WorkspacesTable, WorkspaceEntity>,
      ),
      WorkspaceEntity,
      PrefetchHooks Function()
    >;
typedef $$LyricSheetsTableCreateCompanionBuilder =
    LyricSheetsCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      required String userId,
      Value<String> title,
      Value<String> content,
      Value<int> rowid,
    });
typedef $$LyricSheetsTableUpdateCompanionBuilder =
    LyricSheetsCompanion Function({
      Value<String> id,
      Value<PgDateTime> createdAt,
      Value<String> userId,
      Value<String> title,
      Value<String> content,
      Value<int> rowid,
    });

class $$LyricSheetsTableFilterComposer
    extends Composer<_$Database, $LyricSheetsTable> {
  $$LyricSheetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LyricSheetsTableOrderingComposer
    extends Composer<_$Database, $LyricSheetsTable> {
  $$LyricSheetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<PgDateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LyricSheetsTableAnnotationComposer
    extends Composer<_$Database, $LyricSheetsTable> {
  $$LyricSheetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<PgDateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$LyricSheetsTableTableManager
    extends
        RootTableManager<
          _$Database,
          $LyricSheetsTable,
          LyricSheetEntity,
          $$LyricSheetsTableFilterComposer,
          $$LyricSheetsTableOrderingComposer,
          $$LyricSheetsTableAnnotationComposer,
          $$LyricSheetsTableCreateCompanionBuilder,
          $$LyricSheetsTableUpdateCompanionBuilder,
          (
            LyricSheetEntity,
            BaseReferences<_$Database, $LyricSheetsTable, LyricSheetEntity>,
          ),
          LyricSheetEntity,
          PrefetchHooks Function()
        > {
  $$LyricSheetsTableTableManager(_$Database db, $LyricSheetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricSheetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricSheetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricSheetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricSheetsCompanion(
                id: id,
                createdAt: createdAt,
                userId: userId,
                title: title,
                content: content,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PgDateTime> createdAt = const Value.absent(),
                required String userId,
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricSheetsCompanion.insert(
                id: id,
                createdAt: createdAt,
                userId: userId,
                title: title,
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LyricSheetsTableProcessedTableManager =
    ProcessedTableManager<
      _$Database,
      $LyricSheetsTable,
      LyricSheetEntity,
      $$LyricSheetsTableFilterComposer,
      $$LyricSheetsTableOrderingComposer,
      $$LyricSheetsTableAnnotationComposer,
      $$LyricSheetsTableCreateCompanionBuilder,
      $$LyricSheetsTableUpdateCompanionBuilder,
      (
        LyricSheetEntity,
        BaseReferences<_$Database, $LyricSheetsTable, LyricSheetEntity>,
      ),
      LyricSheetEntity,
      PrefetchHooks Function()
    >;

class $DatabaseManager {
  final _$Database _db;
  $DatabaseManager(this._db);
  $$UserTableTableManager get user => $$UserTableTableManager(_db, _db.user);
  $$AudioGenerationTaskTableTableManager get audioGenerationTask =>
      $$AudioGenerationTaskTableTableManager(_db, _db.audioGenerationTask);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$ServerBackendsTableTableManager get serverBackends =>
      $$ServerBackendsTableTableManager(_db, _db.serverBackends);
  $$PeerConnectionsTableTableManager get peerConnections =>
      $$PeerConnectionsTableTableManager(_db, _db.peerConnections);
  $$WorkspacesTableTableManager get workspaces =>
      $$WorkspacesTableTableManager(_db, _db.workspaces);
  $$LyricSheetsTableTableManager get lyricSheets =>
      $$LyricSheetsTableTableManager(_db, _db.lyricSheets);
}
