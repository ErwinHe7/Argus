//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/quantity.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_portfolio_holdings200_response_data_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListPortfolioHoldings200ResponseDataInner {
  /// Returns a new [ListPortfolioHoldings200ResponseDataInner] instance.
  ListPortfolioHoldings200ResponseDataInner({
    required this.asOfTransactionId,

    required this.assetId,

    required this.ledgerWatermark,

    required this.marketValue,

    required this.quantity,

    required this.symbol,
  });

  @JsonKey(name: r'as_of_transaction_id', required: true, includeIfNull: false)
  final String asOfTransactionId;

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  // minimum: 0
  @JsonKey(name: r'ledger_watermark', required: true, includeIfNull: false)
  final int ledgerWatermark;

  @JsonKey(name: r'market_value', required: true, includeIfNull: false)
  final Money marketValue;

  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final Quantity quantity;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListPortfolioHoldings200ResponseDataInner &&
          other.asOfTransactionId == asOfTransactionId &&
          other.assetId == assetId &&
          other.ledgerWatermark == ledgerWatermark &&
          other.marketValue == marketValue &&
          other.quantity == quantity &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      asOfTransactionId.hashCode +
      assetId.hashCode +
      ledgerWatermark.hashCode +
      marketValue.hashCode +
      quantity.hashCode +
      symbol.hashCode;

  factory ListPortfolioHoldings200ResponseDataInner.fromJson(
    Map<String, dynamic> json,
  ) => _$ListPortfolioHoldings200ResponseDataInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListPortfolioHoldings200ResponseDataInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
