// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simulated_order.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SimulatedOrderCWProxy {
  SimulatedOrder assetId(String assetId);

  SimulatedOrder commandId(String commandId);

  SimulatedOrder demo(SimulationDemoDisclosure demo);

  SimulatedOrder fill(SimulatedOrderFill? fill);

  SimulatedOrder id(String id);

  SimulatedOrder notional(Money? notional);

  SimulatedOrder portfolioId(String portfolioId);

  SimulatedOrder quantity(Quantity? quantity);

  SimulatedOrder side(SimulatedOrderSideEnum side);

  SimulatedOrder status(SimulatedOrderStatusEnum status);

  SimulatedOrder symbol(String symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulatedOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulatedOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulatedOrder call({
    String assetId,
    String commandId,
    SimulationDemoDisclosure demo,
    SimulatedOrderFill? fill,
    String id,
    Money? notional,
    String portfolioId,
    Quantity? quantity,
    SimulatedOrderSideEnum side,
    SimulatedOrderStatusEnum status,
    String symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSimulatedOrder.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSimulatedOrder.copyWith.fieldName(...)`
class _$SimulatedOrderCWProxyImpl implements _$SimulatedOrderCWProxy {
  const _$SimulatedOrderCWProxyImpl(this._value);

  final SimulatedOrder _value;

  @override
  SimulatedOrder assetId(String assetId) => this(assetId: assetId);

  @override
  SimulatedOrder commandId(String commandId) => this(commandId: commandId);

  @override
  SimulatedOrder demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  SimulatedOrder fill(SimulatedOrderFill? fill) => this(fill: fill);

  @override
  SimulatedOrder id(String id) => this(id: id);

  @override
  SimulatedOrder notional(Money? notional) => this(notional: notional);

  @override
  SimulatedOrder portfolioId(String portfolioId) =>
      this(portfolioId: portfolioId);

  @override
  SimulatedOrder quantity(Quantity? quantity) => this(quantity: quantity);

  @override
  SimulatedOrder side(SimulatedOrderSideEnum side) => this(side: side);

  @override
  SimulatedOrder status(SimulatedOrderStatusEnum status) =>
      this(status: status);

  @override
  SimulatedOrder symbol(String symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulatedOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulatedOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulatedOrder call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? commandId = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? fill = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? notional = const $CopyWithPlaceholder(),
    Object? portfolioId = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? side = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return SimulatedOrder(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      commandId: commandId == const $CopyWithPlaceholder()
          ? _value.commandId
          // ignore: cast_nullable_to_non_nullable
          : commandId as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      fill: fill == const $CopyWithPlaceholder()
          ? _value.fill
          // ignore: cast_nullable_to_non_nullable
          : fill as SimulatedOrderFill?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      notional: notional == const $CopyWithPlaceholder()
          ? _value.notional
          // ignore: cast_nullable_to_non_nullable
          : notional as Money?,
      portfolioId: portfolioId == const $CopyWithPlaceholder()
          ? _value.portfolioId
          // ignore: cast_nullable_to_non_nullable
          : portfolioId as String,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as Quantity?,
      side: side == const $CopyWithPlaceholder()
          ? _value.side
          // ignore: cast_nullable_to_non_nullable
          : side as SimulatedOrderSideEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as SimulatedOrderStatusEnum,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
    );
  }
}

extension $SimulatedOrderCopyWith on SimulatedOrder {
  /// Returns a callable class that can be used as follows: `instanceOfSimulatedOrder.copyWith(...)` or like so:`instanceOfSimulatedOrder.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SimulatedOrderCWProxy get copyWith => _$SimulatedOrderCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimulatedOrder _$SimulatedOrderFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SimulatedOrder',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'asset_id',
            'command_id',
            'demo',
            'fill',
            'id',
            'notional',
            'portfolio_id',
            'quantity',
            'side',
            'status',
            'symbol',
          ],
        );
        final val = SimulatedOrder(
          assetId: $checkedConvert('asset_id', (v) => v as String),
          commandId: $checkedConvert('command_id', (v) => v as String),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          fill: $checkedConvert(
            'fill',
            (v) => v == null
                ? null
                : SimulatedOrderFill.fromJson(v as Map<String, dynamic>),
          ),
          id: $checkedConvert('id', (v) => v as String),
          notional: $checkedConvert(
            'notional',
            (v) => v == null ? null : Money.fromJson(v as Map<String, dynamic>),
          ),
          portfolioId: $checkedConvert('portfolio_id', (v) => v as String),
          quantity: $checkedConvert(
            'quantity',
            (v) =>
                v == null ? null : Quantity.fromJson(v as Map<String, dynamic>),
          ),
          side: $checkedConvert(
            'side',
            (v) => $enumDecode(
              _$SimulatedOrderSideEnumEnumMap,
              v,
              unknownValue: SimulatedOrderSideEnum.unknownDefaultOpenApi,
            ),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$SimulatedOrderStatusEnumEnumMap,
              v,
              unknownValue: SimulatedOrderStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          symbol: $checkedConvert('symbol', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'assetId': 'asset_id',
        'commandId': 'command_id',
        'portfolioId': 'portfolio_id',
      },
    );

Map<String, dynamic> _$SimulatedOrderToJson(SimulatedOrder instance) =>
    <String, dynamic>{
      'asset_id': instance.assetId,
      'command_id': instance.commandId,
      'demo': instance.demo.toJson(),
      'fill': instance.fill?.toJson(),
      'id': instance.id,
      'notional': instance.notional?.toJson(),
      'portfolio_id': instance.portfolioId,
      'quantity': instance.quantity?.toJson(),
      'side': _$SimulatedOrderSideEnumEnumMap[instance.side]!,
      'status': _$SimulatedOrderStatusEnumEnumMap[instance.status]!,
      'symbol': instance.symbol,
    };

const _$SimulatedOrderSideEnumEnumMap = {
  SimulatedOrderSideEnum.buy: 'buy',
  SimulatedOrderSideEnum.sell: 'sell',
  SimulatedOrderSideEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$SimulatedOrderStatusEnumEnumMap = {
  SimulatedOrderStatusEnum.accepted: 'accepted',
  SimulatedOrderStatusEnum.rejected: 'rejected',
  SimulatedOrderStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
