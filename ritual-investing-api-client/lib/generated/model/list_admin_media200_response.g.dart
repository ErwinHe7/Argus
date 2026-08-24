// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_media200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminMedia200ResponseCWProxy {
  ListAdminMedia200Response data(List<ListAdminMedia200ResponseDataInner> data);

  ListAdminMedia200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminMedia200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminMedia200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminMedia200Response call({
    List<ListAdminMedia200ResponseDataInner> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminMedia200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminMedia200Response.copyWith.fieldName(...)`
class _$ListAdminMedia200ResponseCWProxyImpl
    implements _$ListAdminMedia200ResponseCWProxy {
  const _$ListAdminMedia200ResponseCWProxyImpl(this._value);

  final ListAdminMedia200Response _value;

  @override
  ListAdminMedia200Response data(
    List<ListAdminMedia200ResponseDataInner> data,
  ) => this(data: data);

  @override
  ListAdminMedia200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminMedia200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminMedia200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminMedia200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminMedia200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<ListAdminMedia200ResponseDataInner>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminMedia200ResponseCopyWith on ListAdminMedia200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminMedia200Response.copyWith(...)` or like so:`instanceOfListAdminMedia200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminMedia200ResponseCWProxy get copyWith =>
      _$ListAdminMedia200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminMedia200Response _$ListAdminMedia200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminMedia200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListAdminMedia200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map(
            (e) => ListAdminMedia200ResponseDataInner.fromJson(
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

Map<String, dynamic> _$ListAdminMedia200ResponseToJson(
  ListAdminMedia200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
