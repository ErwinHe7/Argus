//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of6_sections_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_briefing_template_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateBriefingTemplateRequest {
  /// Returns a new [CreateBriefingTemplateRequest] instance.
  CreateBriefingTemplateRequest({
    required this.briefingType,

    required this.sections,

    required this.slug,

    required this.templateKey,

    required this.title,
  });

  @JsonKey(
    name: r'briefing_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateBriefingTemplateRequestBriefingTypeEnum.unknownDefaultOpenApi,
  )
  final CreateBriefingTemplateRequestBriefingTypeEnum briefingType;

  @JsonKey(name: r'sections', required: true, includeIfNull: false)
  final List<
    ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6SectionsInner
  >
  sections;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'template_key', required: true, includeIfNull: false)
  final String templateKey;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateBriefingTemplateRequest &&
          other.briefingType == briefingType &&
          other.sections == sections &&
          other.slug == slug &&
          other.templateKey == templateKey &&
          other.title == title;

  @override
  int get hashCode =>
      briefingType.hashCode +
      sections.hashCode +
      slug.hashCode +
      templateKey.hashCode +
      title.hashCode;

  factory CreateBriefingTemplateRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateBriefingTemplateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateBriefingTemplateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateBriefingTemplateRequestBriefingTypeEnum {
  @JsonValue(r'daily')
  daily(r'daily'),
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'moon_cycle')
  moonCycle(r'moon_cycle'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateBriefingTemplateRequestBriefingTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
