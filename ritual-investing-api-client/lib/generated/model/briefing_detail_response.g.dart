// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing_detail_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BriefingDetailResponseCWProxy {
  BriefingDetailResponse data(BriefingDetail data);

  BriefingDetailResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingDetailResponse call({
    BriefingDetail data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBriefingDetailResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBriefingDetailResponse.copyWith.fieldName(...)`
class _$BriefingDetailResponseCWProxyImpl
    implements _$BriefingDetailResponseCWProxy {
  const _$BriefingDetailResponseCWProxyImpl(this._value);

  final BriefingDetailResponse _value;

  @override
  BriefingDetailResponse data(BriefingDetail data) => this(data: data);

  @override
  BriefingDetailResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingDetailResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BriefingDetailResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BriefingDetail,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BriefingDetailResponseCopyWith on BriefingDetailResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBriefingDetailResponse.copyWith(...)` or like so:`instanceOfBriefingDetailResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BriefingDetailResponseCWProxy get copyWith =>
      _$BriefingDetailResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BriefingDetailResponse _$BriefingDetailResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BriefingDetailResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BriefingDetailResponse(
    data: $checkedConvert(
      'data',
      (v) => BriefingDetail.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BriefingDetailResponseToJson(
  BriefingDetailResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
