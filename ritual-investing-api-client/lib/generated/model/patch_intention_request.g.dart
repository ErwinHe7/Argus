// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_intention_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchIntentionRequestCWProxy {
  PatchIntentionRequest status(PatchIntentionRequestStatusEnum? status);

  PatchIntentionRequest target(PositiveInputMoney? target);

  PatchIntentionRequest targetDate(DateTime? targetDate);

  PatchIntentionRequest title(String? title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchIntentionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchIntentionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchIntentionRequest call({
    PatchIntentionRequestStatusEnum? status,
    PositiveInputMoney? target,
    DateTime? targetDate,
    String? title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchIntentionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchIntentionRequest.copyWith.fieldName(...)`
class _$PatchIntentionRequestCWProxyImpl
    implements _$PatchIntentionRequestCWProxy {
  const _$PatchIntentionRequestCWProxyImpl(this._value);

  final PatchIntentionRequest _value;

  @override
  PatchIntentionRequest status(PatchIntentionRequestStatusEnum? status) =>
      this(status: status);

  @override
  PatchIntentionRequest target(PositiveInputMoney? target) =>
      this(target: target);

  @override
  PatchIntentionRequest targetDate(DateTime? targetDate) =>
      this(targetDate: targetDate);

  @override
  PatchIntentionRequest title(String? title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchIntentionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchIntentionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchIntentionRequest call({
    Object? status = const $CopyWithPlaceholder(),
    Object? target = const $CopyWithPlaceholder(),
    Object? targetDate = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return PatchIntentionRequest(
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PatchIntentionRequestStatusEnum?,
      target: target == const $CopyWithPlaceholder()
          ? _value.target
          // ignore: cast_nullable_to_non_nullable
          : target as PositiveInputMoney?,
      targetDate: targetDate == const $CopyWithPlaceholder()
          ? _value.targetDate
          // ignore: cast_nullable_to_non_nullable
          : targetDate as DateTime?,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
    );
  }
}

extension $PatchIntentionRequestCopyWith on PatchIntentionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchIntentionRequest.copyWith(...)` or like so:`instanceOfPatchIntentionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchIntentionRequestCWProxy get copyWith =>
      _$PatchIntentionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchIntentionRequest _$PatchIntentionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchIntentionRequest', json, ($checkedConvert) {
  final val = PatchIntentionRequest(
    status: $checkedConvert(
      'status',
      (v) => $enumDecodeNullable(
        _$PatchIntentionRequestStatusEnumEnumMap,
        v,
        unknownValue: PatchIntentionRequestStatusEnum.unknownDefaultOpenApi,
      ),
    ),
    target: $checkedConvert(
      'target',
      (v) => v == null
          ? null
          : PositiveInputMoney.fromJson(v as Map<String, dynamic>),
    ),
    targetDate: $checkedConvert(
      'target_date',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    title: $checkedConvert('title', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'targetDate': 'target_date'});

Map<String, dynamic> _$PatchIntentionRequestToJson(
  PatchIntentionRequest instance,
) => <String, dynamic>{
  'status': ?_$PatchIntentionRequestStatusEnumEnumMap[instance.status],
  'target': ?instance.target?.toJson(),
  'target_date': ?instance.targetDate?.toIso8601String(),
  'title': ?instance.title,
};

const _$PatchIntentionRequestStatusEnumEnumMap = {
  PatchIntentionRequestStatusEnum.active: 'active',
  PatchIntentionRequestStatusEnum.completed: 'completed',
  PatchIntentionRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
