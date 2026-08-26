// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_account_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberAccountResponseCWProxy {
  MemberAccountResponse data(MemberAccountView data);

  MemberAccountResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberAccountResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberAccountResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberAccountResponse call({MemberAccountView data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberAccountResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberAccountResponse.copyWith.fieldName(...)`
class _$MemberAccountResponseCWProxyImpl
    implements _$MemberAccountResponseCWProxy {
  const _$MemberAccountResponseCWProxyImpl(this._value);

  final MemberAccountResponse _value;

  @override
  MemberAccountResponse data(MemberAccountView data) => this(data: data);

  @override
  MemberAccountResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberAccountResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberAccountResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberAccountResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return MemberAccountResponse(
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

extension $MemberAccountResponseCopyWith on MemberAccountResponse {
  /// Returns a callable class that can be used as follows: `instanceOfMemberAccountResponse.copyWith(...)` or like so:`instanceOfMemberAccountResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberAccountResponseCWProxy get copyWith =>
      _$MemberAccountResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberAccountResponse _$MemberAccountResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemberAccountResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = MemberAccountResponse(
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

Map<String, dynamic> _$MemberAccountResponseToJson(
  MemberAccountResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
