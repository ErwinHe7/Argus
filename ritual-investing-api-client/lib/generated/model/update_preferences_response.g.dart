// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_preferences_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UpdatePreferencesResponseCWProxy {
  UpdatePreferencesResponse data(MemberPreferences? data);

  UpdatePreferencesResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdatePreferencesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdatePreferencesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdatePreferencesResponse call({
    MemberPreferences? data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUpdatePreferencesResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUpdatePreferencesResponse.copyWith.fieldName(...)`
class _$UpdatePreferencesResponseCWProxyImpl
    implements _$UpdatePreferencesResponseCWProxy {
  const _$UpdatePreferencesResponseCWProxyImpl(this._value);

  final UpdatePreferencesResponse _value;

  @override
  UpdatePreferencesResponse data(MemberPreferences? data) => this(data: data);

  @override
  UpdatePreferencesResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdatePreferencesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdatePreferencesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdatePreferencesResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return UpdatePreferencesResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberPreferences?,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $UpdatePreferencesResponseCopyWith on UpdatePreferencesResponse {
  /// Returns a callable class that can be used as follows: `instanceOfUpdatePreferencesResponse.copyWith(...)` or like so:`instanceOfUpdatePreferencesResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UpdatePreferencesResponseCWProxy get copyWith =>
      _$UpdatePreferencesResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePreferencesResponse _$UpdatePreferencesResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('UpdatePreferencesResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = UpdatePreferencesResponse(
    data: $checkedConvert(
      'data',
      (v) => v == null
          ? null
          : MemberPreferences.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$UpdatePreferencesResponseToJson(
  UpdatePreferencesResponse instance,
) => <String, dynamic>{
  'data': instance.data?.toJson(),
  'meta': instance.meta.toJson(),
};
