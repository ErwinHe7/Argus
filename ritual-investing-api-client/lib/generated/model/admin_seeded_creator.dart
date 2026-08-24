//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_seeded_creator.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminSeededCreator {
  /// Returns a new [AdminSeededCreator] instance.
  AdminSeededCreator({
    required this.avatarMediaId,

    required this.bio,

    required this.displayName,

    required this.etag,

    required this.id,

    required this.isFictional,

    required this.slug,

    required this.status,

    required this.version,
  });

  @JsonKey(name: r'avatar_media_id', required: true, includeIfNull: true)
  final String? avatarMediaId;

  @JsonKey(name: r'bio', required: true, includeIfNull: false)
  final String bio;

  @JsonKey(name: r'display_name', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'etag', required: true, includeIfNull: false)
  final String etag;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'is_fictional', required: true, includeIfNull: false)
  final bool isFictional;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminSeededCreatorStatusEnum.unknownDefaultOpenApi,
  )
  final AdminSeededCreatorStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminSeededCreator &&
          other.avatarMediaId == avatarMediaId &&
          other.bio == bio &&
          other.displayName == displayName &&
          other.etag == etag &&
          other.id == id &&
          other.isFictional == isFictional &&
          other.slug == slug &&
          other.status == status &&
          other.version == version;

  @override
  int get hashCode =>
      (avatarMediaId == null ? 0 : avatarMediaId.hashCode) +
      bio.hashCode +
      displayName.hashCode +
      etag.hashCode +
      id.hashCode +
      isFictional.hashCode +
      slug.hashCode +
      status.hashCode +
      version.hashCode;

  factory AdminSeededCreator.fromJson(Map<String, dynamic> json) =>
      _$AdminSeededCreatorFromJson(json);

  Map<String, dynamic> toJson() => _$AdminSeededCreatorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminSeededCreatorStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'retired')
  retired(r'retired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminSeededCreatorStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
