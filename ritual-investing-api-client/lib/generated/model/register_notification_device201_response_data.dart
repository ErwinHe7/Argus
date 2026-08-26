//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'register_notification_device201_response_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RegisterNotificationDevice201ResponseData {
  /// Returns a new [RegisterNotificationDevice201ResponseData] instance.
  RegisterNotificationDevice201ResponseData({
    required this.id,

    required this.platform,

    required this.status,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'platform',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RegisterNotificationDevice201ResponseDataPlatformEnum
        .unknownDefaultOpenApi,
  )
  final RegisterNotificationDevice201ResponseDataPlatformEnum platform;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RegisterNotificationDevice201ResponseDataStatusEnum
        .unknownDefaultOpenApi,
  )
  final RegisterNotificationDevice201ResponseDataStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisterNotificationDevice201ResponseData &&
          other.id == id &&
          other.platform == platform &&
          other.status == status;

  @override
  int get hashCode => id.hashCode + platform.hashCode + status.hashCode;

  factory RegisterNotificationDevice201ResponseData.fromJson(
    Map<String, dynamic> json,
  ) => _$RegisterNotificationDevice201ResponseDataFromJson(json);

  Map<String, dynamic> toJson() =>
      _$RegisterNotificationDevice201ResponseDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RegisterNotificationDevice201ResponseDataPlatformEnum {
  @JsonValue(r'ios')
  ios(r'ios'),
  @JsonValue(r'android')
  android(r'android'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RegisterNotificationDevice201ResponseDataPlatformEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum RegisterNotificationDevice201ResponseDataStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'revoked')
  revoked(r'revoked'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RegisterNotificationDevice201ResponseDataStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
