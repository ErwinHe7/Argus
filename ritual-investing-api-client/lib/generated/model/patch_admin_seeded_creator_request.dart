//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_admin_seeded_creator_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchAdminSeededCreatorRequest {
  /// Returns a new [PatchAdminSeededCreatorRequest] instance.
  PatchAdminSeededCreatorRequest({
    this.avatarMediaId,

    this.bio,

    this.displayName,

    this.status,
  });

  @JsonKey(name: r'avatar_media_id', required: false, includeIfNull: false)
  final String? avatarMediaId;

  @JsonKey(name: r'bio', required: false, includeIfNull: false)
  final String? bio;

  @JsonKey(name: r'display_name', required: false, includeIfNull: false)
  final String? displayName;

  @JsonKey(
    name: r'status',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PatchAdminSeededCreatorRequestStatusEnum.unknownDefaultOpenApi,
  )
  final PatchAdminSeededCreatorRequestStatusEnum? status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchAdminSeededCreatorRequest &&
          other.avatarMediaId == avatarMediaId &&
          other.bio == bio &&
          other.displayName == displayName &&
          other.status == status;

  @override
  int get hashCode =>
      (avatarMediaId == null ? 0 : avatarMediaId.hashCode) +
      bio.hashCode +
      displayName.hashCode +
      status.hashCode;

  factory PatchAdminSeededCreatorRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchAdminSeededCreatorRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchAdminSeededCreatorRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PatchAdminSeededCreatorRequestStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'retired')
  retired(r'retired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchAdminSeededCreatorRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
