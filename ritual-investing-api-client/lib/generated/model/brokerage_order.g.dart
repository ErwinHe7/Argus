// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_order.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageOrderCWProxy {
  BrokerageOrder averageFillPrice(String? averageFillPrice);

  BrokerageOrder currency(String currency);

  BrokerageOrder filledQuantity(String filledQuantity);

  BrokerageOrder id(String id);

  BrokerageOrder instrumentId(String instrumentId);

  BrokerageOrder limitPrice(String? limitPrice);

  BrokerageOrder orderType(BrokerageOrderOrderTypeEnum orderType);

  BrokerageOrder providerOrderType(String providerOrderType);

  BrokerageOrder providerSide(String providerSide);

  BrokerageOrder providerState(String providerState);

  BrokerageOrder providerTimeInForce(String providerTimeInForce);

  BrokerageOrder quantity(String quantity);

  BrokerageOrder side(BrokerageOrderSideEnum side);

  BrokerageOrder state(BrokerageOrderStateEnum state);

  BrokerageOrder stopPrice(String? stopPrice);

  BrokerageOrder symbol(String symbol);

  BrokerageOrder terminal(bool terminal);

  BrokerageOrder timeInForce(BrokerageOrderTimeInForceEnum timeInForce);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrder call({
    String? averageFillPrice,
    String currency,
    String filledQuantity,
    String id,
    String instrumentId,
    String? limitPrice,
    BrokerageOrderOrderTypeEnum orderType,
    String providerOrderType,
    String providerSide,
    String providerState,
    String providerTimeInForce,
    String quantity,
    BrokerageOrderSideEnum side,
    BrokerageOrderStateEnum state,
    String? stopPrice,
    String symbol,
    bool terminal,
    BrokerageOrderTimeInForceEnum timeInForce,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageOrder.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageOrder.copyWith.fieldName(...)`
class _$BrokerageOrderCWProxyImpl implements _$BrokerageOrderCWProxy {
  const _$BrokerageOrderCWProxyImpl(this._value);

  final BrokerageOrder _value;

  @override
  BrokerageOrder averageFillPrice(String? averageFillPrice) =>
      this(averageFillPrice: averageFillPrice);

  @override
  BrokerageOrder currency(String currency) => this(currency: currency);

  @override
  BrokerageOrder filledQuantity(String filledQuantity) =>
      this(filledQuantity: filledQuantity);

  @override
  BrokerageOrder id(String id) => this(id: id);

  @override
  BrokerageOrder instrumentId(String instrumentId) =>
      this(instrumentId: instrumentId);

  @override
  BrokerageOrder limitPrice(String? limitPrice) => this(limitPrice: limitPrice);

  @override
  BrokerageOrder orderType(BrokerageOrderOrderTypeEnum orderType) =>
      this(orderType: orderType);

  @override
  BrokerageOrder providerOrderType(String providerOrderType) =>
      this(providerOrderType: providerOrderType);

  @override
  BrokerageOrder providerSide(String providerSide) =>
      this(providerSide: providerSide);

  @override
  BrokerageOrder providerState(String providerState) =>
      this(providerState: providerState);

  @override
  BrokerageOrder providerTimeInForce(String providerTimeInForce) =>
      this(providerTimeInForce: providerTimeInForce);

  @override
  BrokerageOrder quantity(String quantity) => this(quantity: quantity);

  @override
  BrokerageOrder side(BrokerageOrderSideEnum side) => this(side: side);

  @override
  BrokerageOrder state(BrokerageOrderStateEnum state) => this(state: state);

  @override
  BrokerageOrder stopPrice(String? stopPrice) => this(stopPrice: stopPrice);

  @override
  BrokerageOrder symbol(String symbol) => this(symbol: symbol);

  @override
  BrokerageOrder terminal(bool terminal) => this(terminal: terminal);

  @override
  BrokerageOrder timeInForce(BrokerageOrderTimeInForceEnum timeInForce) =>
      this(timeInForce: timeInForce);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageOrder(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageOrder(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageOrder call({
    Object? averageFillPrice = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? filledQuantity = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? instrumentId = const $CopyWithPlaceholder(),
    Object? limitPrice = const $CopyWithPlaceholder(),
    Object? orderType = const $CopyWithPlaceholder(),
    Object? providerOrderType = const $CopyWithPlaceholder(),
    Object? providerSide = const $CopyWithPlaceholder(),
    Object? providerState = const $CopyWithPlaceholder(),
    Object? providerTimeInForce = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? side = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
    Object? stopPrice = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
    Object? terminal = const $CopyWithPlaceholder(),
    Object? timeInForce = const $CopyWithPlaceholder(),
  }) {
    return BrokerageOrder(
      averageFillPrice: averageFillPrice == const $CopyWithPlaceholder()
          ? _value.averageFillPrice
          // ignore: cast_nullable_to_non_nullable
          : averageFillPrice as String?,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as String,
      filledQuantity: filledQuantity == const $CopyWithPlaceholder()
          ? _value.filledQuantity
          // ignore: cast_nullable_to_non_nullable
          : filledQuantity as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      instrumentId: instrumentId == const $CopyWithPlaceholder()
          ? _value.instrumentId
          // ignore: cast_nullable_to_non_nullable
          : instrumentId as String,
      limitPrice: limitPrice == const $CopyWithPlaceholder()
          ? _value.limitPrice
          // ignore: cast_nullable_to_non_nullable
          : limitPrice as String?,
      orderType: orderType == const $CopyWithPlaceholder()
          ? _value.orderType
          // ignore: cast_nullable_to_non_nullable
          : orderType as BrokerageOrderOrderTypeEnum,
      providerOrderType: providerOrderType == const $CopyWithPlaceholder()
          ? _value.providerOrderType
          // ignore: cast_nullable_to_non_nullable
          : providerOrderType as String,
      providerSide: providerSide == const $CopyWithPlaceholder()
          ? _value.providerSide
          // ignore: cast_nullable_to_non_nullable
          : providerSide as String,
      providerState: providerState == const $CopyWithPlaceholder()
          ? _value.providerState
          // ignore: cast_nullable_to_non_nullable
          : providerState as String,
      providerTimeInForce: providerTimeInForce == const $CopyWithPlaceholder()
          ? _value.providerTimeInForce
          // ignore: cast_nullable_to_non_nullable
          : providerTimeInForce as String,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as String,
      side: side == const $CopyWithPlaceholder()
          ? _value.side
          // ignore: cast_nullable_to_non_nullable
          : side as BrokerageOrderSideEnum,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as BrokerageOrderStateEnum,
      stopPrice: stopPrice == const $CopyWithPlaceholder()
          ? _value.stopPrice
          // ignore: cast_nullable_to_non_nullable
          : stopPrice as String?,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
      terminal: terminal == const $CopyWithPlaceholder()
          ? _value.terminal
          // ignore: cast_nullable_to_non_nullable
          : terminal as bool,
      timeInForce: timeInForce == const $CopyWithPlaceholder()
          ? _value.timeInForce
          // ignore: cast_nullable_to_non_nullable
          : timeInForce as BrokerageOrderTimeInForceEnum,
    );
  }
}

extension $BrokerageOrderCopyWith on BrokerageOrder {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageOrder.copyWith(...)` or like so:`instanceOfBrokerageOrder.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageOrderCWProxy get copyWith => _$BrokerageOrderCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageOrder _$BrokerageOrderFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'BrokerageOrder',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'average_fill_price',
            'currency',
            'filled_quantity',
            'id',
            'instrument_id',
            'limit_price',
            'order_type',
            'provider_order_type',
            'provider_side',
            'provider_state',
            'provider_time_in_force',
            'quantity',
            'side',
            'state',
            'stop_price',
            'symbol',
            'terminal',
            'time_in_force',
          ],
        );
        final val = BrokerageOrder(
          averageFillPrice: $checkedConvert(
            'average_fill_price',
            (v) => v as String?,
          ),
          currency: $checkedConvert('currency', (v) => v as String),
          filledQuantity: $checkedConvert(
            'filled_quantity',
            (v) => v as String,
          ),
          id: $checkedConvert('id', (v) => v as String),
          instrumentId: $checkedConvert('instrument_id', (v) => v as String),
          limitPrice: $checkedConvert('limit_price', (v) => v as String?),
          orderType: $checkedConvert(
            'order_type',
            (v) => $enumDecode(
              _$BrokerageOrderOrderTypeEnumEnumMap,
              v,
              unknownValue: BrokerageOrderOrderTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          providerOrderType: $checkedConvert(
            'provider_order_type',
            (v) => v as String,
          ),
          providerSide: $checkedConvert('provider_side', (v) => v as String),
          providerState: $checkedConvert('provider_state', (v) => v as String),
          providerTimeInForce: $checkedConvert(
            'provider_time_in_force',
            (v) => v as String,
          ),
          quantity: $checkedConvert('quantity', (v) => v as String),
          side: $checkedConvert(
            'side',
            (v) => $enumDecode(
              _$BrokerageOrderSideEnumEnumMap,
              v,
              unknownValue: BrokerageOrderSideEnum.unknownDefaultOpenApi,
            ),
          ),
          state: $checkedConvert(
            'state',
            (v) => $enumDecode(
              _$BrokerageOrderStateEnumEnumMap,
              v,
              unknownValue: BrokerageOrderStateEnum.unknownDefaultOpenApi,
            ),
          ),
          stopPrice: $checkedConvert('stop_price', (v) => v as String?),
          symbol: $checkedConvert('symbol', (v) => v as String),
          terminal: $checkedConvert('terminal', (v) => v as bool),
          timeInForce: $checkedConvert(
            'time_in_force',
            (v) => $enumDecode(
              _$BrokerageOrderTimeInForceEnumEnumMap,
              v,
              unknownValue: BrokerageOrderTimeInForceEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'averageFillPrice': 'average_fill_price',
        'filledQuantity': 'filled_quantity',
        'instrumentId': 'instrument_id',
        'limitPrice': 'limit_price',
        'orderType': 'order_type',
        'providerOrderType': 'provider_order_type',
        'providerSide': 'provider_side',
        'providerState': 'provider_state',
        'providerTimeInForce': 'provider_time_in_force',
        'stopPrice': 'stop_price',
        'timeInForce': 'time_in_force',
      },
    );

Map<String, dynamic> _$BrokerageOrderToJson(BrokerageOrder instance) =>
    <String, dynamic>{
      'average_fill_price': instance.averageFillPrice,
      'currency': instance.currency,
      'filled_quantity': instance.filledQuantity,
      'id': instance.id,
      'instrument_id': instance.instrumentId,
      'limit_price': instance.limitPrice,
      'order_type': _$BrokerageOrderOrderTypeEnumEnumMap[instance.orderType]!,
      'provider_order_type': instance.providerOrderType,
      'provider_side': instance.providerSide,
      'provider_state': instance.providerState,
      'provider_time_in_force': instance.providerTimeInForce,
      'quantity': instance.quantity,
      'side': _$BrokerageOrderSideEnumEnumMap[instance.side]!,
      'state': _$BrokerageOrderStateEnumEnumMap[instance.state]!,
      'stop_price': instance.stopPrice,
      'symbol': instance.symbol,
      'terminal': instance.terminal,
      'time_in_force':
          _$BrokerageOrderTimeInForceEnumEnumMap[instance.timeInForce]!,
    };

const _$BrokerageOrderOrderTypeEnumEnumMap = {
  BrokerageOrderOrderTypeEnum.market: 'market',
  BrokerageOrderOrderTypeEnum.limit: 'limit',
  BrokerageOrderOrderTypeEnum.stop: 'stop',
  BrokerageOrderOrderTypeEnum.stopLimit: 'stop_limit',
  BrokerageOrderOrderTypeEnum.unsupported: 'unsupported',
  BrokerageOrderOrderTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$BrokerageOrderSideEnumEnumMap = {
  BrokerageOrderSideEnum.buy: 'buy',
  BrokerageOrderSideEnum.sell: 'sell',
  BrokerageOrderSideEnum.unsupported: 'unsupported',
  BrokerageOrderSideEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$BrokerageOrderStateEnumEnumMap = {
  BrokerageOrderStateEnum.pending: 'pending',
  BrokerageOrderStateEnum.partiallyFilled: 'partially_filled',
  BrokerageOrderStateEnum.filled: 'filled',
  BrokerageOrderStateEnum.cancelled: 'cancelled',
  BrokerageOrderStateEnum.rejected: 'rejected',
  BrokerageOrderStateEnum.expired: 'expired',
  BrokerageOrderStateEnum.unknown: 'unknown',
  BrokerageOrderStateEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$BrokerageOrderTimeInForceEnumEnumMap = {
  BrokerageOrderTimeInForceEnum.day: 'day',
  BrokerageOrderTimeInForceEnum.gtc: 'gtc',
  BrokerageOrderTimeInForceEnum.unsupported: 'unsupported',
  BrokerageOrderTimeInForceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
