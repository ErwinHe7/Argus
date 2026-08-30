// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_snapshot.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathSnapshotCWProxy {
  StarpathSnapshot answer(StarpathAnswerFeedback? answer);

  StarpathSnapshot authority(StarpathAuthority authority);

  StarpathSnapshot availability(StarpathSnapshotAvailabilityEnum availability);

  StarpathSnapshot commandEffect(
    StarpathSnapshotCommandEffectEnum? commandEffect,
  );

  StarpathSnapshot nodes(List<StarpathNode> nodes);

  StarpathSnapshot progress(StarpathProgress? progress);

  StarpathSnapshot recall(StarpathRecall? recall);

  StarpathSnapshot session(StarpathSession? session);

  StarpathSnapshot theme(StarpathSessionTheme? theme);

  StarpathSnapshot version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathSnapshot(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathSnapshot(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathSnapshot call({
    StarpathAnswerFeedback? answer,
    StarpathAuthority authority,
    StarpathSnapshotAvailabilityEnum availability,
    StarpathSnapshotCommandEffectEnum? commandEffect,
    List<StarpathNode> nodes,
    StarpathProgress? progress,
    StarpathRecall? recall,
    StarpathSession? session,
    StarpathSessionTheme? theme,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathSnapshot.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathSnapshot.copyWith.fieldName(...)`
class _$StarpathSnapshotCWProxyImpl implements _$StarpathSnapshotCWProxy {
  const _$StarpathSnapshotCWProxyImpl(this._value);

  final StarpathSnapshot _value;

  @override
  StarpathSnapshot answer(StarpathAnswerFeedback? answer) =>
      this(answer: answer);

  @override
  StarpathSnapshot authority(StarpathAuthority authority) =>
      this(authority: authority);

  @override
  StarpathSnapshot availability(
    StarpathSnapshotAvailabilityEnum availability,
  ) => this(availability: availability);

  @override
  StarpathSnapshot commandEffect(
    StarpathSnapshotCommandEffectEnum? commandEffect,
  ) => this(commandEffect: commandEffect);

  @override
  StarpathSnapshot nodes(List<StarpathNode> nodes) => this(nodes: nodes);

  @override
  StarpathSnapshot progress(StarpathProgress? progress) =>
      this(progress: progress);

  @override
  StarpathSnapshot recall(StarpathRecall? recall) => this(recall: recall);

  @override
  StarpathSnapshot session(StarpathSession? session) => this(session: session);

  @override
  StarpathSnapshot theme(StarpathSessionTheme? theme) => this(theme: theme);

  @override
  StarpathSnapshot version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathSnapshot(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathSnapshot(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathSnapshot call({
    Object? answer = const $CopyWithPlaceholder(),
    Object? authority = const $CopyWithPlaceholder(),
    Object? availability = const $CopyWithPlaceholder(),
    Object? commandEffect = const $CopyWithPlaceholder(),
    Object? nodes = const $CopyWithPlaceholder(),
    Object? progress = const $CopyWithPlaceholder(),
    Object? recall = const $CopyWithPlaceholder(),
    Object? session = const $CopyWithPlaceholder(),
    Object? theme = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return StarpathSnapshot(
      answer: answer == const $CopyWithPlaceholder()
          ? _value.answer
          // ignore: cast_nullable_to_non_nullable
          : answer as StarpathAnswerFeedback?,
      authority: authority == const $CopyWithPlaceholder()
          ? _value.authority
          // ignore: cast_nullable_to_non_nullable
          : authority as StarpathAuthority,
      availability: availability == const $CopyWithPlaceholder()
          ? _value.availability
          // ignore: cast_nullable_to_non_nullable
          : availability as StarpathSnapshotAvailabilityEnum,
      commandEffect: commandEffect == const $CopyWithPlaceholder()
          ? _value.commandEffect
          // ignore: cast_nullable_to_non_nullable
          : commandEffect as StarpathSnapshotCommandEffectEnum?,
      nodes: nodes == const $CopyWithPlaceholder()
          ? _value.nodes
          // ignore: cast_nullable_to_non_nullable
          : nodes as List<StarpathNode>,
      progress: progress == const $CopyWithPlaceholder()
          ? _value.progress
          // ignore: cast_nullable_to_non_nullable
          : progress as StarpathProgress?,
      recall: recall == const $CopyWithPlaceholder()
          ? _value.recall
          // ignore: cast_nullable_to_non_nullable
          : recall as StarpathRecall?,
      session: session == const $CopyWithPlaceholder()
          ? _value.session
          // ignore: cast_nullable_to_non_nullable
          : session as StarpathSession?,
      theme: theme == const $CopyWithPlaceholder()
          ? _value.theme
          // ignore: cast_nullable_to_non_nullable
          : theme as StarpathSessionTheme?,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $StarpathSnapshotCopyWith on StarpathSnapshot {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathSnapshot.copyWith(...)` or like so:`instanceOfStarpathSnapshot.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathSnapshotCWProxy get copyWith => _$StarpathSnapshotCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathSnapshot _$StarpathSnapshotFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('StarpathSnapshot', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'answer',
      'authority',
      'availability',
      'command_effect',
      'nodes',
      'progress',
      'recall',
      'session',
      'theme',
      'version',
    ],
  );
  final val = StarpathSnapshot(
    answer: $checkedConvert(
      'answer',
      (v) => v == null
          ? null
          : StarpathAnswerFeedback.fromJson(v as Map<String, dynamic>),
    ),
    authority: $checkedConvert(
      'authority',
      (v) => StarpathAuthority.fromJson(v as Map<String, dynamic>),
    ),
    availability: $checkedConvert(
      'availability',
      (v) => $enumDecode(
        _$StarpathSnapshotAvailabilityEnumEnumMap,
        v,
        unknownValue: StarpathSnapshotAvailabilityEnum.unknownDefaultOpenApi,
      ),
    ),
    commandEffect: $checkedConvert(
      'command_effect',
      (v) => $enumDecodeNullable(
        _$StarpathSnapshotCommandEffectEnumEnumMap,
        v,
        unknownValue: StarpathSnapshotCommandEffectEnum.unknownDefaultOpenApi,
      ),
    ),
    nodes: $checkedConvert(
      'nodes',
      (v) => (v as List<dynamic>)
          .map((e) => StarpathNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    progress: $checkedConvert(
      'progress',
      (v) => v == null
          ? null
          : StarpathProgress.fromJson(v as Map<String, dynamic>),
    ),
    recall: $checkedConvert(
      'recall',
      (v) =>
          v == null ? null : StarpathRecall.fromJson(v as Map<String, dynamic>),
    ),
    session: $checkedConvert(
      'session',
      (v) => v == null
          ? null
          : StarpathSession.fromJson(v as Map<String, dynamic>),
    ),
    theme: $checkedConvert(
      'theme',
      (v) => v == null
          ? null
          : StarpathSessionTheme.fromJson(v as Map<String, dynamic>),
    ),
    version: $checkedConvert('version', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'commandEffect': 'command_effect'});

Map<String, dynamic> _$StarpathSnapshotToJson(StarpathSnapshot instance) =>
    <String, dynamic>{
      'answer': instance.answer?.toJson(),
      'authority': instance.authority.toJson(),
      'availability':
          _$StarpathSnapshotAvailabilityEnumEnumMap[instance.availability]!,
      'command_effect':
          _$StarpathSnapshotCommandEffectEnumEnumMap[instance.commandEffect],
      'nodes': instance.nodes.map((e) => e.toJson()).toList(),
      'progress': instance.progress?.toJson(),
      'recall': instance.recall?.toJson(),
      'session': instance.session?.toJson(),
      'theme': instance.theme?.toJson(),
      'version': instance.version,
    };

const _$StarpathSnapshotAvailabilityEnumEnumMap = {
  StarpathSnapshotAvailabilityEnum.available: 'available',
  StarpathSnapshotAvailabilityEnum.notStarted: 'not_started',
  StarpathSnapshotAvailabilityEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$StarpathSnapshotCommandEffectEnumEnumMap = {
  StarpathSnapshotCommandEffectEnum.started: 'started',
  StarpathSnapshotCommandEffectEnum.resumed: 'resumed',
  StarpathSnapshotCommandEffectEnum.contentReplaced: 'content_replaced',
  StarpathSnapshotCommandEffectEnum.wrongAnswer: 'wrong_answer',
  StarpathSnapshotCommandEffectEnum.lessonCompleted: 'lesson_completed',
  StarpathSnapshotCommandEffectEnum.recallCompleted: 'recall_completed',
  StarpathSnapshotCommandEffectEnum.recallSkipped: 'recall_skipped',
  StarpathSnapshotCommandEffectEnum.semanticReplay: 'semantic_replay',
  StarpathSnapshotCommandEffectEnum.idempotentReplay: 'idempotent_replay',
  StarpathSnapshotCommandEffectEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
