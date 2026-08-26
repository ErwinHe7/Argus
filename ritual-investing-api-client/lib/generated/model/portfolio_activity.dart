//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/signed_money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'portfolio_activity.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PortfolioActivity {
  /// Returns a new [PortfolioActivity] instance.
  PortfolioActivity({
    required this.cash,

    required this.demo,

    required this.descriptionCode,

    required this.effectiveAt,

    required this.id,

    required this.ledgerWatermark,

    required this.type,
  });

  @JsonKey(name: r'cash', required: true, includeIfNull: false)
  final SignedMoney cash;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'description_code', required: true, includeIfNull: false)
  final String descriptionCode;

  @JsonKey(name: r'effective_at', required: true, includeIfNull: false)
  final DateTime effectiveAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  // minimum: 0
  @JsonKey(name: r'ledger_watermark', required: true, includeIfNull: false)
  final int ledgerWatermark;

  @JsonKey(
    name: r'type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PortfolioActivityTypeEnum.unknownDefaultOpenApi,
  )
  final PortfolioActivityTypeEnum type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortfolioActivity &&
          other.cash == cash &&
          other.demo == demo &&
          other.descriptionCode == descriptionCode &&
          other.effectiveAt == effectiveAt &&
          other.id == id &&
          other.ledgerWatermark == ledgerWatermark &&
          other.type == type;

  @override
  int get hashCode =>
      cash.hashCode +
      demo.hashCode +
      descriptionCode.hashCode +
      effectiveAt.hashCode +
      id.hashCode +
      ledgerWatermark.hashCode +
      type.hashCode;

  factory PortfolioActivity.fromJson(Map<String, dynamic> json) =>
      _$PortfolioActivityFromJson(json);

  Map<String, dynamic> toJson() => _$PortfolioActivityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PortfolioActivityTypeEnum {
  @JsonValue(r'contribution')
  contribution(r'contribution'),
  @JsonValue(r'order')
  order(r'order'),
  @JsonValue(r'rebalance')
  rebalance(r'rebalance'),
  @JsonValue(r'recurring')
  recurring(r'recurring'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PortfolioActivityTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
