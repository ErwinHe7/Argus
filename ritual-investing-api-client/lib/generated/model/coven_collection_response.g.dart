// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coven_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CovenCollectionResponseCWProxy {
  CovenCollectionResponse data(List<CovenSummary> data);

  CovenCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenCollectionResponse call({List<CovenSummary> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCovenCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCovenCollectionResponse.copyWith.fieldName(...)`
class _$CovenCollectionResponseCWProxyImpl
    implements _$CovenCollectionResponseCWProxy {
  const _$CovenCollectionResponseCWProxyImpl(this._value);

  final CovenCollectionResponse _value;

  @override
  CovenCollectionResponse data(List<CovenSummary> data) => this(data: data);

  @override
  CovenCollectionResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CovenCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<CovenSummary>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $CovenCollectionResponseCopyWith on CovenCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCovenCollectionResponse.copyWith(...)` or like so:`instanceOfCovenCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CovenCollectionResponseCWProxy get copyWith =>
      _$CovenCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CovenCollectionResponse _$CovenCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CovenCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CovenCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => CovenSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CovenCollectionResponseToJson(
  CovenCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
