// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_recurring_plan_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchRecurringPlanRequestCWProxy {
  PatchRecurringPlanRequest allocations(
    List<CreateRecurringPlanRequestAllocationsInner>? allocations,
  );

  PatchRecurringPlanRequest amount(PositiveInputMoney? amount);

  PatchRecurringPlanRequest frequency(
    PatchRecurringPlanRequestFrequencyEnum? frequency,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchRecurringPlanRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchRecurringPlanRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchRecurringPlanRequest call({
    List<CreateRecurringPlanRequestAllocationsInner>? allocations,
    PositiveInputMoney? amount,
    PatchRecurringPlanRequestFrequencyEnum? frequency,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchRecurringPlanRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchRecurringPlanRequest.copyWith.fieldName(...)`
class _$PatchRecurringPlanRequestCWProxyImpl
    implements _$PatchRecurringPlanRequestCWProxy {
  const _$PatchRecurringPlanRequestCWProxyImpl(this._value);

  final PatchRecurringPlanRequest _value;

  @override
  PatchRecurringPlanRequest allocations(
    List<CreateRecurringPlanRequestAllocationsInner>? allocations,
  ) => this(allocations: allocations);

  @override
  PatchRecurringPlanRequest amount(PositiveInputMoney? amount) =>
      this(amount: amount);

  @override
  PatchRecurringPlanRequest frequency(
    PatchRecurringPlanRequestFrequencyEnum? frequency,
  ) => this(frequency: frequency);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchRecurringPlanRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchRecurringPlanRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchRecurringPlanRequest call({
    Object? allocations = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? frequency = const $CopyWithPlaceholder(),
  }) {
    return PatchRecurringPlanRequest(
      allocations: allocations == const $CopyWithPlaceholder()
          ? _value.allocations
          // ignore: cast_nullable_to_non_nullable
          : allocations as List<CreateRecurringPlanRequestAllocationsInner>?,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as PositiveInputMoney?,
      frequency: frequency == const $CopyWithPlaceholder()
          ? _value.frequency
          // ignore: cast_nullable_to_non_nullable
          : frequency as PatchRecurringPlanRequestFrequencyEnum?,
    );
  }
}

extension $PatchRecurringPlanRequestCopyWith on PatchRecurringPlanRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchRecurringPlanRequest.copyWith(...)` or like so:`instanceOfPatchRecurringPlanRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchRecurringPlanRequestCWProxy get copyWith =>
      _$PatchRecurringPlanRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchRecurringPlanRequest _$PatchRecurringPlanRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchRecurringPlanRequest', json, ($checkedConvert) {
  final val = PatchRecurringPlanRequest(
    allocations: $checkedConvert(
      'allocations',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) => CreateRecurringPlanRequestAllocationsInner.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    ),
    amount: $checkedConvert(
      'amount',
      (v) => v == null
          ? null
          : PositiveInputMoney.fromJson(v as Map<String, dynamic>),
    ),
    frequency: $checkedConvert(
      'frequency',
      (v) => $enumDecodeNullable(
        _$PatchRecurringPlanRequestFrequencyEnumEnumMap,
        v,
        unknownValue:
            PatchRecurringPlanRequestFrequencyEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$PatchRecurringPlanRequestToJson(
  PatchRecurringPlanRequest instance,
) => <String, dynamic>{
  'allocations': ?instance.allocations?.map((e) => e.toJson()).toList(),
  'amount': ?instance.amount?.toJson(),
  'frequency':
      ?_$PatchRecurringPlanRequestFrequencyEnumEnumMap[instance.frequency],
};

const _$PatchRecurringPlanRequestFrequencyEnumEnumMap = {
  PatchRecurringPlanRequestFrequencyEnum.weekly: 'weekly',
  PatchRecurringPlanRequestFrequencyEnum.monthly: 'monthly',
  PatchRecurringPlanRequestFrequencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
