// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_notification_device201_response_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RegisterNotificationDevice201ResponseDataCWProxy {
  RegisterNotificationDevice201ResponseData id(String id);

  RegisterNotificationDevice201ResponseData platform(
    RegisterNotificationDevice201ResponseDataPlatformEnum platform,
  );

  RegisterNotificationDevice201ResponseData status(
    RegisterNotificationDevice201ResponseDataStatusEnum status,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RegisterNotificationDevice201ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RegisterNotificationDevice201ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RegisterNotificationDevice201ResponseData call({
    String id,
    RegisterNotificationDevice201ResponseDataPlatformEnum platform,
    RegisterNotificationDevice201ResponseDataStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRegisterNotificationDevice201ResponseData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRegisterNotificationDevice201ResponseData.copyWith.fieldName(...)`
class _$RegisterNotificationDevice201ResponseDataCWProxyImpl
    implements _$RegisterNotificationDevice201ResponseDataCWProxy {
  const _$RegisterNotificationDevice201ResponseDataCWProxyImpl(this._value);

  final RegisterNotificationDevice201ResponseData _value;

  @override
  RegisterNotificationDevice201ResponseData id(String id) => this(id: id);

  @override
  RegisterNotificationDevice201ResponseData platform(
    RegisterNotificationDevice201ResponseDataPlatformEnum platform,
  ) => this(platform: platform);

  @override
  RegisterNotificationDevice201ResponseData status(
    RegisterNotificationDevice201ResponseDataStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RegisterNotificationDevice201ResponseData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RegisterNotificationDevice201ResponseData(...).copyWith(id: 12, name: "My name")
  /// ````
  RegisterNotificationDevice201ResponseData call({
    Object? id = const $CopyWithPlaceholder(),
    Object? platform = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return RegisterNotificationDevice201ResponseData(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      platform: platform == const $CopyWithPlaceholder()
          ? _value.platform
          // ignore: cast_nullable_to_non_nullable
          : platform as RegisterNotificationDevice201ResponseDataPlatformEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as RegisterNotificationDevice201ResponseDataStatusEnum,
    );
  }
}

extension $RegisterNotificationDevice201ResponseDataCopyWith
    on RegisterNotificationDevice201ResponseData {
  /// Returns a callable class that can be used as follows: `instanceOfRegisterNotificationDevice201ResponseData.copyWith(...)` or like so:`instanceOfRegisterNotificationDevice201ResponseData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RegisterNotificationDevice201ResponseDataCWProxy get copyWith =>
      _$RegisterNotificationDevice201ResponseDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterNotificationDevice201ResponseData
_$RegisterNotificationDevice201ResponseDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RegisterNotificationDevice201ResponseData', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['id', 'platform', 'status']);
  final val = RegisterNotificationDevice201ResponseData(
    id: $checkedConvert('id', (v) => v as String),
    platform: $checkedConvert(
      'platform',
      (v) => $enumDecode(
        _$RegisterNotificationDevice201ResponseDataPlatformEnumEnumMap,
        v,
        unknownValue: RegisterNotificationDevice201ResponseDataPlatformEnum
            .unknownDefaultOpenApi,
      ),
    ),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$RegisterNotificationDevice201ResponseDataStatusEnumEnumMap,
        v,
        unknownValue: RegisterNotificationDevice201ResponseDataStatusEnum
            .unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$RegisterNotificationDevice201ResponseDataToJson(
  RegisterNotificationDevice201ResponseData instance,
) => <String, dynamic>{
  'id': instance.id,
  'platform':
      _$RegisterNotificationDevice201ResponseDataPlatformEnumEnumMap[instance
          .platform]!,
  'status':
      _$RegisterNotificationDevice201ResponseDataStatusEnumEnumMap[instance
          .status]!,
};

const _$RegisterNotificationDevice201ResponseDataPlatformEnumEnumMap = {
  RegisterNotificationDevice201ResponseDataPlatformEnum.ios: 'ios',
  RegisterNotificationDevice201ResponseDataPlatformEnum.android: 'android',
  RegisterNotificationDevice201ResponseDataPlatformEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$RegisterNotificationDevice201ResponseDataStatusEnumEnumMap = {
  RegisterNotificationDevice201ResponseDataStatusEnum.active: 'active',
  RegisterNotificationDevice201ResponseDataStatusEnum.revoked: 'revoked',
  RegisterNotificationDevice201ResponseDataStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
