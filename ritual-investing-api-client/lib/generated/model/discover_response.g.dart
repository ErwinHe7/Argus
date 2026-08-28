// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiscoverResponseCWProxy {
  DiscoverResponse data(List<DiscoverItem> data);

  DiscoverResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverResponse call({List<DiscoverItem> data, CollectionMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDiscoverResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDiscoverResponse.copyWith.fieldName(...)`
class _$DiscoverResponseCWProxyImpl implements _$DiscoverResponseCWProxy {
  const _$DiscoverResponseCWProxyImpl(this._value);

  final DiscoverResponse _value;

  @override
  DiscoverResponse data(List<DiscoverItem> data) => this(data: data);

  @override
  DiscoverResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return DiscoverResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<DiscoverItem>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $DiscoverResponseCopyWith on DiscoverResponse {
  /// Returns a callable class that can be used as follows: `instanceOfDiscoverResponse.copyWith(...)` or like so:`instanceOfDiscoverResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiscoverResponseCWProxy get copyWith => _$DiscoverResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiscoverResponse _$DiscoverResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiscoverResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = DiscoverResponse(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map((e) => DiscoverItem.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DiscoverResponseToJson(DiscoverResponse instance) =>
    <String, dynamic>{
      'data': instance.data.map((e) => e.toJson()).toList(),
      'meta': instance.meta.toJson(),
    };
