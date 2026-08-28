//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/notification_preferences.dart';
import 'package:ritual_investing_api_client/generated/model/list_admin_audit200_response_meta.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_preferences_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NotificationPreferencesResponse {
  /// Returns a new [NotificationPreferencesResponse] instance.
  NotificationPreferencesResponse({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final NotificationPreferences data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ListAdminAudit200ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferencesResponse &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory NotificationPreferencesResponse.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$NotificationPreferencesResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
