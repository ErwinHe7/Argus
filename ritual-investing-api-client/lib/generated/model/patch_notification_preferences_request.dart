//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/get_notification_preferences200_response_data_quiet_hours.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_notification_preferences_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchNotificationPreferencesRequest {
  /// Returns a new [PatchNotificationPreferencesRequest] instance.
  PatchNotificationPreferencesRequest({
    this.dailyRitual,

    this.moonCycle,

    this.quietHours,

    this.weeklyRecap,
  });

  @JsonKey(name: r'daily_ritual', required: false, includeIfNull: false)
  final bool? dailyRitual;

  @JsonKey(name: r'moon_cycle', required: false, includeIfNull: false)
  final bool? moonCycle;

  @JsonKey(name: r'quiet_hours', required: false, includeIfNull: false)
  final GetNotificationPreferences200ResponseDataQuietHours? quietHours;

  @JsonKey(name: r'weekly_recap', required: false, includeIfNull: false)
  final bool? weeklyRecap;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchNotificationPreferencesRequest &&
          other.dailyRitual == dailyRitual &&
          other.moonCycle == moonCycle &&
          other.quietHours == quietHours &&
          other.weeklyRecap == weeklyRecap;

  @override
  int get hashCode =>
      dailyRitual.hashCode +
      moonCycle.hashCode +
      quietHours.hashCode +
      weeklyRecap.hashCode;

  factory PatchNotificationPreferencesRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$PatchNotificationPreferencesRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchNotificationPreferencesRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
