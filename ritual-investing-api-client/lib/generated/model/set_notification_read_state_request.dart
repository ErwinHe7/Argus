//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'set_notification_read_state_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SetNotificationReadStateRequest {
  /// Returns a new [SetNotificationReadStateRequest] instance.
  SetNotificationReadStateRequest({required this.read});

  @JsonKey(name: r'read', required: true, includeIfNull: false)
  final bool read;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetNotificationReadStateRequest && other.read == read;

  @override
  int get hashCode => read.hashCode;

  factory SetNotificationReadStateRequest.fromJson(Map<String, dynamic> json) =>
      _$SetNotificationReadStateRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$SetNotificationReadStateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
