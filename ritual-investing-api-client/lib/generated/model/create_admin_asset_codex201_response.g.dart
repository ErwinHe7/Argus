// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_asset_codex201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminAssetCodex201ResponseCWProxy {
  CreateAdminAssetCodex201Response data(
    ListAdminAssetCodex200ResponseDataInner data,
  );

  CreateAdminAssetCodex201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAssetCodex201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAssetCodex201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAssetCodex201Response call({
    ListAdminAssetCodex200ResponseDataInner data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminAssetCodex201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminAssetCodex201Response.copyWith.fieldName(...)`
class _$CreateAdminAssetCodex201ResponseCWProxyImpl
    implements _$CreateAdminAssetCodex201ResponseCWProxy {
  const _$CreateAdminAssetCodex201ResponseCWProxyImpl(this._value);

  final CreateAdminAssetCodex201Response _value;

  @override
  CreateAdminAssetCodex201Response data(
    ListAdminAssetCodex200ResponseDataInner data,
  ) => this(data: data);

  @override
  CreateAdminAssetCodex201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAssetCodex201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAssetCodex201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAssetCodex201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminAssetCodex201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as ListAdminAssetCodex200ResponseDataInner,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreateAdminAssetCodex201ResponseCopyWith
    on CreateAdminAssetCodex201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminAssetCodex201Response.copyWith(...)` or like so:`instanceOfCreateAdminAssetCodex201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminAssetCodex201ResponseCWProxy get copyWith =>
      _$CreateAdminAssetCodex201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminAssetCodex201Response _$CreateAdminAssetCodex201ResponseFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('CreateAdminAssetCodex201Response', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CreateAdminAssetCodex201Response(
        data: $checkedConvert(
          'data',
          (v) => ListAdminAssetCodex200ResponseDataInner.fromJson(
            v as Map<String, dynamic>,
          ),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CreateAdminAssetCodex201ResponseToJson(
  CreateAdminAssetCodex201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
