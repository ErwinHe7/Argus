//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_seeded_creator_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminSeededCreatorRequest {
  /// Returns a new [CreateAdminSeededCreatorRequest] instance.
  CreateAdminSeededCreatorRequest({
    required this.avatarMediaId,

    required this.bio,

    required this.displayName,

    required this.slug,

    required this.status,
  });

  @JsonKey(name: r'avatar_media_id', required: true, includeIfNull: true)
  final String? avatarMediaId;

  @JsonKey(name: r'bio', required: true, includeIfNull: false)
  final String bio;

  @JsonKey(name: r'display_name', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateAdminSeededCreatorRequestStatusEnum.unknownDefaultOpenApi,
  )
  final CreateAdminSeededCreatorRequestStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminSeededCreatorRequest &&
          other.avatarMediaId == avatarMediaId &&
          other.bio == bio &&
          other.displayName == displayName &&
          other.slug == slug &&
          other.status == status;

  @override
  int get hashCode =>
      (avatarMediaId == null ? 0 : avatarMediaId.hashCode) +
      bio.hashCode +
      displayName.hashCode +
      slug.hashCode +
      status.hashCode;

  factory CreateAdminSeededCreatorRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateAdminSeededCreatorRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminSeededCreatorRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateAdminSeededCreatorRequestStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'retired')
  retired(r'retired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminSeededCreatorRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
