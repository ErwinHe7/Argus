//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_ritual_scenario_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchRitualScenarioRevisionRequest {
  /// Returns a new [PatchRitualScenarioRevisionRequest] instance.
  PatchRitualScenarioRevisionRequest({required this.payload});

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchRitualScenarioRevisionRequest && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;

  factory PatchRitualScenarioRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$PatchRitualScenarioRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchRitualScenarioRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
