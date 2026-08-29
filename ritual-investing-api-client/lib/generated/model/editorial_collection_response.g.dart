// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'editorial_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EditorialCollectionResponseCWProxy {
  EditorialCollectionResponse data(List<PublishedEditorial> data);

  EditorialCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EditorialCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EditorialCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  EditorialCollectionResponse call({
    List<PublishedEditorial> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEditorialCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEditorialCollectionResponse.copyWith.fieldName(...)`
class _$EditorialCollectionResponseCWProxyImpl
    implements _$EditorialCollectionResponseCWProxy {
  const _$EditorialCollectionResponseCWProxyImpl(this._value);

  final EditorialCollectionResponse _value;

  @override
  EditorialCollectionResponse data(List<PublishedEditorial> data) =>
      this(data: data);

  @override
  EditorialCollectionResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EditorialCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EditorialCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  EditorialCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return EditorialCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<PublishedEditorial>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $EditorialCollectionResponseCopyWith on EditorialCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfEditorialCollectionResponse.copyWith(...)` or like so:`instanceOfEditorialCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EditorialCollectionResponseCWProxy get copyWith =>
      _$EditorialCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EditorialCollectionResponse _$EditorialCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('EditorialCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = EditorialCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => PublishedEditorial.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$EditorialCollectionResponseToJson(
  EditorialCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
