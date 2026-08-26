//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of4.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_circle_template_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchCircleTemplateRevisionRequest {
  /// Returns a new [PatchCircleTemplateRevisionRequest] instance.
  PatchCircleTemplateRevisionRequest({required this.payload});

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4 payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchCircleTemplateRevisionRequest && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;

  factory PatchCircleTemplateRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$PatchCircleTemplateRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchCircleTemplateRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
