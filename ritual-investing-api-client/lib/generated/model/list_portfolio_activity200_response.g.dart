// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_portfolio_activity200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListPortfolioActivity200ResponseCWProxy {
  ListPortfolioActivity200Response data(List<PortfolioActivity> data);

  ListPortfolioActivity200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolioActivity200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolioActivity200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolioActivity200Response call({
    List<PortfolioActivity> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListPortfolioActivity200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListPortfolioActivity200Response.copyWith.fieldName(...)`
class _$ListPortfolioActivity200ResponseCWProxyImpl
    implements _$ListPortfolioActivity200ResponseCWProxy {
  const _$ListPortfolioActivity200ResponseCWProxyImpl(this._value);

  final ListPortfolioActivity200Response _value;

  @override
  ListPortfolioActivity200Response data(List<PortfolioActivity> data) =>
      this(data: data);

  @override
  ListPortfolioActivity200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolioActivity200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolioActivity200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolioActivity200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListPortfolioActivity200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<PortfolioActivity>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListPortfolioActivity200ResponseCopyWith
    on ListPortfolioActivity200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListPortfolioActivity200Response.copyWith(...)` or like so:`instanceOfListPortfolioActivity200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListPortfolioActivity200ResponseCWProxy get copyWith =>
      _$ListPortfolioActivity200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListPortfolioActivity200Response _$ListPortfolioActivity200ResponseFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('ListPortfolioActivity200Response', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = ListPortfolioActivity200Response(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map((e) => PortfolioActivity.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ListPortfolioActivity200ResponseToJson(
  ListPortfolioActivity200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
