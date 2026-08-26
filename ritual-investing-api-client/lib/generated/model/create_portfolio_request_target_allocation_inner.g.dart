// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_portfolio_request_target_allocation_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreatePortfolioRequestTargetAllocationInnerCWProxy {
  CreatePortfolioRequestTargetAllocationInner assetId(String assetId);

  CreatePortfolioRequestTargetAllocationInner targetBps(int targetBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatePortfolioRequestTargetAllocationInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatePortfolioRequestTargetAllocationInner(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatePortfolioRequestTargetAllocationInner call({
    String assetId,
    int targetBps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreatePortfolioRequestTargetAllocationInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreatePortfolioRequestTargetAllocationInner.copyWith.fieldName(...)`
class _$CreatePortfolioRequestTargetAllocationInnerCWProxyImpl
    implements _$CreatePortfolioRequestTargetAllocationInnerCWProxy {
  const _$CreatePortfolioRequestTargetAllocationInnerCWProxyImpl(this._value);

  final CreatePortfolioRequestTargetAllocationInner _value;

  @override
  CreatePortfolioRequestTargetAllocationInner assetId(String assetId) =>
      this(assetId: assetId);

  @override
  CreatePortfolioRequestTargetAllocationInner targetBps(int targetBps) =>
      this(targetBps: targetBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatePortfolioRequestTargetAllocationInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatePortfolioRequestTargetAllocationInner(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatePortfolioRequestTargetAllocationInner call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? targetBps = const $CopyWithPlaceholder(),
  }) {
    return CreatePortfolioRequestTargetAllocationInner(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      targetBps: targetBps == const $CopyWithPlaceholder()
          ? _value.targetBps
          // ignore: cast_nullable_to_non_nullable
          : targetBps as int,
    );
  }
}

extension $CreatePortfolioRequestTargetAllocationInnerCopyWith
    on CreatePortfolioRequestTargetAllocationInner {
  /// Returns a callable class that can be used as follows: `instanceOfCreatePortfolioRequestTargetAllocationInner.copyWith(...)` or like so:`instanceOfCreatePortfolioRequestTargetAllocationInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreatePortfolioRequestTargetAllocationInnerCWProxy get copyWith =>
      _$CreatePortfolioRequestTargetAllocationInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePortfolioRequestTargetAllocationInner
_$CreatePortfolioRequestTargetAllocationInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreatePortfolioRequestTargetAllocationInner', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['asset_id', 'target_bps']);
  final val = CreatePortfolioRequestTargetAllocationInner(
    assetId: $checkedConvert('asset_id', (v) => v as String),
    targetBps: $checkedConvert('target_bps', (v) => (v as num).toInt()),
  );
  return val;
}, fieldKeyMap: const {'assetId': 'asset_id', 'targetBps': 'target_bps'});

Map<String, dynamic> _$CreatePortfolioRequestTargetAllocationInnerToJson(
  CreatePortfolioRequestTargetAllocationInner instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'target_bps': instance.targetBps,
};
