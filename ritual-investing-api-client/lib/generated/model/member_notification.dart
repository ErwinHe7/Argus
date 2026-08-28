//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_notification.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberNotification {
  /// Returns a new [MemberNotification] instance.
  MemberNotification({
    required this.body,

    required this.createdAt,

    required this.deepLink,

    required this.deletionEpoch,

    required this.id,

    required this.kind,

    required this.readAt,

    required this.scheduledAt,

    required this.title,

    required this.userId,
  });

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'deep_link', required: true, includeIfNull: true)
  final String? deepLink;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'kind', required: true, includeIfNull: false)
  final String kind;

  @JsonKey(name: r'read_at', required: true, includeIfNull: true)
  final DateTime? readAt;

  @JsonKey(name: r'scheduled_at', required: true, includeIfNull: true)
  final DateTime? scheduledAt;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberNotification &&
          other.body == body &&
          other.createdAt == createdAt &&
          other.deepLink == deepLink &&
          other.deletionEpoch == deletionEpoch &&
          other.id == id &&
          other.kind == kind &&
          other.readAt == readAt &&
          other.scheduledAt == scheduledAt &&
          other.title == title &&
          other.userId == userId;

  @override
  int get hashCode =>
      body.hashCode +
      createdAt.hashCode +
      (deepLink == null ? 0 : deepLink.hashCode) +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      id.hashCode +
      kind.hashCode +
      (readAt == null ? 0 : readAt.hashCode) +
      (scheduledAt == null ? 0 : scheduledAt.hashCode) +
      title.hashCode +
      userId.hashCode;

  factory MemberNotification.fromJson(Map<String, dynamic> json) =>
      _$MemberNotificationFromJson(json);

  Map<String, dynamic> toJson() => _$MemberNotificationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
