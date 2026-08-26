// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'creator_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreatorCollectionResponseCWProxy {
  CreatorCollectionResponse data(List<SeededCreator> data);

  CreatorCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatorCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatorCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatorCollectionResponse call({
    List<SeededCreator> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreatorCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreatorCollectionResponse.copyWith.fieldName(...)`
class _$CreatorCollectionResponseCWProxyImpl
    implements _$CreatorCollectionResponseCWProxy {
  const _$CreatorCollectionResponseCWProxyImpl(this._value);

  final CreatorCollectionResponse _value;

  @override
  CreatorCollectionResponse data(List<SeededCreator> data) => this(data: data);

  @override
  CreatorCollectionResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatorCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatorCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatorCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreatorCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<SeededCreator>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $CreatorCollectionResponseCopyWith on CreatorCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCreatorCollectionResponse.copyWith(...)` or like so:`instanceOfCreatorCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreatorCollectionResponseCWProxy get copyWith =>
      _$CreatorCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatorCollectionResponse _$CreatorCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreatorCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreatorCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => SeededCreator.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreatorCollectionResponseToJson(
  CreatorCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
