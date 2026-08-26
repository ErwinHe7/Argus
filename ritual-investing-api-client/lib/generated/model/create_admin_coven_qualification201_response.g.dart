// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_coven_qualification201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminCovenQualification201ResponseCWProxy {
  CreateAdminCovenQualification201Response data(AdminCovenQualification data);

  CreateAdminCovenQualification201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminCovenQualification201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminCovenQualification201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminCovenQualification201Response call({
    AdminCovenQualification data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminCovenQualification201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminCovenQualification201Response.copyWith.fieldName(...)`
class _$CreateAdminCovenQualification201ResponseCWProxyImpl
    implements _$CreateAdminCovenQualification201ResponseCWProxy {
  const _$CreateAdminCovenQualification201ResponseCWProxyImpl(this._value);

  final CreateAdminCovenQualification201Response _value;

  @override
  CreateAdminCovenQualification201Response data(AdminCovenQualification data) =>
      this(data: data);

  @override
  CreateAdminCovenQualification201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminCovenQualification201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminCovenQualification201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminCovenQualification201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminCovenQualification201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminCovenQualification,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateAdminCovenQualification201ResponseCopyWith
    on CreateAdminCovenQualification201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminCovenQualification201Response.copyWith(...)` or like so:`instanceOfCreateAdminCovenQualification201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminCovenQualification201ResponseCWProxy get copyWith =>
      _$CreateAdminCovenQualification201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminCovenQualification201Response
_$CreateAdminCovenQualification201ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateAdminCovenQualification201Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CreateAdminCovenQualification201Response(
        data: $checkedConvert(
          'data',
          (v) => AdminCovenQualification.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CreateAdminCovenQualification201ResponseToJson(
  CreateAdminCovenQualification201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
