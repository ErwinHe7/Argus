// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rebalance_preview_trades_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RebalancePreviewTradesInnerCWProxy {
  RebalancePreviewTradesInner assetId(String assetId);

  RebalancePreviewTradesInner notional(Money notional);

  RebalancePreviewTradesInner quantity(Quantity quantity);

  RebalancePreviewTradesInner side(RebalancePreviewTradesInnerSideEnum side);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RebalancePreviewTradesInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RebalancePreviewTradesInner(...).copyWith(id: 12, name: "My name")
  /// ````
  RebalancePreviewTradesInner call({
    String assetId,
    Money notional,
    Quantity quantity,
    RebalancePreviewTradesInnerSideEnum side,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRebalancePreviewTradesInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRebalancePreviewTradesInner.copyWith.fieldName(...)`
class _$RebalancePreviewTradesInnerCWProxyImpl
    implements _$RebalancePreviewTradesInnerCWProxy {
  const _$RebalancePreviewTradesInnerCWProxyImpl(this._value);

  final RebalancePreviewTradesInner _value;

  @override
  RebalancePreviewTradesInner assetId(String assetId) => this(assetId: assetId);

  @override
  RebalancePreviewTradesInner notional(Money notional) =>
      this(notional: notional);

  @override
  RebalancePreviewTradesInner quantity(Quantity quantity) =>
      this(quantity: quantity);

  @override
  RebalancePreviewTradesInner side(RebalancePreviewTradesInnerSideEnum side) =>
      this(side: side);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RebalancePreviewTradesInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RebalancePreviewTradesInner(...).copyWith(id: 12, name: "My name")
  /// ````
  RebalancePreviewTradesInner call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? notional = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? side = const $CopyWithPlaceholder(),
  }) {
    return RebalancePreviewTradesInner(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      notional: notional == const $CopyWithPlaceholder()
          ? _value.notional
          // ignore: cast_nullable_to_non_nullable
          : notional as Money,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as Quantity,
      side: side == const $CopyWithPlaceholder()
          ? _value.side
          // ignore: cast_nullable_to_non_nullable
          : side as RebalancePreviewTradesInnerSideEnum,
    );
  }
}

extension $RebalancePreviewTradesInnerCopyWith on RebalancePreviewTradesInner {
  /// Returns a callable class that can be used as follows: `instanceOfRebalancePreviewTradesInner.copyWith(...)` or like so:`instanceOfRebalancePreviewTradesInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RebalancePreviewTradesInnerCWProxy get copyWith =>
      _$RebalancePreviewTradesInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RebalancePreviewTradesInner _$RebalancePreviewTradesInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RebalancePreviewTradesInner', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['asset_id', 'notional', 'quantity', 'side'],
  );
  final val = RebalancePreviewTradesInner(
    assetId: $checkedConvert('asset_id', (v) => v as String),
    notional: $checkedConvert(
      'notional',
      (v) => Money.fromJson(v as Map<String, dynamic>),
    ),
    quantity: $checkedConvert(
      'quantity',
      (v) => Quantity.fromJson(v as Map<String, dynamic>),
    ),
    side: $checkedConvert(
      'side',
      (v) => $enumDecode(
        _$RebalancePreviewTradesInnerSideEnumEnumMap,
        v,
        unknownValue: RebalancePreviewTradesInnerSideEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'assetId': 'asset_id'});

Map<String, dynamic> _$RebalancePreviewTradesInnerToJson(
  RebalancePreviewTradesInner instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'notional': instance.notional.toJson(),
  'quantity': instance.quantity.toJson(),
  'side': _$RebalancePreviewTradesInnerSideEnumEnumMap[instance.side]!,
};

const _$RebalancePreviewTradesInnerSideEnumEnumMap = {
  RebalancePreviewTradesInnerSideEnum.buy: 'buy',
  RebalancePreviewTradesInnerSideEnum.sell: 'sell',
  RebalancePreviewTradesInnerSideEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
