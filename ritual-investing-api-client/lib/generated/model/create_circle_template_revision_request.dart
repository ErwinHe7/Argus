//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of4.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_circle_template_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateCircleTemplateRevisionRequest {
  /// Returns a new [CreateCircleTemplateRevisionRequest] instance.
  CreateCircleTemplateRevisionRequest({
    required this.payload,

    required this.sourceRevisionId,
  });

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4 payload;

  @JsonKey(name: r'source_revision_id', required: true, includeIfNull: false)
  final String sourceRevisionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateCircleTemplateRevisionRequest &&
          other.payload == payload &&
          other.sourceRevisionId == sourceRevisionId;

  @override
  int get hashCode => payload.hashCode + sourceRevisionId.hashCode;

  factory CreateCircleTemplateRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateCircleTemplateRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateCircleTemplateRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
