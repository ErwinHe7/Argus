// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_asset201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminAsset201ResponseCWProxy {
  CreateAdminAsset201Response data(AdminAsset data);

  CreateAdminAsset201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAsset201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAsset201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAsset201Response call({AdminAsset data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminAsset201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminAsset201Response.copyWith.fieldName(...)`
class _$CreateAdminAsset201ResponseCWProxyImpl
    implements _$CreateAdminAsset201ResponseCWProxy {
  const _$CreateAdminAsset201ResponseCWProxyImpl(this._value);

  final CreateAdminAsset201Response _value;

  @override
  CreateAdminAsset201Response data(AdminAsset data) => this(data: data);

  @override
  CreateAdminAsset201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAsset201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAsset201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAsset201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminAsset201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as AdminAsset,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateAdminAsset201ResponseCopyWith on CreateAdminAsset201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminAsset201Response.copyWith(...)` or like so:`instanceOfCreateAdminAsset201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminAsset201ResponseCWProxy get copyWith =>
      _$CreateAdminAsset201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminAsset201Response _$CreateAdminAsset201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateAdminAsset201Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreateAdminAsset201Response(
    data: $checkedConvert(
      'data',
      (v) => AdminAsset.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateAdminAsset201ResponseToJson(
  CreateAdminAsset201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
