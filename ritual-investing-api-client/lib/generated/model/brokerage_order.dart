//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_order.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageOrder {
  /// Returns a new [BrokerageOrder] instance.
  BrokerageOrder({
    required this.averageFillPrice,

    required this.currency,

    required this.filledQuantity,

    required this.id,

    required this.instrumentId,

    required this.limitPrice,

    required this.orderType,

    required this.providerOrderType,

    required this.providerSide,

    required this.providerState,

    required this.providerTimeInForce,

    required this.quantity,

    required this.side,

    required this.state,

    required this.stopPrice,

    required this.symbol,

    required this.terminal,

    required this.timeInForce,
  });

  @JsonKey(name: r'average_fill_price', required: true, includeIfNull: true)
  final String? averageFillPrice;

  @JsonKey(name: r'currency', required: true, includeIfNull: false)
  final String currency;

  @JsonKey(name: r'filled_quantity', required: true, includeIfNull: false)
  final String filledQuantity;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'instrument_id', required: true, includeIfNull: false)
  final String instrumentId;

  @JsonKey(name: r'limit_price', required: true, includeIfNull: true)
  final String? limitPrice;

  @JsonKey(
    name: r'order_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderOrderTypeEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderOrderTypeEnum orderType;

  @JsonKey(name: r'provider_order_type', required: true, includeIfNull: false)
  final String providerOrderType;

  @JsonKey(name: r'provider_side', required: true, includeIfNull: false)
  final String providerSide;

  @JsonKey(name: r'provider_state', required: true, includeIfNull: false)
  final String providerState;

  @JsonKey(
    name: r'provider_time_in_force',
    required: true,
    includeIfNull: false,
  )
  final String providerTimeInForce;

  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final String quantity;

  @JsonKey(
    name: r'side',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderSideEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderSideEnum side;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderStateEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderStateEnum state;

  @JsonKey(name: r'stop_price', required: true, includeIfNull: true)
  final String? stopPrice;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @JsonKey(name: r'terminal', required: true, includeIfNull: false)
  final bool terminal;

  @JsonKey(
    name: r'time_in_force',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderTimeInForceEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderTimeInForceEnum timeInForce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageOrder &&
          other.averageFillPrice == averageFillPrice &&
          other.currency == currency &&
          other.filledQuantity == filledQuantity &&
          other.id == id &&
          other.instrumentId == instrumentId &&
          other.limitPrice == limitPrice &&
          other.orderType == orderType &&
          other.providerOrderType == providerOrderType &&
          other.providerSide == providerSide &&
          other.providerState == providerState &&
          other.providerTimeInForce == providerTimeInForce &&
          other.quantity == quantity &&
          other.side == side &&
          other.state == state &&
          other.stopPrice == stopPrice &&
          other.symbol == symbol &&
          other.terminal == terminal &&
          other.timeInForce == timeInForce;

  @override
  int get hashCode =>
      (averageFillPrice == null ? 0 : averageFillPrice.hashCode) +
      currency.hashCode +
      filledQuantity.hashCode +
      id.hashCode +
      instrumentId.hashCode +
      (limitPrice == null ? 0 : limitPrice.hashCode) +
      orderType.hashCode +
      providerOrderType.hashCode +
      providerSide.hashCode +
      providerState.hashCode +
      providerTimeInForce.hashCode +
      quantity.hashCode +
      side.hashCode +
      state.hashCode +
      (stopPrice == null ? 0 : stopPrice.hashCode) +
      symbol.hashCode +
      terminal.hashCode +
      timeInForce.hashCode;

  factory BrokerageOrder.fromJson(Map<String, dynamic> json) =>
      _$BrokerageOrderFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageOrderToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageOrderOrderTypeEnum {
  @JsonValue(r'market')
  market(r'market'),
  @JsonValue(r'limit')
  limit(r'limit'),
  @JsonValue(r'stop')
  stop(r'stop'),
  @JsonValue(r'stop_limit')
  stopLimit(r'stop_limit'),
  @JsonValue(r'unsupported')
  unsupported(r'unsupported'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderOrderTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageOrderSideEnum {
  @JsonValue(r'buy')
  buy(r'buy'),
  @JsonValue(r'sell')
  sell(r'sell'),
  @JsonValue(r'unsupported')
  unsupported(r'unsupported'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderSideEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageOrderStateEnum {
  @JsonValue(r'pending')
  pending(r'pending'),
  @JsonValue(r'partially_filled')
  partiallyFilled(r'partially_filled'),
  @JsonValue(r'filled')
  filled(r'filled'),
  @JsonValue(r'cancelled')
  cancelled(r'cancelled'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'expired')
  expired(r'expired'),
  @JsonValue(r'unknown')
  unknown(r'unknown'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageOrderTimeInForceEnum {
  @JsonValue(r'day')
  day(r'day'),
  @JsonValue(r'gtc')
  gtc(r'gtc'),
  @JsonValue(r'unsupported')
  unsupported(r'unsupported'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderTimeInForceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
