// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_portfolio_holdings200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListPortfolioHoldings200ResponseCWProxy {
  ListPortfolioHoldings200Response data(
    List<ListPortfolioHoldings200ResponseDataInner> data,
  );

  ListPortfolioHoldings200Response meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolioHoldings200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolioHoldings200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolioHoldings200Response call({
    List<ListPortfolioHoldings200ResponseDataInner> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListPortfolioHoldings200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListPortfolioHoldings200Response.copyWith.fieldName(...)`
class _$ListPortfolioHoldings200ResponseCWProxyImpl
    implements _$ListPortfolioHoldings200ResponseCWProxy {
  const _$ListPortfolioHoldings200ResponseCWProxyImpl(this._value);

  final ListPortfolioHoldings200Response _value;

  @override
  ListPortfolioHoldings200Response data(
    List<ListPortfolioHoldings200ResponseDataInner> data,
  ) => this(data: data);

  @override
  ListPortfolioHoldings200Response meta(CollectionMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolioHoldings200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolioHoldings200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolioHoldings200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return ListPortfolioHoldings200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<ListPortfolioHoldings200ResponseDataInner>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $ListPortfolioHoldings200ResponseCopyWith
    on ListPortfolioHoldings200Response {
  /// Returns a callable class that can be used as follows: `instanceOfListPortfolioHoldings200Response.copyWith(...)` or like so:`instanceOfListPortfolioHoldings200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListPortfolioHoldings200ResponseCWProxy get copyWith =>
      _$ListPortfolioHoldings200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListPortfolioHoldings200Response _$ListPortfolioHoldings200ResponseFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('ListPortfolioHoldings200Response', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = ListPortfolioHoldings200Response(
        data: $checkedConvert(
          'data',
          (v) => (v as List<dynamic>)
              .map(
                (e) => ListPortfolioHoldings200ResponseDataInner.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
        ),
        meta: $checkedConvert(
          'meta',
          (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ListPortfolioHoldings200ResponseToJson(
  ListPortfolioHoldings200Response instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
