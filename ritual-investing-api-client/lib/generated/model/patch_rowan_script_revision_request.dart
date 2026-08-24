//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of5.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_rowan_script_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchRowanScriptRevisionRequest {
  /// Returns a new [PatchRowanScriptRevisionRequest] instance.
  PatchRowanScriptRevisionRequest({required this.payload});

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf5 payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchRowanScriptRevisionRequest && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;

  factory PatchRowanScriptRevisionRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchRowanScriptRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchRowanScriptRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
