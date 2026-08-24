//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'portfolio_snapshot.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PortfolioSnapshot {
  /// Returns a new [PortfolioSnapshot] instance.
  PortfolioSnapshot({
    required this.asOf,

    required this.asOfTransactionId,

    required this.cash,

    required this.demo,

    required this.id,

    required this.ledgerWatermark,

    required this.marketValue,
  });

  @JsonKey(name: r'as_of', required: true, includeIfNull: false)
  final DateTime asOf;

  @JsonKey(name: r'as_of_transaction_id', required: true, includeIfNull: false)
  final String asOfTransactionId;

  @JsonKey(name: r'cash', required: true, includeIfNull: false)
  final Money cash;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  // minimum: 0
  @JsonKey(name: r'ledger_watermark', required: true, includeIfNull: false)
  final int ledgerWatermark;

  @JsonKey(name: r'market_value', required: true, includeIfNull: false)
  final Money marketValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PortfolioSnapshot &&
          other.asOf == asOf &&
          other.asOfTransactionId == asOfTransactionId &&
          other.cash == cash &&
          other.demo == demo &&
          other.id == id &&
          other.ledgerWatermark == ledgerWatermark &&
          other.marketValue == marketValue;

  @override
  int get hashCode =>
      asOf.hashCode +
      asOfTransactionId.hashCode +
      cash.hashCode +
      demo.hashCode +
      id.hashCode +
      ledgerWatermark.hashCode +
      marketValue.hashCode;

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> json) =>
      _$PortfolioSnapshotFromJson(json);

  Map<String, dynamic> toJson() => _$PortfolioSnapshotToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
