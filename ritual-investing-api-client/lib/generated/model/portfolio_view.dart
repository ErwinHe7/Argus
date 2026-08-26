//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:ritual_investing_api_client/generated/model/create_portfolio_request_target_allocation_inner.dart';
import 'package:ritual_investing_api_client/generated/model/list_portfolio_holdings200_response_data_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'portfolio_view.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PortfolioView {
  /// Returns a new [PortfolioView] instance.
  PortfolioView({
    required this.asOfTransactionId,

    required this.cash,

    required this.currency,

    required this.demo,

    required this.id,

    required this.isDefault,

    required this.latestValuation,

    required this.ledgerWatermark,

    required this.name,

    required this.positions,

    required this.status,

    required this.targetAllocation,

    required this.version,
  });

  @JsonKey(name: r'as_of_transaction_id', required: true, includeIfNull: true)
  final String? asOfTransactionId;

  @JsonKey(name: r'cash', required: true, includeIfNull: false)
  final Money cash;

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PortfolioViewCurrencyEnum.unknownDefaultOpenApi,
  )
  final PortfolioViewCurrencyEnum currency;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'is_default', required: true, includeIfNull: false)
  final bool isDefault;

  @JsonKey(name: r'latest_valuation', required: true, includeIfNull: false)
  final Money latestValuation;

  // minimum: 0
  @JsonKey(name: r'ledger_watermark', required: true, includeIfNull: false)
  final int ledgerWatermark;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'positions', required: true, includeIfNull: false)
  final List<ListPortfolioHoldings200ResponseDataInner> positions;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PortfolioViewStatusEnum.unknownDefaultOpenApi,
  )
  final PortfolioViewStatusEnum status;

  @JsonKey(name: r'target_allocation', required: true, includeIfNull: false)
  final List<CreatePortfolioRequestTargetAllocationInner> targetAllocation;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortfolioView &&
          other.asOfTransactionId == asOfTransactionId &&
          other.cash == cash &&
          other.currency == currency &&
          other.demo == demo &&
          other.id == id &&
          other.isDefault == isDefault &&
          other.latestValuation == latestValuation &&
          other.ledgerWatermark == ledgerWatermark &&
          other.name == name &&
          other.positions == positions &&
          other.status == status &&
          other.targetAllocation == targetAllocation &&
          other.version == version;

  @override
  int get hashCode =>
      (asOfTransactionId == null ? 0 : asOfTransactionId.hashCode) +
      cash.hashCode +
      currency.hashCode +
      demo.hashCode +
      id.hashCode +
      isDefault.hashCode +
      latestValuation.hashCode +
      ledgerWatermark.hashCode +
      name.hashCode +
      positions.hashCode +
      status.hashCode +
      targetAllocation.hashCode +
      version.hashCode;

  factory PortfolioView.fromJson(Map<String, dynamic> json) =>
      _$PortfolioViewFromJson(json);

  Map<String, dynamic> toJson() => _$PortfolioViewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PortfolioViewCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PortfolioViewCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PortfolioViewStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'archived')
  archived(r'archived'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PortfolioViewStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
