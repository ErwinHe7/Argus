// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_admin_coven_qualification201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$VerifyAdminCovenQualification201ResponseCWProxy {
  VerifyAdminCovenQualification201Response data(AdminCovenVerification data);

  VerifyAdminCovenQualification201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `VerifyAdminCovenQualification201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// VerifyAdminCovenQualification201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  VerifyAdminCovenQualification201Response call({
    AdminCovenVerification data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfVerifyAdminCovenQualification201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfVerifyAdminCovenQualification201Response.copyWith.fieldName(...)`
class _$VerifyAdminCovenQualification201ResponseCWProxyImpl
    implements _$VerifyAdminCovenQualification201ResponseCWProxy {
  const _$VerifyAdminCovenQualification201ResponseCWProxyImpl(this._value);

  final VerifyAdminCovenQualification201Response _value;

  @override
  VerifyAdminCovenQualification201Response data(AdminCovenVerification data) =>
      this(data: data);

  @override
  VerifyAdminCovenQualification201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `VerifyAdminCovenQualification201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// VerifyAdminCovenQualification201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  VerifyAdminCovenQualification201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return VerifyAdminCovenQualification201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminCovenVerification,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $VerifyAdminCovenQualification201ResponseCopyWith
    on VerifyAdminCovenQualification201Response {
  /// Returns a callable class that can be used as follows: `instanceOfVerifyAdminCovenQualification201Response.copyWith(...)` or like so:`instanceOfVerifyAdminCovenQualification201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$VerifyAdminCovenQualification201ResponseCWProxy get copyWith =>
      _$VerifyAdminCovenQualification201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerifyAdminCovenQualification201Response
_$VerifyAdminCovenQualification201ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('VerifyAdminCovenQualification201Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = VerifyAdminCovenQualification201Response(
        data: $checkedConvert(
          'data',
          (v) => AdminCovenVerification.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$VerifyAdminCovenQualification201ResponseToJson(
  VerifyAdminCovenQualification201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
