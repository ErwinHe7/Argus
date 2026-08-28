// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rowan_counsel_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RowanCounselResponseCWProxy {
  RowanCounselResponse data(RowanCounsel data);

  RowanCounselResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RowanCounselResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RowanCounselResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  RowanCounselResponse call({
    RowanCounsel data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRowanCounselResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRowanCounselResponse.copyWith.fieldName(...)`
class _$RowanCounselResponseCWProxyImpl
    implements _$RowanCounselResponseCWProxy {
  const _$RowanCounselResponseCWProxyImpl(this._value);

  final RowanCounselResponse _value;

  @override
  RowanCounselResponse data(RowanCounsel data) => this(data: data);

  @override
  RowanCounselResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RowanCounselResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RowanCounselResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  RowanCounselResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return RowanCounselResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as RowanCounsel,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $RowanCounselResponseCopyWith on RowanCounselResponse {
  /// Returns a callable class that can be used as follows: `instanceOfRowanCounselResponse.copyWith(...)` or like so:`instanceOfRowanCounselResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RowanCounselResponseCWProxy get copyWith =>
      _$RowanCounselResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RowanCounselResponse _$RowanCounselResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RowanCounselResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = RowanCounselResponse(
    data: $checkedConvert(
      'data',
      (v) => RowanCounsel.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$RowanCounselResponseToJson(
  RowanCounselResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
