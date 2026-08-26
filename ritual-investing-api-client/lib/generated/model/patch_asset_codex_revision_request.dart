//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of1.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_asset_codex_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchAssetCodexRevisionRequest {
  /// Returns a new [PatchAssetCodexRevisionRequest] instance.
  PatchAssetCodexRevisionRequest({required this.payload});

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1 payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchAssetCodexRevisionRequest && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;

  factory PatchAssetCodexRevisionRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchAssetCodexRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchAssetCodexRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
