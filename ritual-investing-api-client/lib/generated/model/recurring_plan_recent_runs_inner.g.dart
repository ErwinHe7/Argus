// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_plan_recent_runs_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RecurringPlanRecentRunsInnerCWProxy {
  RecurringPlanRecentRunsInner id(String id);

  RecurringPlanRecentRunsInner scheduledFor(DateTime scheduledFor);

  RecurringPlanRecentRunsInner status(
    RecurringPlanRecentRunsInnerStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RecurringPlanRecentRunsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RecurringPlanRecentRunsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  RecurringPlanRecentRunsInner call({
    String id,
    DateTime scheduledFor,
    RecurringPlanRecentRunsInnerStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRecurringPlanRecentRunsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRecurringPlanRecentRunsInner.copyWith.fieldName(...)`
class _$RecurringPlanRecentRunsInnerCWProxyImpl
    implements _$RecurringPlanRecentRunsInnerCWProxy {
  const _$RecurringPlanRecentRunsInnerCWProxyImpl(this._value);

  final RecurringPlanRecentRunsInner _value;

  @override
  RecurringPlanRecentRunsInner id(String id) => this(id: id);

  @override
  RecurringPlanRecentRunsInner scheduledFor(DateTime scheduledFor) =>
      this(scheduledFor: scheduledFor);

  @override
  RecurringPlanRecentRunsInner status(
    RecurringPlanRecentRunsInnerStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RecurringPlanRecentRunsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RecurringPlanRecentRunsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  RecurringPlanRecentRunsInner call({
    Object? id = const $CopyWithPlaceholder(),
    Object? scheduledFor = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return RecurringPlanRecentRunsInner(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      scheduledFor: scheduledFor == const $CopyWithPlaceholder()
          ? _value.scheduledFor
          // ignore: cast_nullable_to_non_nullable
          : scheduledFor as DateTime,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as RecurringPlanRecentRunsInnerStatusEnum,
    );
  }
}

extension $RecurringPlanRecentRunsInnerCopyWith
    on RecurringPlanRecentRunsInner {
  /// Returns a callable class that can be used as follows: `instanceOfRecurringPlanRecentRunsInner.copyWith(...)` or like so:`instanceOfRecurringPlanRecentRunsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RecurringPlanRecentRunsInnerCWProxy get copyWith =>
      _$RecurringPlanRecentRunsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecurringPlanRecentRunsInner _$RecurringPlanRecentRunsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RecurringPlanRecentRunsInner', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['id', 'scheduled_for', 'status']);
  final val = RecurringPlanRecentRunsInner(
    id: $checkedConvert('id', (v) => v as String),
    scheduledFor: $checkedConvert(
      'scheduled_for',
      (v) => DateTime.parse(v as String),
    ),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$RecurringPlanRecentRunsInnerStatusEnumEnumMap,
        v,
        unknownValue:
            RecurringPlanRecentRunsInnerStatusEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'scheduledFor': 'scheduled_for'});

Map<String, dynamic> _$RecurringPlanRecentRunsInnerToJson(
  RecurringPlanRecentRunsInner instance,
) => <String, dynamic>{
  'id': instance.id,
  'scheduled_for': instance.scheduledFor.toIso8601String(),
  'status': _$RecurringPlanRecentRunsInnerStatusEnumEnumMap[instance.status]!,
};

const _$RecurringPlanRecentRunsInnerStatusEnumEnumMap = {
  RecurringPlanRecentRunsInnerStatusEnum.due: 'due',
  RecurringPlanRecentRunsInnerStatusEnum.running: 'running',
  RecurringPlanRecentRunsInnerStatusEnum.completed: 'completed',
  RecurringPlanRecentRunsInnerStatusEnum.rejected: 'rejected',
  RecurringPlanRecentRunsInnerStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
