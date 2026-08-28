//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_capability.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_account_authority.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageAccountAuthority {
  /// Returns a new [BrokerageAccountAuthority] instance.
  BrokerageAccountAuthority({
    required this.baseCurrency,

    required this.capabilities,

    required this.capabilityVersion,

    required this.displayLabel,

    required this.marketTimezone,

    required this.status,
  });

  @JsonKey(name: r'base_currency', required: true, includeIfNull: false)
  final String baseCurrency;

  @JsonKey(name: r'capabilities', required: true, includeIfNull: false)
  final List<BrokerageCapability> capabilities;

  // minimum: 0
  @JsonKey(name: r'capability_version', required: true, includeIfNull: false)
  final int capabilityVersion;

  @JsonKey(name: r'display_label', required: true, includeIfNull: false)
  final String displayLabel;

  @JsonKey(name: r'market_timezone', required: true, includeIfNull: false)
  final String marketTimezone;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageAccountAuthorityStatusEnum.unknownDefaultOpenApi,
  )
  final BrokerageAccountAuthorityStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageAccountAuthority &&
          other.baseCurrency == baseCurrency &&
          other.capabilities == capabilities &&
          other.capabilityVersion == capabilityVersion &&
          other.displayLabel == displayLabel &&
          other.marketTimezone == marketTimezone &&
          other.status == status;

  @override
  int get hashCode =>
      baseCurrency.hashCode +
      capabilities.hashCode +
      capabilityVersion.hashCode +
      displayLabel.hashCode +
      marketTimezone.hashCode +
      status.hashCode;

  factory BrokerageAccountAuthority.fromJson(Map<String, dynamic> json) =>
      _$BrokerageAccountAuthorityFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageAccountAuthorityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageAccountAuthorityStatusEnum {
  @JsonValue(r'available')
  available(r'available'),
  @JsonValue(r'restricted')
  restricted(r'restricted'),
  @JsonValue(r'closed')
  closed(r'closed'),
  @JsonValue(r'unavailable')
  unavailable(r'unavailable'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageAccountAuthorityStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
