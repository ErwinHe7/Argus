//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'register_notification_device_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RegisterNotificationDeviceRequest {
  /// Returns a new [RegisterNotificationDeviceRequest] instance.
  RegisterNotificationDeviceRequest({
    required this.platform,

    required this.pushToken,
  });

  @JsonKey(
    name: r'platform',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        RegisterNotificationDeviceRequestPlatformEnum.unknownDefaultOpenApi,
  )
  final RegisterNotificationDeviceRequestPlatformEnum platform;

  @JsonKey(name: r'push_token', required: true, includeIfNull: false)
  final String pushToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisterNotificationDeviceRequest &&
          other.platform == platform &&
          other.pushToken == pushToken;

  @override
  int get hashCode => platform.hashCode + pushToken.hashCode;

  factory RegisterNotificationDeviceRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$RegisterNotificationDeviceRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RegisterNotificationDeviceRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RegisterNotificationDeviceRequestPlatformEnum {
  @JsonValue(r'ios')
  ios(r'ios'),
  @JsonValue(r'android')
  android(r'android'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RegisterNotificationDeviceRequestPlatformEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
