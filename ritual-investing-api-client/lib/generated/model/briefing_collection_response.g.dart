// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BriefingCollectionResponseCWProxy {
  BriefingCollectionResponse data(List<BriefingSummary> data);

  BriefingCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingCollectionResponse call({
    List<BriefingSummary> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBriefingCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBriefingCollectionResponse.copyWith.fieldName(...)`
class _$BriefingCollectionResponseCWProxyImpl
    implements _$BriefingCollectionResponseCWProxy {
  const _$BriefingCollectionResponseCWProxyImpl(this._value);

  final BriefingCollectionResponse _value;

  @override
  BriefingCollectionResponse data(List<BriefingSummary> data) =>
      this(data: data);

  @override
  BriefingCollectionResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BriefingCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<BriefingSummary>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $BriefingCollectionResponseCopyWith on BriefingCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBriefingCollectionResponse.copyWith(...)` or like so:`instanceOfBriefingCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BriefingCollectionResponseCWProxy get copyWith =>
      _$BriefingCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BriefingCollectionResponse _$BriefingCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BriefingCollectionResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BriefingCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => BriefingSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BriefingCollectionResponseToJson(
  BriefingCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
