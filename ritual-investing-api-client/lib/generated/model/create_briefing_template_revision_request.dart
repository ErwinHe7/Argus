//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of6.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_briefing_template_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateBriefingTemplateRevisionRequest {
  /// Returns a new [CreateBriefingTemplateRevisionRequest] instance.
  CreateBriefingTemplateRevisionRequest({
    required this.payload,

    required this.sourceRevisionId,
  });

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf6 payload;

  @JsonKey(name: r'source_revision_id', required: true, includeIfNull: false)
  final String sourceRevisionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateBriefingTemplateRevisionRequest &&
          other.payload == payload &&
          other.sourceRevisionId == sourceRevisionId;

  @override
  int get hashCode => payload.hashCode + sourceRevisionId.hashCode;

  factory CreateBriefingTemplateRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateBriefingTemplateRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateBriefingTemplateRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
