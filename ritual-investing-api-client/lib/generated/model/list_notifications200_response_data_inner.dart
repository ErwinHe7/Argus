//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_notifications200_response_data_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListNotifications200ResponseDataInner {
  /// Returns a new [ListNotifications200ResponseDataInner] instance.
  ListNotifications200ResponseDataInner({
    required this.body,

    required this.deepLink,

    required this.id,

    required this.kind,

    required this.readAt,

    required this.scheduledAt,

    required this.title,
  });

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'deep_link', required: true, includeIfNull: true)
  final String? deepLink;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListNotifications200ResponseDataInner &&
          other.body == body &&
          other.deepLink == deepLink &&
          other.id == id &&
          other.kind == kind &&
          other.readAt == readAt &&
          other.scheduledAt == scheduledAt &&
          other.title == title;

  @override
  int get hashCode =>
      body.hashCode +
      (deepLink == null ? 0 : deepLink.hashCode) +
      id.hashCode +
      kind.hashCode +
      (readAt == null ? 0 : readAt.hashCode) +
      (scheduledAt == null ? 0 : scheduledAt.hashCode) +
      title.hashCode;

  factory ListNotifications200ResponseDataInner.fromJson(
    Map<String, dynamic> json,
  ) => _$ListNotifications200ResponseDataInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$ListNotifications200ResponseDataInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
