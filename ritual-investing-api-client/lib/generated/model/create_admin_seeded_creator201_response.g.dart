// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_seeded_creator201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminSeededCreator201ResponseCWProxy {
  CreateAdminSeededCreator201Response data(AdminSeededCreator data);

  CreateAdminSeededCreator201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminSeededCreator201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminSeededCreator201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminSeededCreator201Response call({
    AdminSeededCreator data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminSeededCreator201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminSeededCreator201Response.copyWith.fieldName(...)`
class _$CreateAdminSeededCreator201ResponseCWProxyImpl
    implements _$CreateAdminSeededCreator201ResponseCWProxy {
  const _$CreateAdminSeededCreator201ResponseCWProxyImpl(this._value);

  final CreateAdminSeededCreator201Response _value;

  @override
  CreateAdminSeededCreator201Response data(AdminSeededCreator data) =>
      this(data: data);

  @override
  CreateAdminSeededCreator201Response meta(ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminSeededCreator201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminSeededCreator201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminSeededCreator201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminSeededCreator201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminSeededCreator,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateAdminSeededCreator201ResponseCopyWith
    on CreateAdminSeededCreator201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminSeededCreator201Response.copyWith(...)` or like so:`instanceOfCreateAdminSeededCreator201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminSeededCreator201ResponseCWProxy get copyWith =>
      _$CreateAdminSeededCreator201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminSeededCreator201Response
_$CreateAdminSeededCreator201ResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateAdminSeededCreator201Response', json, (
      $checkedConvert,
    ) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CreateAdminSeededCreator201Response(
        data: $checkedConvert(
          'data',
          (v) => AdminSeededCreator.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CreateAdminSeededCreator201ResponseToJson(
  CreateAdminSeededCreator201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
