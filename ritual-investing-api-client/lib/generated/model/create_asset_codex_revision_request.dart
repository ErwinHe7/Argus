//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of1.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_asset_codex_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAssetCodexRevisionRequest {
  /// Returns a new [CreateAssetCodexRevisionRequest] instance.
  CreateAssetCodexRevisionRequest({
    required this.payload,

    required this.sourceRevisionId,
  });

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf1 payload;

  @JsonKey(name: r'source_revision_id', required: true, includeIfNull: false)
  final String sourceRevisionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAssetCodexRevisionRequest &&
          other.payload == payload &&
          other.sourceRevisionId == sourceRevisionId;

  @override
  int get hashCode => payload.hashCode + sourceRevisionId.hashCode;

  factory CreateAssetCodexRevisionRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAssetCodexRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAssetCodexRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
