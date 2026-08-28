//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'place_brokerage_order_intent.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PlaceBrokerageOrderIntent {
  /// Returns a new [PlaceBrokerageOrderIntent] instance.
  PlaceBrokerageOrderIntent({
    required this.instrumentId,

    required this.limitPrice,

    required this.orderType,

    required this.quantity,

    required this.side,

    required this.timeInForce,
  });

  @JsonKey(name: r'instrument_id', required: true, includeIfNull: false)
  final String instrumentId;

  @JsonKey(name: r'limit_price', required: true, includeIfNull: true)
  final String? limitPrice;

  @JsonKey(
    name: r'order_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        PlaceBrokerageOrderIntentOrderTypeEnum.unknownDefaultOpenApi,
  )
  final PlaceBrokerageOrderIntentOrderTypeEnum orderType;

  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final String quantity;

  @JsonKey(
    name: r'side',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PlaceBrokerageOrderIntentSideEnum.unknownDefaultOpenApi,
  )
  final PlaceBrokerageOrderIntentSideEnum side;

  @JsonKey(
    name: r'time_in_force',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        PlaceBrokerageOrderIntentTimeInForceEnum.unknownDefaultOpenApi,
  )
  final PlaceBrokerageOrderIntentTimeInForceEnum timeInForce;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceBrokerageOrderIntent &&
          other.instrumentId == instrumentId &&
          other.limitPrice == limitPrice &&
          other.orderType == orderType &&
          other.quantity == quantity &&
          other.side == side &&
          other.timeInForce == timeInForce;

  @override
  int get hashCode =>
      instrumentId.hashCode +
      (limitPrice == null ? 0 : limitPrice.hashCode) +
      orderType.hashCode +
      quantity.hashCode +
      side.hashCode +
      timeInForce.hashCode;

  factory PlaceBrokerageOrderIntent.fromJson(Map<String, dynamic> json) =>
      _$PlaceBrokerageOrderIntentFromJson(json);

  Map<String, dynamic> toJson() => _$PlaceBrokerageOrderIntentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PlaceBrokerageOrderIntentOrderTypeEnum {
  @JsonValue(r'market')
  market(r'market'),
  @JsonValue(r'limit')
  limit(r'limit'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PlaceBrokerageOrderIntentOrderTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PlaceBrokerageOrderIntentSideEnum {
  @JsonValue(r'buy')
  buy(r'buy'),
  @JsonValue(r'sell')
  sell(r'sell'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PlaceBrokerageOrderIntentSideEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PlaceBrokerageOrderIntentTimeInForceEnum {
  @JsonValue(r'day')
  day(r'day'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PlaceBrokerageOrderIntentTimeInForceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
