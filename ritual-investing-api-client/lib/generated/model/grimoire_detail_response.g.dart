// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grimoire_detail_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GrimoireDetailResponseCWProxy {
  GrimoireDetailResponse data(GrimoireDetail data);

  GrimoireDetailResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GrimoireDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GrimoireDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  GrimoireDetailResponse call({
    GrimoireDetail data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGrimoireDetailResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGrimoireDetailResponse.copyWith.fieldName(...)`
class _$GrimoireDetailResponseCWProxyImpl
    implements _$GrimoireDetailResponseCWProxy {
  const _$GrimoireDetailResponseCWProxyImpl(this._value);

  final GrimoireDetailResponse _value;

  @override
  GrimoireDetailResponse data(GrimoireDetail data) => this(data: data);

  @override
  GrimoireDetailResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GrimoireDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GrimoireDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  GrimoireDetailResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GrimoireDetailResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as GrimoireDetail,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $GrimoireDetailResponseCopyWith on GrimoireDetailResponse {
  /// Returns a callable class that can be used as follows: `instanceOfGrimoireDetailResponse.copyWith(...)` or like so:`instanceOfGrimoireDetailResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GrimoireDetailResponseCWProxy get copyWith =>
      _$GrimoireDetailResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GrimoireDetailResponse _$GrimoireDetailResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GrimoireDetailResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GrimoireDetailResponse(
    data: $checkedConvert(
      'data',
      (v) => GrimoireDetail.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GrimoireDetailResponseToJson(
  GrimoireDetailResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
