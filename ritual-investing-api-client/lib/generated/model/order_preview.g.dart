// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_preview.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderPreviewCWProxy {
  OrderPreview assetId(String assetId);

  OrderPreview demo(SimulationDemoDisclosure demo);

  OrderPreview expiresAt(DateTime expiresAt);

  OrderPreview frozenPrice(Money frozenPrice);

  OrderPreview id(String id);

  OrderPreview notional(Money notional);

  OrderPreview observedAt(DateTime observedAt);

  OrderPreview portfolioId(String portfolioId);

  OrderPreview portfolioVersion(int portfolioVersion);

  OrderPreview quantity(Quantity quantity);

  OrderPreview quoteSnapshotId(String quoteSnapshotId);

  OrderPreview side(OrderPreviewSideEnum side);

  OrderPreview status(OrderPreviewStatusEnum status);

  OrderPreview symbol(String symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderPreview(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderPreview(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderPreview call({
    String assetId,
    SimulationDemoDisclosure demo,
    DateTime expiresAt,
    Money frozenPrice,
    String id,
    Money notional,
    DateTime observedAt,
    String portfolioId,
    int portfolioVersion,
    Quantity quantity,
    String quoteSnapshotId,
    OrderPreviewSideEnum side,
    OrderPreviewStatusEnum status,
    String symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderPreview.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderPreview.copyWith.fieldName(...)`
class _$OrderPreviewCWProxyImpl implements _$OrderPreviewCWProxy {
  const _$OrderPreviewCWProxyImpl(this._value);

  final OrderPreview _value;

  @override
  OrderPreview assetId(String assetId) => this(assetId: assetId);

  @override
  OrderPreview demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  OrderPreview expiresAt(DateTime expiresAt) => this(expiresAt: expiresAt);

  @override
  OrderPreview frozenPrice(Money frozenPrice) => this(frozenPrice: frozenPrice);

  @override
  OrderPreview id(String id) => this(id: id);

  @override
  OrderPreview notional(Money notional) => this(notional: notional);

  @override
  OrderPreview observedAt(DateTime observedAt) => this(observedAt: observedAt);

  @override
  OrderPreview portfolioId(String portfolioId) =>
      this(portfolioId: portfolioId);

  @override
  OrderPreview portfolioVersion(int portfolioVersion) =>
      this(portfolioVersion: portfolioVersion);

  @override
  OrderPreview quantity(Quantity quantity) => this(quantity: quantity);

  @override
  OrderPreview quoteSnapshotId(String quoteSnapshotId) =>
      this(quoteSnapshotId: quoteSnapshotId);

  @override
  OrderPreview side(OrderPreviewSideEnum side) => this(side: side);

  @override
  OrderPreview status(OrderPreviewStatusEnum status) => this(status: status);

  @override
  OrderPreview symbol(String symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderPreview(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderPreview(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderPreview call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? frozenPrice = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? notional = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? portfolioId = const $CopyWithPlaceholder(),
    Object? portfolioVersion = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? quoteSnapshotId = const $CopyWithPlaceholder(),
    Object? side = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return OrderPreview(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime,
      frozenPrice: frozenPrice == const $CopyWithPlaceholder()
          ? _value.frozenPrice
          // ignore: cast_nullable_to_non_nullable
          : frozenPrice as Money,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      notional: notional == const $CopyWithPlaceholder()
          ? _value.notional
          // ignore: cast_nullable_to_non_nullable
          : notional as Money,
      observedAt: observedAt == const $CopyWithPlaceholder()
          ? _value.observedAt
          // ignore: cast_nullable_to_non_nullable
          : observedAt as DateTime,
      portfolioId: portfolioId == const $CopyWithPlaceholder()
          ? _value.portfolioId
          // ignore: cast_nullable_to_non_nullable
          : portfolioId as String,
      portfolioVersion: portfolioVersion == const $CopyWithPlaceholder()
          ? _value.portfolioVersion
          // ignore: cast_nullable_to_non_nullable
          : portfolioVersion as int,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as Quantity,
      quoteSnapshotId: quoteSnapshotId == const $CopyWithPlaceholder()
          ? _value.quoteSnapshotId
          // ignore: cast_nullable_to_non_nullable
          : quoteSnapshotId as String,
      side: side == const $CopyWithPlaceholder()
          ? _value.side
          // ignore: cast_nullable_to_non_nullable
          : side as OrderPreviewSideEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as OrderPreviewStatusEnum,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
    );
  }
}

extension $OrderPreviewCopyWith on OrderPreview {
  /// Returns a callable class that can be used as follows: `instanceOfOrderPreview.copyWith(...)` or like so:`instanceOfOrderPreview.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderPreviewCWProxy get copyWith => _$OrderPreviewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderPreview _$OrderPreviewFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OrderPreview',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'asset_id',
            'demo',
            'expires_at',
            'frozen_price',
            'id',
            'notional',
            'observed_at',
            'portfolio_id',
            'portfolio_version',
            'quantity',
            'quote_snapshot_id',
            'side',
            'status',
            'symbol',
          ],
        );
        final val = OrderPreview(
          assetId: $checkedConvert('asset_id', (v) => v as String),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          expiresAt: $checkedConvert(
            'expires_at',
            (v) => DateTime.parse(v as String),
          ),
          frozenPrice: $checkedConvert(
            'frozen_price',
            (v) => Money.fromJson(v as Map<String, dynamic>),
          ),
          id: $checkedConvert('id', (v) => v as String),
          notional: $checkedConvert(
            'notional',
            (v) => Money.fromJson(v as Map<String, dynamic>),
          ),
          observedAt: $checkedConvert(
            'observed_at',
            (v) => DateTime.parse(v as String),
          ),
          portfolioId: $checkedConvert('portfolio_id', (v) => v as String),
          portfolioVersion: $checkedConvert(
            'portfolio_version',
            (v) => (v as num).toInt(),
          ),
          quantity: $checkedConvert(
            'quantity',
            (v) => Quantity.fromJson(v as Map<String, dynamic>),
          ),
          quoteSnapshotId: $checkedConvert(
            'quote_snapshot_id',
            (v) => v as String,
          ),
          side: $checkedConvert(
            'side',
            (v) => $enumDecode(
              _$OrderPreviewSideEnumEnumMap,
              v,
              unknownValue: OrderPreviewSideEnum.unknownDefaultOpenApi,
            ),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$OrderPreviewStatusEnumEnumMap,
              v,
              unknownValue: OrderPreviewStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          symbol: $checkedConvert('symbol', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'assetId': 'asset_id',
        'expiresAt': 'expires_at',
        'frozenPrice': 'frozen_price',
        'observedAt': 'observed_at',
        'portfolioId': 'portfolio_id',
        'portfolioVersion': 'portfolio_version',
        'quoteSnapshotId': 'quote_snapshot_id',
      },
    );

Map<String, dynamic> _$OrderPreviewToJson(OrderPreview instance) =>
    <String, dynamic>{
      'asset_id': instance.assetId,
      'demo': instance.demo.toJson(),
      'expires_at': instance.expiresAt.toIso8601String(),
      'frozen_price': instance.frozenPrice.toJson(),
      'id': instance.id,
      'notional': instance.notional.toJson(),
      'observed_at': instance.observedAt.toIso8601String(),
      'portfolio_id': instance.portfolioId,
      'portfolio_version': instance.portfolioVersion,
      'quantity': instance.quantity.toJson(),
      'quote_snapshot_id': instance.quoteSnapshotId,
      'side': _$OrderPreviewSideEnumEnumMap[instance.side]!,
      'status': _$OrderPreviewStatusEnumEnumMap[instance.status]!,
      'symbol': instance.symbol,
    };

const _$OrderPreviewSideEnumEnumMap = {
  OrderPreviewSideEnum.buy: 'buy',
  OrderPreviewSideEnum.sell: 'sell',
  OrderPreviewSideEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$OrderPreviewStatusEnumEnumMap = {
  OrderPreviewStatusEnum.active: 'active',
  OrderPreviewStatusEnum.executed: 'executed',
  OrderPreviewStatusEnum.expired: 'expired',
  OrderPreviewStatusEnum.invalidated: 'invalidated',
  OrderPreviewStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
