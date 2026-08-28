// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'briefing_pending_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BriefingPendingResponseCWProxy {
  BriefingPendingResponse data(BriefingPending data);

  BriefingPendingResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingPendingResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingPendingResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingPendingResponse call({
    BriefingPending data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBriefingPendingResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBriefingPendingResponse.copyWith.fieldName(...)`
class _$BriefingPendingResponseCWProxyImpl
    implements _$BriefingPendingResponseCWProxy {
  const _$BriefingPendingResponseCWProxyImpl(this._value);

  final BriefingPendingResponse _value;

  @override
  BriefingPendingResponse data(BriefingPending data) => this(data: data);

  @override
  BriefingPendingResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BriefingPendingResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BriefingPendingResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  BriefingPendingResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return BriefingPendingResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BriefingPending,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $BriefingPendingResponseCopyWith on BriefingPendingResponse {
  /// Returns a callable class that can be used as follows: `instanceOfBriefingPendingResponse.copyWith(...)` or like so:`instanceOfBriefingPendingResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BriefingPendingResponseCWProxy get copyWith =>
      _$BriefingPendingResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BriefingPendingResponse _$BriefingPendingResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BriefingPendingResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = BriefingPendingResponse(
    data: $checkedConvert(
      'data',
      (v) => BriefingPending.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$BriefingPendingResponseToJson(
  BriefingPendingResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
