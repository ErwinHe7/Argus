//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/evidence_summary.dart';
import 'package:ritual_investing_api_client/generated/model/research_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/asset_risk.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'asset_codex_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AssetCodexDetail {
  /// Returns a new [AssetCodexDetail] instance.
  AssetCodexDetail({
    required this.appearanceReason,

    required this.assetType,

    required this.currency,

    required this.demo,

    required this.evidence,

    required this.id,

    required this.limitations,

    required this.metricsAsOf,

    required this.name,

    required this.revisionId,

    required this.risks,

    required this.saved,

    required this.slug,

    required this.symbol,

    required this.thesis,
  });

  @JsonKey(name: r'appearance_reason', required: true, includeIfNull: false)
  final String appearanceReason;

  @JsonKey(
    name: r'asset_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AssetCodexDetailAssetTypeEnum.unknownDefaultOpenApi,
  )
  final AssetCodexDetailAssetTypeEnum assetType;

  @JsonKey(name: r'currency', required: true, includeIfNull: false)
  final String currency;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final ResearchDisclosure demo;

  @JsonKey(name: r'evidence', required: true, includeIfNull: false)
  final List<EvidenceSummary> evidence;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'limitations', required: true, includeIfNull: false)
  final String limitations;

  @JsonKey(name: r'metrics_as_of', required: true, includeIfNull: false)
  final DateTime metricsAsOf;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'risks', required: true, includeIfNull: false)
  final List<AssetRisk> risks;

  @JsonKey(name: r'saved', required: true, includeIfNull: false)
  final bool saved;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  @JsonKey(name: r'thesis', required: true, includeIfNull: false)
  final String thesis;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetCodexDetail &&
          other.appearanceReason == appearanceReason &&
          other.assetType == assetType &&
          other.currency == currency &&
          other.demo == demo &&
          other.evidence == evidence &&
          other.id == id &&
          other.limitations == limitations &&
          other.metricsAsOf == metricsAsOf &&
          other.name == name &&
          other.revisionId == revisionId &&
          other.risks == risks &&
          other.saved == saved &&
          other.slug == slug &&
          other.symbol == symbol &&
          other.thesis == thesis;

  @override
  int get hashCode =>
      appearanceReason.hashCode +
      assetType.hashCode +
      currency.hashCode +
      demo.hashCode +
      evidence.hashCode +
      id.hashCode +
      limitations.hashCode +
      metricsAsOf.hashCode +
      name.hashCode +
      revisionId.hashCode +
      risks.hashCode +
      saved.hashCode +
      slug.hashCode +
      symbol.hashCode +
      thesis.hashCode;

  factory AssetCodexDetail.fromJson(Map<String, dynamic> json) =>
      _$AssetCodexDetailFromJson(json);

  Map<String, dynamic> toJson() => _$AssetCodexDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AssetCodexDetailAssetTypeEnum {
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

  const AssetCodexDetailAssetTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
