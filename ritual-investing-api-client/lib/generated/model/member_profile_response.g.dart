// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_profile_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberProfileResponseCWProxy {
  MemberProfileResponse data(MemberAccountView data);

  MemberProfileResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberProfileResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberProfileResponse call({MemberAccountView data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberProfileResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberProfileResponse.copyWith.fieldName(...)`
class _$MemberProfileResponseCWProxyImpl
    implements _$MemberProfileResponseCWProxy {
  const _$MemberProfileResponseCWProxyImpl(this._value);

  final MemberProfileResponse _value;

  @override
  MemberProfileResponse data(MemberAccountView data) => this(data: data);

  @override
  MemberProfileResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberProfileResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberProfileResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return MemberProfileResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberAccountView,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $MemberProfileResponseCopyWith on MemberProfileResponse {
  /// Returns a callable class that can be used as follows: `instanceOfMemberProfileResponse.copyWith(...)` or like so:`instanceOfMemberProfileResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberProfileResponseCWProxy get copyWith =>
      _$MemberProfileResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberProfileResponse _$MemberProfileResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberProfileResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = MemberProfileResponse(
    data: $checkedConvert(
      'data',
      (v) => MemberAccountView.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$MemberProfileResponseToJson(
  MemberProfileResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
