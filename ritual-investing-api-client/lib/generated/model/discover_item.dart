//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/circle_template_summary.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item_one_of2.dart';
import 'package:ritual_investing_api_client/generated/model/coven_summary.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item_one_of1.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item_one_of.dart';
import 'package:ritual_investing_api_client/generated/model/discover_item_one_of3.dart';
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
    required this.asset,

    required this.kind,

    required this.coven,

    required this.grimoire,

    required this.circleTemplate,
  });

  @JsonKey(name: r'asset', required: true, includeIfNull: false)
  final AssetSummary asset;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DiscoverItemKindEnum.unknownDefaultOpenApi,
  )
  final DiscoverItemKindEnum kind;

  @JsonKey(name: r'coven', required: true, includeIfNull: false)
  final CovenSummary coven;

  @JsonKey(name: r'grimoire', required: true, includeIfNull: false)
  final GrimoireSummary grimoire;

  @JsonKey(name: r'circle_template', required: true, includeIfNull: false)
  final CircleTemplateSummary circleTemplate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoverItem &&
          other.asset == asset &&
          other.kind == kind &&
          other.coven == coven &&
          other.grimoire == grimoire &&
          other.circleTemplate == circleTemplate;

  @override
  int get hashCode =>
      asset.hashCode +
      kind.hashCode +
      coven.hashCode +
      grimoire.hashCode +
      circleTemplate.hashCode;

  factory DiscoverItem.fromJson(Map<String, dynamic> json) =>
      _$DiscoverItemFromJson(json);

  Map<String, dynamic> toJson() => _$DiscoverItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DiscoverItemKindEnum {
  @JsonValue(r'circle_template')
  circleTemplate(r'circle_template'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DiscoverItemKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
