// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_detail_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleDetailResponseCWProxy {
  CircleDetailResponse data(MemberCircle data);

  CircleDetailResponse meta(ListAdminAudit200ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleDetailResponse call({
    MemberCircle data,
    ListAdminAudit200ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleDetailResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleDetailResponse.copyWith.fieldName(...)`
class _$CircleDetailResponseCWProxyImpl
    implements _$CircleDetailResponseCWProxy {
  const _$CircleDetailResponseCWProxyImpl(this._value);

  final CircleDetailResponse _value;

  @override
  CircleDetailResponse data(MemberCircle data) => this(data: data);

  @override
  CircleDetailResponse meta(ListAdminAudit200ResponseMeta meta) =>
      this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleDetailResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CircleDetailResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as MemberCircle,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ListAdminAudit200ResponseMeta,
    );
  }
}

extension $CircleDetailResponseCopyWith on CircleDetailResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCircleDetailResponse.copyWith(...)` or like so:`instanceOfCircleDetailResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleDetailResponseCWProxy get copyWith =>
      _$CircleDetailResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleDetailResponse _$CircleDetailResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CircleDetailResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CircleDetailResponse(
    data: $checkedConvert(
      'data',
      (v) => MemberCircle.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ListAdminAudit200ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CircleDetailResponseToJson(
  CircleDetailResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
