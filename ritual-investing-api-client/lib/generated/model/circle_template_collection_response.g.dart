// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_template_collection_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleTemplateCollectionResponseCWProxy {
  CircleTemplateCollectionResponse data(List<CircleTemplateSummary> data);

  CircleTemplateCollectionResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateCollectionResponse call({
    List<CircleTemplateSummary> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleTemplateCollectionResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleTemplateCollectionResponse.copyWith.fieldName(...)`
class _$CircleTemplateCollectionResponseCWProxyImpl
    implements _$CircleTemplateCollectionResponseCWProxy {
  const _$CircleTemplateCollectionResponseCWProxyImpl(this._value);

  final CircleTemplateCollectionResponse _value;

  @override
  CircleTemplateCollectionResponse data(List<CircleTemplateSummary> data) =>
      this(data: data);

  @override
  CircleTemplateCollectionResponse meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateCollectionResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateCollectionResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateCollectionResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CircleTemplateCollectionResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<CircleTemplateSummary>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $CircleTemplateCollectionResponseCopyWith
    on CircleTemplateCollectionResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCircleTemplateCollectionResponse.copyWith(...)` or like so:`instanceOfCircleTemplateCollectionResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleTemplateCollectionResponseCWProxy get copyWith =>
      _$CircleTemplateCollectionResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleTemplateCollectionResponse _$CircleTemplateCollectionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CircleTemplateCollectionResponse', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CircleTemplateCollectionResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => CircleTemplateSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CircleTemplateCollectionResponseToJson(
  CircleTemplateCollectionResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
