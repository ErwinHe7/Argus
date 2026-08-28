//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_capability.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageCapability {
  /// Returns a new [BrokerageCapability] instance.
  BrokerageCapability({
    required this.available,

    required this.capability,

    required this.providerCode,
  });

  @JsonKey(name: r'available', required: true, includeIfNull: false)
  final bool available;

  @JsonKey(
    name: r'capability',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageCapabilityCapabilityEnum.unknownDefaultOpenApi,
  )
  final BrokerageCapabilityCapabilityEnum capability;

  @JsonKey(name: r'provider_code', required: true, includeIfNull: false)
  final String providerCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageCapability &&
          other.available == available &&
          other.capability == capability &&
          other.providerCode == providerCode;

  @override
  int get hashCode =>
      available.hashCode + capability.hashCode + providerCode.hashCode;

  factory BrokerageCapability.fromJson(Map<String, dynamic> json) =>
      _$BrokerageCapabilityFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageCapabilityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageCapabilityCapabilityEnum {
  @JsonValue(r'balances_read')
  balancesRead(r'balances_read'),
  @JsonValue(r'positions_read')
  positionsRead(r'positions_read'),
  @JsonValue(r'orders_read')
  ordersRead(r'orders_read'),
  @JsonValue(r'manual_orders')
  manualOrders(r'manual_orders'),
  @JsonValue(r'unsupported')
  unsupported(r'unsupported'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageCapabilityCapabilityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
