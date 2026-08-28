//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_asset.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_position.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokeragePosition {
  /// Returns a new [BrokeragePosition] instance.
  BrokeragePosition({
    required this.asset,

    required this.availableQuantity,

    required this.averageCost,

    required this.currency,

    required this.marketValue,

    required this.quantity,
  });

  @JsonKey(name: r'asset', required: true, includeIfNull: false)
  final BrokerageAsset asset;

  @JsonKey(name: r'available_quantity', required: true, includeIfNull: false)
  final String availableQuantity;

  @JsonKey(name: r'average_cost', required: true, includeIfNull: true)
  final String? averageCost;

  @JsonKey(name: r'currency', required: true, includeIfNull: false)
  final String currency;

  @JsonKey(name: r'market_value', required: true, includeIfNull: true)
  final String? marketValue;

  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final String quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokeragePosition &&
          other.asset == asset &&
          other.availableQuantity == availableQuantity &&
          other.averageCost == averageCost &&
          other.currency == currency &&
          other.marketValue == marketValue &&
          other.quantity == quantity;

  @override
  int get hashCode =>
      asset.hashCode +
      availableQuantity.hashCode +
      (averageCost == null ? 0 : averageCost.hashCode) +
      currency.hashCode +
      (marketValue == null ? 0 : marketValue.hashCode) +
      quantity.hashCode;

  factory BrokeragePosition.fromJson(Map<String, dynamic> json) =>
      _$BrokeragePositionFromJson(json);

  Map<String, dynamic> toJson() => _$BrokeragePositionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
