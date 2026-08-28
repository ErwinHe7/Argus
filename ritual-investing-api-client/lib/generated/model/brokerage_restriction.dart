//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_restriction.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageRestriction {
  /// Returns a new [BrokerageRestriction] instance.
  BrokerageRestriction({
    required this.active,

    required this.detail,

    required this.providerCode,

    required this.restriction,
  });

  @JsonKey(name: r'active', required: true, includeIfNull: false)
  final bool active;

  @JsonKey(name: r'detail', required: true, includeIfNull: true)
  final String? detail;

  @JsonKey(name: r'provider_code', required: true, includeIfNull: false)
  final String providerCode;

  @JsonKey(
    name: r'restriction',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageRestrictionRestrictionEnum.unknownDefaultOpenApi,
  )
  final BrokerageRestrictionRestrictionEnum restriction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageRestriction &&
          other.active == active &&
          other.detail == detail &&
          other.providerCode == providerCode &&
          other.restriction == restriction;

  @override
  int get hashCode =>
      active.hashCode +
      (detail == null ? 0 : detail.hashCode) +
      providerCode.hashCode +
      restriction.hashCode;

  factory BrokerageRestriction.fromJson(Map<String, dynamic> json) =>
      _$BrokerageRestrictionFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageRestrictionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageRestrictionRestrictionEnum {
  @JsonValue(r'closing_only')
  closingOnly(r'closing_only'),
  @JsonValue(r'trading_disabled')
  tradingDisabled(r'trading_disabled'),
  @JsonValue(r'liquidation_only')
  liquidationOnly(r'liquidation_only'),
  @JsonValue(r'unsupported')
  unsupported(r'unsupported'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageRestrictionRestrictionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
