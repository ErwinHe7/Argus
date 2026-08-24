// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_seeded_creators200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminSeededCreators200ResponseCWProxy {
  ListAdminSeededCreators200Response data(List<AdminSeededCreator> data);

  ListAdminSeededCreators200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminSeededCreators200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminSeededCreators200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminSeededCreators200Response call({
    List<AdminSeededCreator> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminSeededCreators200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminSeededCreators200Response.copyWith.fieldName(...)`
class _$ListAdminSeededCreators200ResponseCWProxyImpl
    implements _$ListAdminSeededCreators200ResponseCWProxy {
  const _$ListAdminSeededCreators200ResponseCWProxyImpl(this._value);

  final ListAdminSeededCreators200Response _value;

  @override
  ListAdminSeededCreators200Response data(List<AdminSeededCreator> data) =>
      this(data: data);

  @override
  ListAdminSeededCreators200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminSeededCreators200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminSeededCreators200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminSeededCreators200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListAdminSeededCreators200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<AdminSeededCreator>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListAdminSeededCreators200ResponseCopyWith
    on ListAdminSeededCreators200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminSeededCreators200Response.copyWith(...)` or like so:`instanceOfListAdminSeededCreators200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminSeededCreators200ResponseCWProxy get copyWith =>
      _$ListAdminSeededCreators200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminSeededCreators200Response _$ListAdminSeededCreators200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListAdminSeededCreators200Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListAdminSeededCreators200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => AdminSeededCreator.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListAdminSeededCreators200ResponseToJson(
  ListAdminSeededCreators200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
