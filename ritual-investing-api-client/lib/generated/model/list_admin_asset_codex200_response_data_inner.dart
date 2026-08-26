//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInner {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInner] instance.
  ListAdminAssetCodex200ResponseDataInner({
    required this.currentPublishedRevisionId,

    required this.etag,

    required this.id,

    required this.kind,

    this.revision,

    required this.slug,

    required this.status,

    required this.version,
  });

  @JsonKey(
    name: r'current_published_revision_id',
    required: true,
    includeIfNull: true,
  )
  final String? currentPublishedRevisionId;

  @JsonKey(name: r'etag', required: true, includeIfNull: false)
  final String etag;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerKindEnum.unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerKindEnum kind;

  @JsonKey(name: r'revision', required: false, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevision? revision;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerStatusEnum.unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInner &&
          other.currentPublishedRevisionId == currentPublishedRevisionId &&
          other.etag == etag &&
          other.id == id &&
          other.kind == kind &&
          other.revision == revision &&
          other.slug == slug &&
          other.status == status &&
          other.version == version;

  @override
  int get hashCode =>
      (currentPublishedRevisionId == null
          ? 0
          : currentPublishedRevisionId.hashCode) +
      etag.hashCode +
      id.hashCode +
      kind.hashCode +
      revision.hashCode +
      slug.hashCode +
      status.hashCode +
      version.hashCode;

  factory ListAdminAssetCodex200ResponseDataInner.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminAssetCodex200ResponseDataInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminAssetCodex200ResponseDataInnerKindEnum {
  @JsonValue(r'ritual_scenario')
  ritualScenario(r'ritual_scenario'),
  @JsonValue(r'asset_codex')
  assetCodex(r'asset_codex'),
  @JsonValue(r'coven_entry')
  covenEntry(r'coven_entry'),
  @JsonValue(r'grimoire')
  grimoire(r'grimoire'),
  @JsonValue(r'circle_template')
  circleTemplate(r'circle_template'),
  @JsonValue(r'rowan_script')
  rowanScript(r'rowan_script'),
  @JsonValue(r'briefing_template')
  briefingTemplate(r'briefing_template'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum ListAdminAssetCodex200ResponseDataInnerStatusEnum {
  @JsonValue(r'draft')
  draft(r'draft'),
  @JsonValue(r'published')
  published(r'published'),
  @JsonValue(r'withdrawn')
  withdrawn(r'withdrawn'),
  @JsonValue(r'retired')
  retired(r'retired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
