//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_preferences.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NotificationPreferences {
  /// Returns a new [NotificationPreferences] instance.
  NotificationPreferences({
    required this.dailyRitual,

    required this.deletionEpoch,

    required this.moonCycle,

    required this.quietHours,

    required this.userId,

    required this.version,

    required this.weeklyRecap,
  });

  @JsonKey(name: r'daily_ritual', required: true, includeIfNull: false)
  final bool dailyRitual;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'moon_cycle', required: true, includeIfNull: false)
  final bool moonCycle;

  @JsonKey(name: r'quiet_hours', required: true, includeIfNull: false)
  final Map<String, Object?> quietHours;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @JsonKey(name: r'weekly_recap', required: true, includeIfNull: false)
  final bool weeklyRecap;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          other.dailyRitual == dailyRitual &&
          other.deletionEpoch == deletionEpoch &&
          other.moonCycle == moonCycle &&
          other.quietHours == quietHours &&
          other.userId == userId &&
          other.version == version &&
          other.weeklyRecap == weeklyRecap;

  @override
  int get hashCode =>
      dailyRitual.hashCode +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      moonCycle.hashCode +
      quietHours.hashCode +
      userId.hashCode +
      version.hashCode +
      weeklyRecap.hashCode;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationPreferencesToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
