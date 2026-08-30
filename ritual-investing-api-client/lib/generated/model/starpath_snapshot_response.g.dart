// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_snapshot_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathSnapshotResponseCWProxy {
  StarpathSnapshotResponse data(StarpathSnapshot data);

  StarpathSnapshotResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathSnapshotResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathSnapshotResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathSnapshotResponse call({
    StarpathSnapshot data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathSnapshotResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathSnapshotResponse.copyWith.fieldName(...)`
class _$StarpathSnapshotResponseCWProxyImpl
    implements _$StarpathSnapshotResponseCWProxy {
  const _$StarpathSnapshotResponseCWProxyImpl(this._value);

  final StarpathSnapshotResponse _value;

  @override
  StarpathSnapshotResponse data(StarpathSnapshot data) => this(data: data);

  @override
  StarpathSnapshotResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathSnapshotResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathSnapshotResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathSnapshotResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return StarpathSnapshotResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as StarpathSnapshot,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $StarpathSnapshotResponseCopyWith on StarpathSnapshotResponse {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathSnapshotResponse.copyWith(...)` or like so:`instanceOfStarpathSnapshotResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathSnapshotResponseCWProxy get copyWith =>
      _$StarpathSnapshotResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathSnapshotResponse _$StarpathSnapshotResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('StarpathSnapshotResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = StarpathSnapshotResponse(
    data: $checkedConvert(
      'data',
      (v) => StarpathSnapshot.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$StarpathSnapshotResponseToJson(
  StarpathSnapshotResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
