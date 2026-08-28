// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coven_detail_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CovenDetailResponseCWProxy {
  CovenDetailResponse data(CovenEntryDetail data);

  CovenDetailResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenDetailResponse call({
    CovenEntryDetail data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCovenDetailResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCovenDetailResponse.copyWith.fieldName(...)`
class _$CovenDetailResponseCWProxyImpl implements _$CovenDetailResponseCWProxy {
  const _$CovenDetailResponseCWProxyImpl(this._value);

  final CovenDetailResponse _value;

  @override
  CovenDetailResponse data(CovenEntryDetail data) => this(data: data);

  @override
  CovenDetailResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenDetailResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CovenDetailResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as CovenEntryDetail,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $CovenDetailResponseCopyWith on CovenDetailResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCovenDetailResponse.copyWith(...)` or like so:`instanceOfCovenDetailResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CovenDetailResponseCWProxy get copyWith =>
      _$CovenDetailResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CovenDetailResponse _$CovenDetailResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CovenDetailResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = CovenDetailResponse(
        data: $checkedConvert(
          'data',
          (v) => CovenEntryDetail.fromJson(v as Map<String, dynamic>),
        ),
        meta: $checkedConvert(
          'meta',
          (v) =>
              ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CovenDetailResponseToJson(
  CovenDetailResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
