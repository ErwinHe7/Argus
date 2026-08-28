//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_profile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberProfile {
  /// Returns a new [MemberProfile] instance.
  MemberProfile({
    required this.avatarMediaId,

    required this.deletionEpoch,

    required this.displayName,

    required this.locale,

    required this.updatedAt,

    required this.userId,
  });

  @JsonKey(name: r'avatar_media_id', required: true, includeIfNull: true)
  final String? avatarMediaId;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'display_name', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'locale', required: true, includeIfNull: false)
  final String locale;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: true)
  final DateTime? updatedAt;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberProfile &&
          other.avatarMediaId == avatarMediaId &&
          other.deletionEpoch == deletionEpoch &&
          other.displayName == displayName &&
          other.locale == locale &&
          other.updatedAt == updatedAt &&
          other.userId == userId;

  @override
  int get hashCode =>
      (avatarMediaId == null ? 0 : avatarMediaId.hashCode) +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      displayName.hashCode +
      locale.hashCode +
      (updatedAt == null ? 0 : updatedAt.hashCode) +
      userId.hashCode;

  factory MemberProfile.fromJson(Map<String, dynamic> json) =>
      _$MemberProfileFromJson(json);

  Map<String, dynamic> toJson() => _$MemberProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
