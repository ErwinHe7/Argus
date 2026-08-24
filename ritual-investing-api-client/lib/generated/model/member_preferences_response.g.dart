// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_preferences_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberPreferencesResponseCWProxy {
  MemberPreferencesResponse data(MemberPreferences data);

  MemberPreferencesResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberPreferencesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberPreferencesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberPreferencesResponse call({MemberPreferences data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberPreferencesResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberPreferencesResponse.copyWith.fieldName(...)`
class _$MemberPreferencesResponseCWProxyImpl
    implements _$MemberPreferencesResponseCWProxy {
  const _$MemberPreferencesResponseCWProxyImpl(this._value);

  final MemberPreferencesResponse _value;

  @override
  MemberPreferencesResponse data(MemberPreferences data) => this(data: data);

  @override
  MemberPreferencesResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberPreferencesResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberPreferencesResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberPreferencesResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return MemberPreferencesResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberPreferences,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $MemberPreferencesResponseCopyWith on MemberPreferencesResponse {
  /// Returns a callable class that can be used as follows: `instanceOfMemberPreferencesResponse.copyWith(...)` or like so:`instanceOfMemberPreferencesResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberPreferencesResponseCWProxy get copyWith =>
      _$MemberPreferencesResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberPreferencesResponse _$MemberPreferencesResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberPreferencesResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = MemberPreferencesResponse(
    data: $checkedConvert(
      'data',
      (v) => MemberPreferences.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$MemberPreferencesResponseToJson(
  MemberPreferencesResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
