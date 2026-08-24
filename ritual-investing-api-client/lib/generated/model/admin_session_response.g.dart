// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_session_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminSessionResponseCWProxy {
  AdminSessionResponse data(AdminSession data);

  AdminSessionResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminSessionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminSessionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminSessionResponse call({AdminSession data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminSessionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminSessionResponse.copyWith.fieldName(...)`
class _$AdminSessionResponseCWProxyImpl
    implements _$AdminSessionResponseCWProxy {
  const _$AdminSessionResponseCWProxyImpl(this._value);

  final AdminSessionResponse _value;

  @override
  AdminSessionResponse data(AdminSession data) => this(data: data);

  @override
  AdminSessionResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminSessionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminSessionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminSessionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return AdminSessionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminSession,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $AdminSessionResponseCopyWith on AdminSessionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfAdminSessionResponse.copyWith(...)` or like so:`instanceOfAdminSessionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminSessionResponseCWProxy get copyWith =>
      _$AdminSessionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminSessionResponse _$AdminSessionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AdminSessionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = AdminSessionResponse(
    data: $checkedConvert(
      'data',
      (v) => AdminSession.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$AdminSessionResponseToJson(
  AdminSessionResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
