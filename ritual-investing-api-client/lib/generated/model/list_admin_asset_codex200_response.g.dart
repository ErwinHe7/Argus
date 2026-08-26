// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseCWProxy {
  ListAdminAssetCodex200Response data(
    List<ListAdminAssetCodex200ResponseDataInner> data,
  );

  ListAdminAssetCodex200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200Response call({
    List<ListAdminAssetCodex200ResponseDataInner> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200Response.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseCWProxyImpl
    implements _$ListAdminAssetCodex200ResponseCWProxy {
  const _$ListAdminAssetCodex200ResponseCWProxyImpl(this._value);

  final ListAdminAssetCodex200Response _value;

  @override
  ListAdminAssetCodex200Response data(
    List<ListAdminAssetCodex200ResponseDataInner> data,
  ) => this(data: data);

  @override
  ListAdminAssetCodex200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<ListAdminAssetCodex200ResponseDataInner>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminAssetCodex200ResponseCopyWith
    on ListAdminAssetCodex200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200Response.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseCWProxy get copyWith =>
      _$ListAdminAssetCodex200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200Response _$ListAdminAssetCodex200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminAssetCodex200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListAdminAssetCodex200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map(
            (e) => ListAdminAssetCodex200ResponseDataInner.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListAdminAssetCodex200ResponseToJson(
  ListAdminAssetCodex200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
