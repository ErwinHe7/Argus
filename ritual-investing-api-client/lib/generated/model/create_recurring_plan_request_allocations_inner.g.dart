// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_recurring_plan_request_allocations_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateRecurringPlanRequestAllocationsInnerCWProxy {
  CreateRecurringPlanRequestAllocationsInner assetId(String assetId);

  CreateRecurringPlanRequestAllocationsInner weightBps(int weightBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRecurringPlanRequestAllocationsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRecurringPlanRequestAllocationsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRecurringPlanRequestAllocationsInner call({
    String assetId,
    int weightBps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateRecurringPlanRequestAllocationsInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateRecurringPlanRequestAllocationsInner.copyWith.fieldName(...)`
class _$CreateRecurringPlanRequestAllocationsInnerCWProxyImpl
    implements _$CreateRecurringPlanRequestAllocationsInnerCWProxy {
  const _$CreateRecurringPlanRequestAllocationsInnerCWProxyImpl(this._value);

  final CreateRecurringPlanRequestAllocationsInner _value;

  @override
  CreateRecurringPlanRequestAllocationsInner assetId(String assetId) =>
      this(assetId: assetId);

  @override
  CreateRecurringPlanRequestAllocationsInner weightBps(int weightBps) =>
      this(weightBps: weightBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateRecurringPlanRequestAllocationsInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateRecurringPlanRequestAllocationsInner(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateRecurringPlanRequestAllocationsInner call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? weightBps = const $CopyWithPlaceholder(),
  }) {
    return CreateRecurringPlanRequestAllocationsInner(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      weightBps: weightBps == const $CopyWithPlaceholder()
          ? _value.weightBps
          // ignore: cast_nullable_to_non_nullable
          : weightBps as int,
    );
  }
}

extension $CreateRecurringPlanRequestAllocationsInnerCopyWith
    on CreateRecurringPlanRequestAllocationsInner {
  /// Returns a callable class that can be used as follows: `instanceOfCreateRecurringPlanRequestAllocationsInner.copyWith(...)` or like so:`instanceOfCreateRecurringPlanRequestAllocationsInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateRecurringPlanRequestAllocationsInnerCWProxy get copyWith =>
      _$CreateRecurringPlanRequestAllocationsInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateRecurringPlanRequestAllocationsInner
_$CreateRecurringPlanRequestAllocationsInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateRecurringPlanRequestAllocationsInner', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['asset_id', 'weight_bps']);
  final val = CreateRecurringPlanRequestAllocationsInner(
    assetId: $checkedConvert('asset_id', (v) => v as String),
    weightBps: $checkedConvert('weight_bps', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'assetId': 'asset_id', 'weightBps': 'weight_bps'});

Map<String, dynamic> _$CreateRecurringPlanRequestAllocationsInnerToJson(
  CreateRecurringPlanRequestAllocationsInner instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'weight_bps': instance.weightBps,
};
