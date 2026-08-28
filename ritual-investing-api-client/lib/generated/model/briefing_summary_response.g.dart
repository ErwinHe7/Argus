// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing_summary_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BriefingSummaryResponseCWProxy {
  BriefingSummaryResponse data(BriefingSummary data);

  BriefingSummaryResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingSummaryResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingSummaryResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingSummaryResponse call({
    BriefingSummary data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBriefingSummaryResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBriefingSummaryResponse.copyWith.fieldName(...)`
class _$BriefingSummaryResponseCWProxyImpl
    implements _$BriefingSummaryResponseCWProxy {
  const _$BriefingSummaryResponseCWProxyImpl(this._value);

  final BriefingSummaryResponse _value;

  @override
  BriefingSummaryResponse data(BriefingSummary data) => this(data: data);

  @override
  BriefingSummaryResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingSummaryResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingSummaryResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingSummaryResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BriefingSummaryResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BriefingSummary,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BriefingSummaryResponseCopyWith on BriefingSummaryResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBriefingSummaryResponse.copyWith(...)` or like so:`instanceOfBriefingSummaryResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BriefingSummaryResponseCWProxy get copyWith =>
      _$BriefingSummaryResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BriefingSummaryResponse _$BriefingSummaryResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BriefingSummaryResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BriefingSummaryResponse(
    data: $checkedConvert(
      'data',
      (v) => BriefingSummary.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BriefingSummaryResponseToJson(
  BriefingSummaryResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
