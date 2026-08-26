// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'put_investor_profile200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PutInvestorProfile200ResponseCWProxy {
  PutInvestorProfile200Response data(InvestorProfile data);

  PutInvestorProfile200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutInvestorProfile200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutInvestorProfile200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  PutInvestorProfile200Response call({InvestorProfile data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPutInvestorProfile200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPutInvestorProfile200Response.copyWith.fieldName(...)`
class _$PutInvestorProfile200ResponseCWProxyImpl
    implements _$PutInvestorProfile200ResponseCWProxy {
  const _$PutInvestorProfile200ResponseCWProxyImpl(this._value);

  final PutInvestorProfile200Response _value;

  @override
  PutInvestorProfile200Response data(InvestorProfile data) => this(data: data);

  @override
  PutInvestorProfile200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PutInvestorProfile200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PutInvestorProfile200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  PutInvestorProfile200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PutInvestorProfile200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as InvestorProfile,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $PutInvestorProfile200ResponseCopyWith
    on PutInvestorProfile200Response {
  /// Returns a callable class that can be used as follows: `instanceOfPutInvestorProfile200Response.copyWith(...)` or like so:`instanceOfPutInvestorProfile200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PutInvestorProfile200ResponseCWProxy get copyWith =>
      _$PutInvestorProfile200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PutInvestorProfile200Response _$PutInvestorProfile200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PutInvestorProfile200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PutInvestorProfile200Response(
    data: $checkedConvert(
      'data',
      (v) => InvestorProfile.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PutInvestorProfile200ResponseToJson(
  PutInvestorProfile200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
