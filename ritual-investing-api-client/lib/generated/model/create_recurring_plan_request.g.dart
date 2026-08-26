// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_recurring_plan_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateRecurringPlanRequestCWProxy {
  CreateRecurringPlanRequest allocations(
    List<CreateRecurringPlanRequestAllocationsInner> allocations,
  );

  CreateRecurringPlanRequest amount(PositiveInputMoney amount);

  CreateRecurringPlanRequest firstRunAt(DateTime firstRunAt);

  CreateRecurringPlanRequest frequency(
    CreateRecurringPlanRequestFrequencyEnum frequency,
  );

  CreateRecurringPlanRequest sourceId(String sourceId);

  CreateRecurringPlanRequest type(CreateRecurringPlanRequestTypeEnum type);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRecurringPlanRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRecurringPlanRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRecurringPlanRequest call({
    List<CreateRecurringPlanRequestAllocationsInner> allocations,
    PositiveInputMoney amount,
    DateTime firstRunAt,
    CreateRecurringPlanRequestFrequencyEnum frequency,
    String sourceId,
    CreateRecurringPlanRequestTypeEnum type,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateRecurringPlanRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateRecurringPlanRequest.copyWith.fieldName(...)`
class _$CreateRecurringPlanRequestCWProxyImpl
    implements _$CreateRecurringPlanRequestCWProxy {
  const _$CreateRecurringPlanRequestCWProxyImpl(this._value);

  final CreateRecurringPlanRequest _value;

  @override
  CreateRecurringPlanRequest allocations(
    List<CreateRecurringPlanRequestAllocationsInner> allocations,
  ) => this(allocations: allocations);

  @override
  CreateRecurringPlanRequest amount(PositiveInputMoney amount) =>
      this(amount: amount);

  @override
  CreateRecurringPlanRequest firstRunAt(DateTime firstRunAt) =>
      this(firstRunAt: firstRunAt);

  @override
  CreateRecurringPlanRequest frequency(
    CreateRecurringPlanRequestFrequencyEnum frequency,
  ) => this(frequency: frequency);

  @override
  CreateRecurringPlanRequest sourceId(String sourceId) =>
      this(sourceId: sourceId);

  @override
  CreateRecurringPlanRequest type(CreateRecurringPlanRequestTypeEnum type) =>
      this(type: type);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRecurringPlanRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRecurringPlanRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRecurringPlanRequest call({
    Object? allocations = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? firstRunAt = const $CopyWithPlaceholder(),
    Object? frequency = const $CopyWithPlaceholder(),
    Object? sourceId = const $CopyWithPlaceholder(),
    Object? type = const $CopyWithPlaceholder(),
  }) {
    return CreateRecurringPlanRequest(
      allocations: allocations == const $CopyWithPlaceholder()
          ? _value.allocations
          // ignore: cast_nullable_to_non_nullable
          : allocations as List<CreateRecurringPlanRequestAllocationsInner>,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as PositiveInputMoney,
      firstRunAt: firstRunAt == const $CopyWithPlaceholder()
          ? _value.firstRunAt
          // ignore: cast_nullable_to_non_nullable
          : firstRunAt as DateTime,
      frequency: frequency == const $CopyWithPlaceholder()
          ? _value.frequency
          // ignore: cast_nullable_to_non_nullable
          : frequency as CreateRecurringPlanRequestFrequencyEnum,
      sourceId: sourceId == const $CopyWithPlaceholder()
          ? _value.sourceId
          // ignore: cast_nullable_to_non_nullable
          : sourceId as String,
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as CreateRecurringPlanRequestTypeEnum,
    );
  }
}

extension $CreateRecurringPlanRequestCopyWith on CreateRecurringPlanRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateRecurringPlanRequest.copyWith(...)` or like so:`instanceOfCreateRecurringPlanRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateRecurringPlanRequestCWProxy get copyWith =>
      _$CreateRecurringPlanRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateRecurringPlanRequest _$CreateRecurringPlanRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateRecurringPlanRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'allocations',
      'amount',
      'first_run_at',
      'frequency',
      'source_id',
      'type',
    ],
  );
  final val = CreateRecurringPlanRequest(
    allocations: $checkedConvert(
      'allocations',
      (v) => (v as List<dynamic>)
          .map(
            (e) => CreateRecurringPlanRequestAllocationsInner.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    ),
    amount: $checkedConvert(
      'amount',
      (v) => PositiveInputMoney.fromJson(v as Map<String, dynamic>),
    ),
    firstRunAt: $checkedConvert(
      'first_run_at',
      (v) => DateTime.parse(v as String),
    ),
    frequency: $checkedConvert(
      'frequency',
      (v) => $enumDecode(
        _$CreateRecurringPlanRequestFrequencyEnumEnumMap,
        v,
        unknownValue:
            CreateRecurringPlanRequestFrequencyEnum.unknownDefaultOpenApi,
      ),
    ),
    sourceId: $checkedConvert('source_id', (v) => v as String),
    type: $checkedConvert(
      'type',
      (v) => $enumDecode(
        _$CreateRecurringPlanRequestTypeEnumEnumMap,
        v,
        unknownValue: CreateRecurringPlanRequestTypeEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'firstRunAt': 'first_run_at', 'sourceId': 'source_id'});

Map<String, dynamic> _$CreateRecurringPlanRequestToJson(
  CreateRecurringPlanRequest instance,
) => <String, dynamic>{
  'allocations': instance.allocations.map((e) => e.toJson()).toList(),
  'amount': instance.amount.toJson(),
  'first_run_at': instance.firstRunAt.toIso8601String(),
  'frequency':
      _$CreateRecurringPlanRequestFrequencyEnumEnumMap[instance.frequency]!,
  'source_id': instance.sourceId,
  'type': _$CreateRecurringPlanRequestTypeEnumEnumMap[instance.type]!,
};

const _$CreateRecurringPlanRequestFrequencyEnumEnumMap = {
  CreateRecurringPlanRequestFrequencyEnum.weekly: 'weekly',
  CreateRecurringPlanRequestFrequencyEnum.monthly: 'monthly',
  CreateRecurringPlanRequestFrequencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$CreateRecurringPlanRequestTypeEnumEnumMap = {
  CreateRecurringPlanRequestTypeEnum.contribution: 'contribution',
  CreateRecurringPlanRequestTypeEnum.allocation: 'allocation',
  CreateRecurringPlanRequestTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
