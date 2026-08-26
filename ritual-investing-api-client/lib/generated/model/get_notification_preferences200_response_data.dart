//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/get_notification_preferences200_response_data_quiet_hours.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'get_notification_preferences200_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GetNotificationPreferences200ResponseData {
  /// Returns a new [GetNotificationPreferences200ResponseData] instance.
  GetNotificationPreferences200ResponseData({
    required this.dailyRitual,

    required this.moonCycle,

    required this.quietHours,

    required this.version,

    required this.weeklyRecap,
  });

  @JsonKey(name: r'daily_ritual', required: true, includeIfNull: false)
  final bool dailyRitual;

  @JsonKey(name: r'moon_cycle', required: true, includeIfNull: false)
  final bool moonCycle;

  @JsonKey(name: r'quiet_hours', required: true, includeIfNull: false)
  final GetNotificationPreferences200ResponseDataQuietHours quietHours;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @JsonKey(name: r'weekly_recap', required: true, includeIfNull: false)
  final bool weeklyRecap;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetNotificationPreferences200ResponseData &&
          other.dailyRitual == dailyRitual &&
          other.moonCycle == moonCycle &&
          other.quietHours == quietHours &&
          other.version == version &&
          other.weeklyRecap == weeklyRecap;

  @override
  int get hashCode =>
      dailyRitual.hashCode +
      moonCycle.hashCode +
      quietHours.hashCode +
      version.hashCode +
      weeklyRecap.hashCode;

  factory GetNotificationPreferences200ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$GetNotificationPreferences200ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$GetNotificationPreferences200ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
