//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_balance.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageBalance {
  /// Returns a new [BrokerageBalance] instance.
  BrokerageBalance({
    required this.buyingPower,

    required this.cash,

    required this.currency,

    required this.marketValue,

    required this.totalEquity,
  });

  @JsonKey(name: r'buying_power', required: true, includeIfNull: true)
  final String? buyingPower;

  @JsonKey(name: r'cash', required: true, includeIfNull: false)
  final String cash;

  @JsonKey(name: r'currency', required: true, includeIfNull: false)
  final String currency;

  @JsonKey(name: r'market_value', required: true, includeIfNull: true)
  final String? marketValue;

  @JsonKey(name: r'total_equity', required: true, includeIfNull: false)
  final String totalEquity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageBalance &&
          other.buyingPower == buyingPower &&
          other.cash == cash &&
          other.currency == currency &&
          other.marketValue == marketValue &&
          other.totalEquity == totalEquity;

  @override
  int get hashCode =>
      (buyingPower == null ? 0 : buyingPower.hashCode) +
      cash.hashCode +
      currency.hashCode +
      (marketValue == null ? 0 : marketValue.hashCode) +
      totalEquity.hashCode;

  factory BrokerageBalance.fromJson(Map<String, dynamic> json) =>
      _$BrokerageBalanceFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageBalanceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
