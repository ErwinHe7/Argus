// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_template_detail_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleTemplateDetailResponseCWProxy {
  CircleTemplateDetailResponse data(CircleTemplateDetail data);

  CircleTemplateDetailResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateDetailResponse call({
    CircleTemplateDetail data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleTemplateDetailResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleTemplateDetailResponse.copyWith.fieldName(...)`
class _$CircleTemplateDetailResponseCWProxyImpl
    implements _$CircleTemplateDetailResponseCWProxy {
  const _$CircleTemplateDetailResponseCWProxyImpl(this._value);

  final CircleTemplateDetailResponse _value;

  @override
  CircleTemplateDetailResponse data(CircleTemplateDetail data) =>
      this(data: data);

  @override
  CircleTemplateDetailResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateDetailResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateDetailResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateDetailResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CircleTemplateDetailResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as CircleTemplateDetail,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $CircleTemplateDetailResponseCopyWith
    on CircleTemplateDetailResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCircleTemplateDetailResponse.copyWith(...)` or like so:`instanceOfCircleTemplateDetailResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleTemplateDetailResponseCWProxy get copyWith =>
      _$CircleTemplateDetailResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleTemplateDetailResponse _$CircleTemplateDetailResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CircleTemplateDetailResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CircleTemplateDetailResponse(
    data: $checkedConvert(
      'data',
      (v) => CircleTemplateDetail.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CircleTemplateDetailResponseToJson(
  CircleTemplateDetailResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
