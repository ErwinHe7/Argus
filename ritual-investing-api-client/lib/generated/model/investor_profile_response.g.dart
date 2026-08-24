// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'investor_profile_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InvestorProfileResponseCWProxy {
  InvestorProfileResponse data(InvestorProfile data);

  InvestorProfileResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InvestorProfileResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InvestorProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  InvestorProfileResponse call({InvestorProfile data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfInvestorProfileResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfInvestorProfileResponse.copyWith.fieldName(...)`
class _$InvestorProfileResponseCWProxyImpl
    implements _$InvestorProfileResponseCWProxy {
  const _$InvestorProfileResponseCWProxyImpl(this._value);

  final InvestorProfileResponse _value;

  @override
  InvestorProfileResponse data(InvestorProfile data) => this(data: data);

  @override
  InvestorProfileResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InvestorProfileResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InvestorProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  InvestorProfileResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return InvestorProfileResponse(
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

extension $InvestorProfileResponseCopyWith on InvestorProfileResponse {
  /// Returns a callable class that can be used as follows: `instanceOfInvestorProfileResponse.copyWith(...)` or like so:`instanceOfInvestorProfileResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$InvestorProfileResponseCWProxy get copyWith =>
      _$InvestorProfileResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvestorProfileResponse _$InvestorProfileResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('InvestorProfileResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = InvestorProfileResponse(
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

Map<String, dynamic> _$InvestorProfileResponseToJson(
  InvestorProfileResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
