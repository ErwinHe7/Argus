//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_order_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageOrderDetail {
  /// Returns a new [BrokerageOrderDetail] instance.
  BrokerageOrderDetail({
    required this.averageFillPrice,

    required this.currency,

    required this.fetchedAt,

    required this.filledQuantity,

    required this.generation,

    required this.id,

    required this.instrumentId,

    required this.limitPrice,

    required this.orderType,

    required this.providerObservedAt,

    required this.providerOrderType,

    required this.providerSide,

    required this.providerState,

    required this.providerTimeInForce,

    required this.quantity,

    required this.side,

    required this.source_,

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

  @JsonKey(name: r'fetched_at', required: true, includeIfNull: false)
  final DateTime fetchedAt;

  @JsonKey(name: r'filled_quantity', required: true, includeIfNull: false)
  final String filledQuantity;

  // minimum: 0
  @JsonKey(name: r'generation', required: true, includeIfNull: false)
  final int generation;

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
    unknownEnumValue: BrokerageOrderDetailOrderTypeEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderDetailOrderTypeEnum orderType;

  @JsonKey(name: r'provider_observed_at', required: true, includeIfNull: false)
  final DateTime providerObservedAt;

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
    unknownEnumValue: BrokerageOrderDetailSideEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderDetailSideEnum side;

  @JsonKey(
    name: r'source',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderDetailSource_Enum.unknownDefaultOpenApi,
  )
  final BrokerageOrderDetailSource_Enum source_;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderDetailStateEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderDetailStateEnum state;

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
    unknownEnumValue: BrokerageOrderDetailTimeInForceEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderDetailTimeInForceEnum timeInForce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageOrderDetail &&
          other.averageFillPrice == averageFillPrice &&
          other.currency == currency &&
          other.fetchedAt == fetchedAt &&
          other.filledQuantity == filledQuantity &&
          other.generation == generation &&
          other.id == id &&
          other.instrumentId == instrumentId &&
          other.limitPrice == limitPrice &&
          other.orderType == orderType &&
          other.providerObservedAt == providerObservedAt &&
          other.providerOrderType == providerOrderType &&
          other.providerSide == providerSide &&
          other.providerState == providerState &&
          other.providerTimeInForce == providerTimeInForce &&
          other.quantity == quantity &&
          other.side == side &&
          other.source_ == source_ &&
          other.state == state &&
          other.stopPrice == stopPrice &&
          other.symbol == symbol &&
          other.terminal == terminal &&
          other.timeInForce == timeInForce;

  @override
  int get hashCode =>
      (averageFillPrice == null ? 0 : averageFillPrice.hashCode) +
      currency.hashCode +
      fetchedAt.hashCode +
      filledQuantity.hashCode +
      generation.hashCode +
      id.hashCode +
      instrumentId.hashCode +
      (limitPrice == null ? 0 : limitPrice.hashCode) +
      orderType.hashCode +
      providerObservedAt.hashCode +
      providerOrderType.hashCode +
      providerSide.hashCode +
      providerState.hashCode +
      providerTimeInForce.hashCode +
      quantity.hashCode +
      side.hashCode +
      source_.hashCode +
      state.hashCode +
      (stopPrice == null ? 0 : stopPrice.hashCode) +
      symbol.hashCode +
      terminal.hashCode +
      timeInForce.hashCode;

  factory BrokerageOrderDetail.fromJson(Map<String, dynamic> json) =>
      _$BrokerageOrderDetailFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageOrderDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageOrderDetailOrderTypeEnum {
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

  const BrokerageOrderDetailOrderTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageOrderDetailSideEnum {
  @JsonValue(r'buy')
  buy(r'buy'),
  @JsonValue(r'sell')
  sell(r'sell'),
  @JsonValue(r'unsupported')
  unsupported(r'unsupported'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderDetailSideEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageOrderDetailSource_Enum {
  @JsonValue(r'list')
  list(r'list'),
  @JsonValue(r'detail')
  detail(r'detail'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderDetailSource_Enum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageOrderDetailStateEnum {
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

  const BrokerageOrderDetailStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageOrderDetailTimeInForceEnum {
  @JsonValue(r'day')
  day(r'day'),
  @JsonValue(r'gtc')
  gtc(r'gtc'),
  @JsonValue(r'unsupported')
  unsupported(r'unsupported'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderDetailTimeInForceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
