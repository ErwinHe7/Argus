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

part 'search_result.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SearchResult {
  /// Returns a new [SearchResult] instance.
  SearchResult({
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
    unknownEnumValue: SearchResultKindEnum.unknownDefaultOpenApi,
  )
  final SearchResultKindEnum kind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          other.asset == asset &&
          other.circleTemplate == circleTemplate &&
          other.coven == coven &&
          other.grimoire == grimoire &&
          other.kind == kind;

  @override
  int get hashCode =>
      asset.hashCode +
      circleTemplate.hashCode +
      coven.hashCode +
      grimoire.hashCode +
      kind.hashCode;

  factory SearchResult.fromJson(Map<String, dynamic> json) =>
      _$SearchResultFromJson(json);

  Map<String, dynamic> toJson() => _$SearchResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SearchResultKindEnum {
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

  const SearchResultKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
