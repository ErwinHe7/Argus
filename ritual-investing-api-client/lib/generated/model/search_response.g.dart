// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SearchResponseCWProxy {
  SearchResponse data(List<SearchResult> data);

  SearchResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SearchResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SearchResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  SearchResponse call({List<SearchResult> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSearchResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSearchResponse.copyWith.fieldName(...)`
class _$SearchResponseCWProxyImpl implements _$SearchResponseCWProxy {
  const _$SearchResponseCWProxyImpl(this._value);

  final SearchResponse _value;

  @override
  SearchResponse data(List<SearchResult> data) => this(data: data);

  @override
  SearchResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SearchResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SearchResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  SearchResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return SearchResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<SearchResult>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $SearchResponseCopyWith on SearchResponse {
  /// Returns a callable class that can be used as follows: `instanceOfSearchResponse.copyWith(...)` or like so:`instanceOfSearchResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SearchResponseCWProxy get copyWith => _$SearchResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchResponse _$SearchResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SearchResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = SearchResponse(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SearchResponseToJson(SearchResponse instance) =>
    <String, dynamic>{
      'data': instance.data.map((e) => e.toJson()).toList(),
      'meta': instance.meta.toJson(),
    };
