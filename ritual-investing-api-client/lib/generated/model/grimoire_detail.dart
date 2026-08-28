//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/research_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/asset_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'grimoire_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GrimoireDetail {
  /// Returns a new [GrimoireDetail] instance.
  GrimoireDetail({
    required this.assets,

    required this.curatorLabel,

    required this.demo,

    required this.description,

    required this.id,

    required this.revisionId,

    required this.saved,

    required this.slug,

    required this.theme,

    required this.title,
  });

  @JsonKey(name: r'assets', required: true, includeIfNull: false)
  final List<AssetSummary> assets;

  @JsonKey(name: r'curator_label', required: true, includeIfNull: false)
  final String curatorLabel;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final ResearchDisclosure demo;

  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'saved', required: true, includeIfNull: false)
  final bool saved;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'theme', required: true, includeIfNull: false)
  final String theme;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrimoireDetail &&
          other.assets == assets &&
          other.curatorLabel == curatorLabel &&
          other.demo == demo &&
          other.description == description &&
          other.id == id &&
          other.revisionId == revisionId &&
          other.saved == saved &&
          other.slug == slug &&
          other.theme == theme &&
          other.title == title;

  @override
  int get hashCode =>
      assets.hashCode +
      curatorLabel.hashCode +
      demo.hashCode +
      description.hashCode +
      id.hashCode +
      revisionId.hashCode +
      saved.hashCode +
      slug.hashCode +
      theme.hashCode +
      title.hashCode;

  factory GrimoireDetail.fromJson(Map<String, dynamic> json) =>
      _$GrimoireDetailFromJson(json);

  Map<String, dynamic> toJson() => _$GrimoireDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
