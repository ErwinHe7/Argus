// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleCollectionResponseCWProxy {
  CircleCollectionResponse data(List<CircleView> data);

  CircleCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleCollectionResponse call({List<CircleView> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleCollectionResponse.copyWith.fieldName(...)`
class _$CircleCollectionResponseCWProxyImpl
    implements _$CircleCollectionResponseCWProxy {
  const _$CircleCollectionResponseCWProxyImpl(this._value);

  final CircleCollectionResponse _value;

  @override
  CircleCollectionResponse data(List<CircleView> data) => this(data: data);

  @override
  CircleCollectionResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CircleCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<CircleView>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $CircleCollectionResponseCopyWith on CircleCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCircleCollectionResponse.copyWith(...)` or like so:`instanceOfCircleCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleCollectionResponseCWProxy get copyWith =>
      _$CircleCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleCollectionResponse _$CircleCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CircleCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CircleCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => CircleView.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CircleCollectionResponseToJson(
  CircleCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
