//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of6_sections_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_admin_asset_codex200_response_data_inner_revision_payload_any_of6.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 {
  /// Returns a new [ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6] instance.
  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6({
    required this.briefingType,

    required this.sections,

    required this.templateKey,

    required this.title,
  });

  @JsonKey(
    name: r'briefing_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
            .unknownDefaultOpenApi,
  )
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum
  briefingType;

  @JsonKey(name: r'sections', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  >
  sections;

  @JsonKey(name: r'template_key', required: true, includeIfNull: false)
  final String templateKey;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 &&
          other.briefingType == briefingType &&
          other.sections == sections &&
          other.templateKey == templateKey &&
          other.title == title;

  @override
  int get hashCode =>
      briefingType.hashCode +
      sections.hashCode +
      templateKey.hashCode +
      title.hashCode;

  factory ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6.fromJson(
    Map<String, dynamic> json,
  ) => _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6FromJson(
    json,
  );

  Map<String, dynamic> toJson() =>
      _$ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6ToJson(
        this,
      );

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum {
  @JsonValue(r'daily')
  daily(r'daily'),
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'moon_cycle')
  moonCycle(r'moon_cycle'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6BriefingTypeEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}
