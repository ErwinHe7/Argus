// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_astrology_profile_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeleteAstrologyProfileResponseCWProxy {
  DeleteAstrologyProfileResponse data(DeleteAstrologyProfileResponseData data);

  DeleteAstrologyProfileResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeleteAstrologyProfileResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeleteAstrologyProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  DeleteAstrologyProfileResponse call({
    DeleteAstrologyProfileResponseData data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDeleteAstrologyProfileResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDeleteAstrologyProfileResponse.copyWith.fieldName(...)`
class _$DeleteAstrologyProfileResponseCWProxyImpl
    implements _$DeleteAstrologyProfileResponseCWProxy {
  const _$DeleteAstrologyProfileResponseCWProxyImpl(this._value);

  final DeleteAstrologyProfileResponse _value;

  @override
  DeleteAstrologyProfileResponse data(
    DeleteAstrologyProfileResponseData data,
  ) => this(data: data);

  @override
  DeleteAstrologyProfileResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeleteAstrologyProfileResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeleteAstrologyProfileResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  DeleteAstrologyProfileResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return DeleteAstrologyProfileResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as DeleteAstrologyProfileResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $DeleteAstrologyProfileResponseCopyWith
    on DeleteAstrologyProfileResponse {
  /// Returns a callable class that can be used as follows: `instanceOfDeleteAstrologyProfileResponse.copyWith(...)` or like so:`instanceOfDeleteAstrologyProfileResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeleteAstrologyProfileResponseCWProxy get copyWith =>
      _$DeleteAstrologyProfileResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteAstrologyProfileResponse _$DeleteAstrologyProfileResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DeleteAstrologyProfileResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = DeleteAstrologyProfileResponse(
    data: $checkedConvert(
      'data',
      (v) => DeleteAstrologyProfileResponseData.fromJson(
        v as Map<String, dynamic>,
      ),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$DeleteAstrologyProfileResponseToJson(
  DeleteAstrologyProfileResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
