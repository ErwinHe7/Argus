//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'read_all_notifications_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReadAllNotificationsRequest {
  /// Returns a new [ReadAllNotificationsRequest] instance.
  ReadAllNotificationsRequest({this.before});

  @JsonKey(name: r'before', required: false, includeIfNull: false)
  final DateTime? before;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadAllNotificationsRequest && other.before == before;

  @override
  int get hashCode => before.hashCode;

  factory ReadAllNotificationsRequest.fromJson(Map<String, dynamic> json) =>
      _$ReadAllNotificationsRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ReadAllNotificationsRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
