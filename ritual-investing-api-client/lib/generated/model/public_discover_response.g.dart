// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_discover_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicDiscoverResponseCWProxy {
  PublicDiscoverResponse data(List<PublicDiscoverItem> data);

  PublicDiscoverResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverResponse call({
    List<PublicDiscoverItem> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicDiscoverResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicDiscoverResponse.copyWith.fieldName(...)`
class _$PublicDiscoverResponseCWProxyImpl
    implements _$PublicDiscoverResponseCWProxy {
  const _$PublicDiscoverResponseCWProxyImpl(this._value);

  final PublicDiscoverResponse _value;

  @override
  PublicDiscoverResponse data(List<PublicDiscoverItem> data) =>
      this(data: data);

  @override
  PublicDiscoverResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PublicDiscoverResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<PublicDiscoverItem>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $PublicDiscoverResponseCopyWith on PublicDiscoverResponse {
  /// Returns a callable class that can be used as follows: `instanceOfPublicDiscoverResponse.copyWith(...)` or like so:`instanceOfPublicDiscoverResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicDiscoverResponseCWProxy get copyWith =>
      _$PublicDiscoverResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicDiscoverResponse _$PublicDiscoverResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PublicDiscoverResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PublicDiscoverResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => PublicDiscoverItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PublicDiscoverResponseToJson(
  PublicDiscoverResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
