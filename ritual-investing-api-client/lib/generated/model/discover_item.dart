//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/circle_template_summary.dart';
import 'package:ritual_investing_api_client/generated/model/coven_summary.dart';
import 'package:ritual_investing_api_client/generated/model/asset_summary.dart';
import 'package:ritual_investing_api_client/generated/model/grimoire_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'discover_item.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DiscoverItem {
  /// Returns a new [DiscoverItem] instance.
  DiscoverItem({
    this.asset,

    this.circleTemplate,

    this.coven,

    this.grimoire,

    required this.kind,
  });

  @JsonKey(name: r'asset', required: false, includeIfNull: false)
  final AssetSummary? asset;

  @JsonKey(name: r'circle_template', required: false, includeIfNull: false)
  final CircleTemplateSummary? circleTemplate;

  @JsonKey(name: r'coven', required: false, includeIfNull: false)
  final CovenSummary? coven;

  @JsonKey(name: r'grimoire', required: false, includeIfNull: false)
  final GrimoireSummary? grimoire;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DiscoverItemKindEnum.unknownDefaultOpenApi,
  )
  final DiscoverItemKindEnum kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItem &&
          other.asset == asset &&
          other.circleTemplate == circleTemplate &&
          other.coven == coven &&
          other.grimoire == grimoire &&
          other.kind == kind;

  @override
  int get hashCode =>
      (asset == null ? 0 : asset.hashCode) +
      (circleTemplate == null ? 0 : circleTemplate.hashCode) +
      (coven == null ? 0 : coven.hashCode) +
      (grimoire == null ? 0 : grimoire.hashCode) +
      kind.hashCode;

  factory DiscoverItem.fromJson(Map<String, dynamic> json) =>
      _$DiscoverItemFromJson(json);

  Map<String, dynamic> toJson() => _$DiscoverItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DiscoverItemKindEnum {
  @JsonValue(r'asset')
  asset(r'asset'),
  @JsonValue(r'coven')
  coven(r'coven'),
  @JsonValue(r'grimoire')
  grimoire(r'grimoire'),
  @JsonValue(r'circle_template')
  circleTemplate(r'circle_template'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DiscoverItemKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
