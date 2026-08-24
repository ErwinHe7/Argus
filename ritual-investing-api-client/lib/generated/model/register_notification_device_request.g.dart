// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_notification_device_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RegisterNotificationDeviceRequestCWProxy {
  RegisterNotificationDeviceRequest platform(
    RegisterNotificationDeviceRequestPlatformEnum platform,
  );

  RegisterNotificationDeviceRequest pushToken(String pushToken);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RegisterNotificationDeviceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RegisterNotificationDeviceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RegisterNotificationDeviceRequest call({
    RegisterNotificationDeviceRequestPlatformEnum platform,
    String pushToken,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRegisterNotificationDeviceRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRegisterNotificationDeviceRequest.copyWith.fieldName(...)`
class _$RegisterNotificationDeviceRequestCWProxyImpl
    implements _$RegisterNotificationDeviceRequestCWProxy {
  const _$RegisterNotificationDeviceRequestCWProxyImpl(this._value);

  final RegisterNotificationDeviceRequest _value;

  @override
  RegisterNotificationDeviceRequest platform(
    RegisterNotificationDeviceRequestPlatformEnum platform,
  ) => this(platform: platform);

  @override
  RegisterNotificationDeviceRequest pushToken(String pushToken) =>
      this(pushToken: pushToken);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RegisterNotificationDeviceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RegisterNotificationDeviceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  RegisterNotificationDeviceRequest call({
    Object? platform = const $CopyWithPlaceholder(),
    Object? pushToken = const $CopyWithPlaceholder(),
  }) {
    return RegisterNotificationDeviceRequest(
      platform: platform == const $CopyWithPlaceholder()
          ? _value.platform
          // ignore: cast_nullable_to_non_nullable
          : platform as RegisterNotificationDeviceRequestPlatformEnum,
      pushToken: pushToken == const $CopyWithPlaceholder()
          ? _value.pushToken
          // ignore: cast_nullable_to_non_nullable
          : pushToken as String,
    );
  }
}

extension $RegisterNotificationDeviceRequestCopyWith
    on RegisterNotificationDeviceRequest {
  /// Returns a callable class that can be used as follows: `instanceOfRegisterNotificationDeviceRequest.copyWith(...)` or like so:`instanceOfRegisterNotificationDeviceRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RegisterNotificationDeviceRequestCWProxy get copyWith =>
      _$RegisterNotificationDeviceRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterNotificationDeviceRequest _$RegisterNotificationDeviceRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RegisterNotificationDeviceRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['platform', 'push_token']);
  final val = RegisterNotificationDeviceRequest(
    platform: $checkedConvert(
      'platform',
      (v) => $enumDecode(
        _$RegisterNotificationDeviceRequestPlatformEnumEnumMap,
        v,
        unknownValue:
            RegisterNotificationDeviceRequestPlatformEnum.unknownDefaultOpenApi,
      ),
    ),
    pushToken: $checkedConvert('push_token', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'pushToken': 'push_token'});

Map<String, dynamic> _$RegisterNotificationDeviceRequestToJson(
  RegisterNotificationDeviceRequest instance,
) => <String, dynamic>{
  'platform':
      _$RegisterNotificationDeviceRequestPlatformEnumEnumMap[instance
          .platform]!,
  'push_token': instance.pushToken,
};

const _$RegisterNotificationDeviceRequestPlatformEnumEnumMap = {
  RegisterNotificationDeviceRequestPlatformEnum.ios: 'ios',
  RegisterNotificationDeviceRequestPlatformEnum.android: 'android',
  RegisterNotificationDeviceRequestPlatformEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
