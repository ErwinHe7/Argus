//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_member.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionMember {
  /// Returns a new [SessionMember] instance.
  SessionMember({
    required this.createdAt,

    required this.deletionEpoch,

    required this.deletionRequestedAt,

    required this.status,

    required this.updatedAt,

    required this.userId,
  });

  @JsonKey(name: r'created_at', required: true, includeIfNull: true)
  final DateTime? createdAt;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'deletion_requested_at', required: true, includeIfNull: true)
  final DateTime? deletionRequestedAt;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SessionMemberStatusEnum.unknownDefaultOpenApi,
  )
  final SessionMemberStatusEnum status;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: true)
  final DateTime? updatedAt;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionMember &&
          other.createdAt == createdAt &&
          other.deletionEpoch == deletionEpoch &&
          other.deletionRequestedAt == deletionRequestedAt &&
          other.status == status &&
          other.updatedAt == updatedAt &&
          other.userId == userId;

  @override
  int get hashCode =>
      (createdAt == null ? 0 : createdAt.hashCode) +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      (deletionRequestedAt == null ? 0 : deletionRequestedAt.hashCode) +
      status.hashCode +
      (updatedAt == null ? 0 : updatedAt.hashCode) +
      userId.hashCode;

  factory SessionMember.fromJson(Map<String, dynamic> json) =>
      _$SessionMemberFromJson(json);

  Map<String, dynamic> toJson() => _$SessionMemberToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionMemberStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionMemberStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
