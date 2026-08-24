//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_notification_preferences200_response_data_quiet_hours.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetNotificationPreferences200ResponseDataQuietHours {
  /// Returns a new [GetNotificationPreferences200ResponseDataQuietHours] instance.
  GetNotificationPreferences200ResponseDataQuietHours({
    required this.enabled,

    required this.end,

    required this.start,

    required this.timezone,
  });

  @JsonKey(name: r'enabled', required: true, includeIfNull: false)
  final bool enabled;

  @JsonKey(name: r'end', required: true, includeIfNull: false)
  final String end;

  @JsonKey(name: r'start', required: true, includeIfNull: false)
  final String start;

  @JsonKey(name: r'timezone', required: true, includeIfNull: false)
  final String timezone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetNotificationPreferences200ResponseDataQuietHours &&
          other.enabled == enabled &&
          other.end == end &&
          other.start == start &&
          other.timezone == timezone;

  @override
  int get hashCode =>
      enabled.hashCode + end.hashCode + start.hashCode + timezone.hashCode;

  factory GetNotificationPreferences200ResponseDataQuietHours.fromJson(
    Map<String, dynamic> json,
  ) => _$GetNotificationPreferences200ResponseDataQuietHoursFromJson(json);

  Map<String, dynamic> toJson() =>
      _$GetNotificationPreferences200ResponseDataQuietHoursToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
