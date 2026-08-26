// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intention.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$IntentionCWProxy {
  Intention demo(SimulationDemoDisclosure demo);

  Intention id(String id);

  Intention latestProjectionId(String? latestProjectionId);

  Intention portfolioId(String portfolioId);

  Intention progress(Money progress);

  Intention progressBps(int progressBps);

  Intention status(IntentionStatusEnum status);

  Intention target(Money target);

  Intention targetDate(DateTime targetDate);

  Intention title(String title);

  Intention version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Intention(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Intention(...).copyWith(id: 12, name: "My name")
  /// ````
  Intention call({
    SimulationDemoDisclosure demo,
    String id,
    String? latestProjectionId,
    String portfolioId,
    Money progress,
    int progressBps,
    IntentionStatusEnum status,
    Money target,
    DateTime targetDate,
    String title,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfIntention.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfIntention.copyWith.fieldName(...)`
class _$IntentionCWProxyImpl implements _$IntentionCWProxy {
  const _$IntentionCWProxyImpl(this._value);

  final Intention _value;

  @override
  Intention demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  Intention id(String id) => this(id: id);

  @override
  Intention latestProjectionId(String? latestProjectionId) =>
      this(latestProjectionId: latestProjectionId);

  @override
  Intention portfolioId(String portfolioId) => this(portfolioId: portfolioId);

  @override
  Intention progress(Money progress) => this(progress: progress);

  @override
  Intention progressBps(int progressBps) => this(progressBps: progressBps);

  @override
  Intention status(IntentionStatusEnum status) => this(status: status);

  @override
  Intention target(Money target) => this(target: target);

  @override
  Intention targetDate(DateTime targetDate) => this(targetDate: targetDate);

  @override
  Intention title(String title) => this(title: title);

  @override
  Intention version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Intention(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Intention(...).copyWith(id: 12, name: "My name")
  /// ````
  Intention call({
    Object? demo = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? latestProjectionId = const $CopyWithPlaceholder(),
    Object? portfolioId = const $CopyWithPlaceholder(),
    Object? progress = const $CopyWithPlaceholder(),
    Object? progressBps = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? target = const $CopyWithPlaceholder(),
    Object? targetDate = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return Intention(
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      latestProjectionId: latestProjectionId == const $CopyWithPlaceholder()
          ? _value.latestProjectionId
          // ignore: cast_nullable_to_non_nullable
          : latestProjectionId as String?,
      portfolioId: portfolioId == const $CopyWithPlaceholder()
          ? _value.portfolioId
          // ignore: cast_nullable_to_non_nullable
          : portfolioId as String,
      progress: progress == const $CopyWithPlaceholder()
          ? _value.progress
          // ignore: cast_nullable_to_non_nullable
          : progress as Money,
      progressBps: progressBps == const $CopyWithPlaceholder()
          ? _value.progressBps
          // ignore: cast_nullable_to_non_nullable
          : progressBps as int,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as IntentionStatusEnum,
      target: target == const $CopyWithPlaceholder()
          ? _value.target
          // ignore: cast_nullable_to_non_nullable
          : target as Money,
      targetDate: targetDate == const $CopyWithPlaceholder()
          ? _value.targetDate
          // ignore: cast_nullable_to_non_nullable
          : targetDate as DateTime,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $IntentionCopyWith on Intention {
  /// Returns a callable class that can be used as follows: `instanceOfIntention.copyWith(...)` or like so:`instanceOfIntention.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$IntentionCWProxy get copyWith => _$IntentionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Intention _$IntentionFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Intention',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'demo',
        'id',
        'latest_projection_id',
        'portfolio_id',
        'progress',
        'progress_bps',
        'status',
        'target',
        'target_date',
        'title',
        'version',
      ],
    );
    final val = Intention(
      demo: $checkedConvert(
        'demo',
        (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
      ),
      id: $checkedConvert('id', (v) => v as String),
      latestProjectionId: $checkedConvert(
        'latest_projection_id',
        (v) => v as String?,
      ),
      portfolioId: $checkedConvert('portfolio_id', (v) => v as String),
      progress: $checkedConvert(
        'progress',
        (v) => Money.fromJson(v as Map<String, dynamic>),
      ),
      progressBps: $checkedConvert('progress_bps', (v) => (v as num).toInt()),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$IntentionStatusEnumEnumMap,
          v,
          unknownValue: IntentionStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      target: $checkedConvert(
        'target',
        (v) => Money.fromJson(v as Map<String, dynamic>),
      ),
      targetDate: $checkedConvert(
        'target_date',
        (v) => DateTime.parse(v as String),
      ),
      title: $checkedConvert('title', (v) => v as String),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'latestProjectionId': 'latest_projection_id',
    'portfolioId': 'portfolio_id',
    'progressBps': 'progress_bps',
    'targetDate': 'target_date',
  },
);

Map<String, dynamic> _$IntentionToJson(Intention instance) => <String, dynamic>{
  'demo': instance.demo.toJson(),
  'id': instance.id,
  'latest_projection_id': instance.latestProjectionId,
  'portfolio_id': instance.portfolioId,
  'progress': instance.progress.toJson(),
  'progress_bps': instance.progressBps,
  'status': _$IntentionStatusEnumEnumMap[instance.status]!,
  'target': instance.target.toJson(),
  'target_date': instance.targetDate.toIso8601String(),
  'title': instance.title,
  'version': instance.version,
};

const _$IntentionStatusEnumEnumMap = {
  IntentionStatusEnum.active: 'active',
  IntentionStatusEnum.completed: 'completed',
  IntentionStatusEnum.archived: 'archived',
  IntentionStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
