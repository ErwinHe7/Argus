//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_admin_moderation_case_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchAdminModerationCaseRequest {
  /// Returns a new [PatchAdminModerationCaseRequest] instance.
  PatchAdminModerationCaseRequest({
    required this.reason,

    this.resolutionCode,

    required this.status,
  });

  @JsonKey(name: r'reason', required: true, includeIfNull: false)
  final String reason;

  @JsonKey(name: r'resolution_code', required: false, includeIfNull: false)
  final String? resolutionCode;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        PatchAdminModerationCaseRequestStatusEnum.unknownDefaultOpenApi,
  )
  final PatchAdminModerationCaseRequestStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchAdminModerationCaseRequest &&
          other.reason == reason &&
          other.resolutionCode == resolutionCode &&
          other.status == status;

  @override
  int get hashCode =>
      reason.hashCode + resolutionCode.hashCode + status.hashCode;

  factory PatchAdminModerationCaseRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchAdminModerationCaseRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchAdminModerationCaseRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PatchAdminModerationCaseRequestStatusEnum {
  @JsonValue(r'investigating')
  investigating(r'investigating'),
  @JsonValue(r'resolved')
  resolved(r'resolved'),
  @JsonValue(r'dismissed')
  dismissed(r'dismissed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchAdminModerationCaseRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
