// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_portfolio_snapshots200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListPortfolioSnapshots200ResponseCWProxy {
  ListPortfolioSnapshots200Response data(List<PortfolioSnapshot> data);

  ListPortfolioSnapshots200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolioSnapshots200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolioSnapshots200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolioSnapshots200Response call({
    List<PortfolioSnapshot> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListPortfolioSnapshots200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListPortfolioSnapshots200Response.copyWith.fieldName(...)`
class _$ListPortfolioSnapshots200ResponseCWProxyImpl
    implements _$ListPortfolioSnapshots200ResponseCWProxy {
  const _$ListPortfolioSnapshots200ResponseCWProxyImpl(this._value);

  final ListPortfolioSnapshots200Response _value;

  @override
  ListPortfolioSnapshots200Response data(List<PortfolioSnapshot> data) =>
      this(data: data);

  @override
  ListPortfolioSnapshots200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolioSnapshots200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolioSnapshots200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolioSnapshots200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListPortfolioSnapshots200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<PortfolioSnapshot>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListPortfolioSnapshots200ResponseCopyWith
    on ListPortfolioSnapshots200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListPortfolioSnapshots200Response.copyWith(...)` or like so:`instanceOfListPortfolioSnapshots200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListPortfolioSnapshots200ResponseCWProxy get copyWith =>
      _$ListPortfolioSnapshots200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListPortfolioSnapshots200Response _$ListPortfolioSnapshots200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListPortfolioSnapshots200Response', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListPortfolioSnapshots200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => PortfolioSnapshot.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListPortfolioSnapshots200ResponseToJson(
  ListPortfolioSnapshots200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
