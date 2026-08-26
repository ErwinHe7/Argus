//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'circle_template_detail_assets_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CircleTemplateDetailAssetsInner {
  /// Returns a new [CircleTemplateDetailAssetsInner] instance.
  CircleTemplateDetailAssetsInner({
    required this.appearanceReason,

    required this.assetType,

    required this.currency,

    required this.demo,

    required this.id,

    required this.name,

    required this.note,

    required this.ordinal,

    required this.revisionId,

    required this.slug,

    required this.symbol,

    required this.weightBps,
  });

  @JsonKey(name: r'appearance_reason', required: true, includeIfNull: false)
  final String appearanceReason;

  @JsonKey(
    name: r'asset_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CircleTemplateDetailAssetsInnerAssetTypeEnum.unknownDefaultOpenApi,
  )
  final CircleTemplateDetailAssetsInnerAssetTypeEnum assetType;

  @JsonKey(
    name: r'currency',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CircleTemplateDetailAssetsInnerCurrencyEnum.unknownDefaultOpenApi,
  )
  final CircleTemplateDetailAssetsInnerCurrencyEnum currency;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'note', required: true, includeIfNull: true)
  final String? note;

  // minimum: 1
  // maximum: 50
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'symbol', required: true, includeIfNull: false)
  final String symbol;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'weight_bps', required: true, includeIfNull: true)
  final int? weightBps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleTemplateDetailAssetsInner &&
          other.appearanceReason == appearanceReason &&
          other.assetType == assetType &&
          other.currency == currency &&
          other.demo == demo &&
          other.id == id &&
          other.name == name &&
          other.note == note &&
          other.ordinal == ordinal &&
          other.revisionId == revisionId &&
          other.slug == slug &&
          other.symbol == symbol &&
          other.weightBps == weightBps;

  @override
  int get hashCode =>
      appearanceReason.hashCode +
      assetType.hashCode +
      currency.hashCode +
      demo.hashCode +
      id.hashCode +
      name.hashCode +
      (note == null ? 0 : note.hashCode) +
      ordinal.hashCode +
      revisionId.hashCode +
      slug.hashCode +
      symbol.hashCode +
      (weightBps == null ? 0 : weightBps.hashCode);

  factory CircleTemplateDetailAssetsInner.fromJson(Map<String, dynamic> json) =>
      _$CircleTemplateDetailAssetsInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CircleTemplateDetailAssetsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CircleTemplateDetailAssetsInnerAssetTypeEnum {
  @JsonValue(r'equity')
  equity(r'equity'),
  @JsonValue(r'etf')
  etf(r'etf'),
  @JsonValue(r'index')
  marketIndex(r'index'),
  @JsonValue(r'cash')
  cash(r'cash'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CircleTemplateDetailAssetsInnerAssetTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CircleTemplateDetailAssetsInnerCurrencyEnum {
  @JsonValue(r'USD')
  USD(r'USD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CircleTemplateDetailAssetsInnerCurrencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
