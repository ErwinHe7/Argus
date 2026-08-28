//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_asset.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageAsset {
  /// Returns a new [BrokerageAsset] instance.
  BrokerageAsset({
    required this.assetKind,

    required this.currency,

    required this.exchange,

    required this.instrumentId,

    required this.marketTimezone,

    required this.name,

    required this.providerAssetKind,

    required this.supported,

    required this.symbol,
  });

  @JsonKey(
    name: r'asset_kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageAssetAssetKindEnum.unknownDefaultOpenApi,
  )
  final BrokerageAssetAssetKindEnum assetKind;

  @JsonKey(name: r'currency', required: true, includeIfNull: false)
  final String currency;

  @JsonKey(name: r'exchange', required: true, includeIfNull: true)
  final String? exchange;

  @JsonKey(name: r'instrument_id', required: true, includeIfNull: false)
  final String instrumentId;

  @JsonKey(name: r'market_timezone', required: true, includeIfNull: false)
  final String marketTimezone;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'provider_asset_kind', required: true, includeIfNull: false)
  final String providerAssetKind;

  @JsonKey(name: r'supported', required: true, includeIfNull: false)
  final bool supported;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageAsset &&
          other.assetKind == assetKind &&
          other.currency == currency &&
          other.exchange == exchange &&
          other.instrumentId == instrumentId &&
          other.marketTimezone == marketTimezone &&
          other.name == name &&
          other.providerAssetKind == providerAssetKind &&
          other.supported == supported &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      assetKind.hashCode +
      currency.hashCode +
      (exchange == null ? 0 : exchange.hashCode) +
      instrumentId.hashCode +
      marketTimezone.hashCode +
      name.hashCode +
      providerAssetKind.hashCode +
      supported.hashCode +
      symbol.hashCode;

  factory BrokerageAsset.fromJson(Map<String, dynamic> json) =>
      _$BrokerageAssetFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageAssetToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageAssetAssetKindEnum {
  @JsonValue(r'equity')
  equity(r'equity'),
  @JsonValue(r'etf')
  etf(r'etf'),
  @JsonValue(r'unsupported')
  unsupported(r'unsupported'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageAssetAssetKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
