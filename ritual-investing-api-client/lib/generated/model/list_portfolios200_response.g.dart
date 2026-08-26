// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_portfolios200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListPortfolios200ResponseCWProxy {
  ListPortfolios200Response data(List<PortfolioView> data);

  ListPortfolios200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolios200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolios200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolios200Response call({
    List<PortfolioView> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListPortfolios200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListPortfolios200Response.copyWith.fieldName(...)`
class _$ListPortfolios200ResponseCWProxyImpl
    implements _$ListPortfolios200ResponseCWProxy {
  const _$ListPortfolios200ResponseCWProxyImpl(this._value);

  final ListPortfolios200Response _value;

  @override
  ListPortfolios200Response data(List<PortfolioView> data) => this(data: data);

  @override
  ListPortfolios200Response meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolios200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolios200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolios200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListPortfolios200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<PortfolioView>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListPortfolios200ResponseCopyWith on ListPortfolios200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListPortfolios200Response.copyWith(...)` or like so:`instanceOfListPortfolios200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListPortfolios200ResponseCWProxy get copyWith =>
      _$ListPortfolios200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListPortfolios200Response _$ListPortfolios200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ListPortfolios200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = ListPortfolios200Response(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => PortfolioView.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$ListPortfolios200ResponseToJson(
  ListPortfolios200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
