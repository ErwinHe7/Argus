// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_portfolio201_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreatePortfolio201ResponseCWProxy {
  CreatePortfolio201Response data(PortfolioView data);

  CreatePortfolio201Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatePortfolio201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatePortfolio201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatePortfolio201Response call({PortfolioView data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreatePortfolio201Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreatePortfolio201Response.copyWith.fieldName(...)`
class _$CreatePortfolio201ResponseCWProxyImpl
    implements _$CreatePortfolio201ResponseCWProxy {
  const _$CreatePortfolio201ResponseCWProxyImpl(this._value);

  final CreatePortfolio201Response _value;

  @override
  CreatePortfolio201Response data(PortfolioView data) => this(data: data);

  @override
  CreatePortfolio201Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreatePortfolio201Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreatePortfolio201Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CreatePortfolio201Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CreatePortfolio201Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as PortfolioView,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CreatePortfolio201ResponseCopyWith on CreatePortfolio201Response {
  /// Returns a callable class that can be used as follows: `instanceOfCreatePortfolio201Response.copyWith(...)` or like so:`instanceOfCreatePortfolio201Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreatePortfolio201ResponseCWProxy get copyWith =>
      _$CreatePortfolio201ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePortfolio201Response _$CreatePortfolio201ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreatePortfolio201Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CreatePortfolio201Response(
    data: $checkedConvert(
      'data',
      (v) => PortfolioView.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreatePortfolio201ResponseToJson(
  CreatePortfolio201Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
