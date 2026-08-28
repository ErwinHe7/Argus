//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/research_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AssetSummary {
  /// Returns a new [AssetSummary] instance.
  AssetSummary({
    required this.appearanceReason,

    required this.assetType,

    required this.currency,

    required this.demo,

    required this.id,

    required this.name,

    required this.revisionId,

    required this.slug,

    required this.symbol,
  });

  @JsonKey(name: r'appearance_reason', required: true, includeIfNull: false)
  final String appearanceReason;

  @JsonKey(
    name: r'asset_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AssetSummaryAssetTypeEnum.unknownDefaultOpenApi,
  )
  final AssetSummaryAssetTypeEnum assetType;

  @JsonKey(name: r'currency', required: true, includeIfNull: false)
  final String currency;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final ResearchDisclosure demo;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetSummary &&
          other.appearanceReason == appearanceReason &&
          other.assetType == assetType &&
          other.currency == currency &&
          other.demo == demo &&
          other.id == id &&
          other.name == name &&
          other.revisionId == revisionId &&
          other.slug == slug &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      appearanceReason.hashCode +
      assetType.hashCode +
      currency.hashCode +
      demo.hashCode +
      id.hashCode +
      name.hashCode +
      revisionId.hashCode +
      slug.hashCode +
      symbol.hashCode;

  factory AssetSummary.fromJson(Map<String, dynamic> json) =>
      _$AssetSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$AssetSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AssetSummaryAssetTypeEnum {
  @JsonValue(r'equity')
  equity(r'equity'),
  @JsonValue(r'etf')
  etf(r'etf'),
  @JsonValue(r'market_index')
  marketIndex(r'market_index'),
  @JsonValue(r'cash')
  cash(r'cash'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AssetSummaryAssetTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
