// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grimoire_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GrimoireCollectionResponseCWProxy {
  GrimoireCollectionResponse data(List<GrimoireSummary> data);

  GrimoireCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GrimoireCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GrimoireCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  GrimoireCollectionResponse call({
    List<GrimoireSummary> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGrimoireCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGrimoireCollectionResponse.copyWith.fieldName(...)`
class _$GrimoireCollectionResponseCWProxyImpl
    implements _$GrimoireCollectionResponseCWProxy {
  const _$GrimoireCollectionResponseCWProxyImpl(this._value);

  final GrimoireCollectionResponse _value;

  @override
  GrimoireCollectionResponse data(List<GrimoireSummary> data) =>
      this(data: data);

  @override
  GrimoireCollectionResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GrimoireCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GrimoireCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  GrimoireCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GrimoireCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<GrimoireSummary>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $GrimoireCollectionResponseCopyWith on GrimoireCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfGrimoireCollectionResponse.copyWith(...)` or like so:`instanceOfGrimoireCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GrimoireCollectionResponseCWProxy get copyWith =>
      _$GrimoireCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GrimoireCollectionResponse _$GrimoireCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GrimoireCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GrimoireCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => GrimoireSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GrimoireCollectionResponseToJson(
  GrimoireCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
