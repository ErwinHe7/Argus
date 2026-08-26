//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/list_admin_asset_codex200_response_data_inner_revision_payload_any_of.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_ritual_scenario_revision_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateRitualScenarioRevisionRequest {
  /// Returns a new [CreateRitualScenarioRevisionRequest] instance.
  CreateRitualScenarioRevisionRequest({
    required this.payload,

    required this.sourceRevisionId,
  });

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf payload;

  @JsonKey(name: r'source_revision_id', required: true, includeIfNull: false)
  final String sourceRevisionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateRitualScenarioRevisionRequest &&
          other.payload == payload &&
          other.sourceRevisionId == sourceRevisionId;

  @override
  int get hashCode => payload.hashCode + sourceRevisionId.hashCode;

  factory CreateRitualScenarioRevisionRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateRitualScenarioRevisionRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateRitualScenarioRevisionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
