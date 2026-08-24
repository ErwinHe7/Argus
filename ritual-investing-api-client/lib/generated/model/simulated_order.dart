//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/quantity.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:ritual_investing_api_client/generated/model/simulated_order_fill.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'simulated_order.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SimulatedOrder {
  /// Returns a new [SimulatedOrder] instance.
  SimulatedOrder({
    required this.assetId,

    required this.commandId,

    required this.demo,

    required this.fill,

    required this.id,

    required this.notional,

    required this.portfolioId,

    required this.quantity,

    required this.side,

    required this.status,

    required this.symbol,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  @JsonKey(name: r'command_id', required: true, includeIfNull: false)
  final String commandId;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'fill', required: true, includeIfNull: true)
  final SimulatedOrderFill? fill;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'notional', required: true, includeIfNull: true)
  final Money? notional;

  @JsonKey(name: r'portfolio_id', required: true, includeIfNull: false)
  final String portfolioId;

  @JsonKey(name: r'quantity', required: true, includeIfNull: true)
  final Quantity? quantity;

  @JsonKey(
    name: r'side',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SimulatedOrderSideEnum.unknownDefaultOpenApi,
  )
  final SimulatedOrderSideEnum side;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SimulatedOrderStatusEnum.unknownDefaultOpenApi,
  )
  final SimulatedOrderStatusEnum status;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimulatedOrder &&
          other.assetId == assetId &&
          other.commandId == commandId &&
          other.demo == demo &&
          other.fill == fill &&
          other.id == id &&
          other.notional == notional &&
          other.portfolioId == portfolioId &&
          other.quantity == quantity &&
          other.side == side &&
          other.status == status &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      assetId.hashCode +
      commandId.hashCode +
      demo.hashCode +
      (fill == null ? 0 : fill.hashCode) +
      id.hashCode +
      (notional == null ? 0 : notional.hashCode) +
      portfolioId.hashCode +
      (quantity == null ? 0 : quantity.hashCode) +
      side.hashCode +
      status.hashCode +
      symbol.hashCode;

  factory SimulatedOrder.fromJson(Map<String, dynamic> json) =>
      _$SimulatedOrderFromJson(json);

  Map<String, dynamic> toJson() => _$SimulatedOrderToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SimulatedOrderSideEnum {
  @JsonValue(r'buy')
  buy(r'buy'),
  @JsonValue(r'sell')
  sell(r'sell'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SimulatedOrderSideEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum SimulatedOrderStatusEnum {
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SimulatedOrderStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
