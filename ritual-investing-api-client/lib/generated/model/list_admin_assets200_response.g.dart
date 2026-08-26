// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_assets200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssets200ResponseCWProxy {
  ListAdminAssets200Response data(List<AdminAsset> data);

  ListAdminAssets200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssets200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssets200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssets200Response call({List<AdminAsset> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssets200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssets200Response.copyWith.fieldName(...)`
class _$ListAdminAssets200ResponseCWProxyImpl
    implements _$ListAdminAssets200ResponseCWProxy {
  const _$ListAdminAssets200ResponseCWProxyImpl(this._value);

  final ListAdminAssets200Response _value;

  @override
  ListAdminAssets200Response data(List<AdminAsset> data) => this(data: data);

  @override
  ListAdminAssets200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssets200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssets200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssets200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssets200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AdminAsset>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminAssets200ResponseCopyWith on ListAdminAssets200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssets200Response.copyWith(...)` or like so:`instanceOfListAdminAssets200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssets200ResponseCWProxy get copyWith =>
      _$ListAdminAssets200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssets200Response _$ListAdminAssets200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminAssets200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListAdminAssets200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => AdminAsset.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListAdminAssets200ResponseToJson(
  ListAdminAssets200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
