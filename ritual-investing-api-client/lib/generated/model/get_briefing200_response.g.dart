// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_briefing200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetBriefing200ResponseCWProxy {
  GetBriefing200Response data(GetBriefing200ResponseData data);

  GetBriefing200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetBriefing200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetBriefing200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetBriefing200Response call({
    GetBriefing200ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetBriefing200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetBriefing200Response.copyWith.fieldName(...)`
class _$GetBriefing200ResponseCWProxyImpl
    implements _$GetBriefing200ResponseCWProxy {
  const _$GetBriefing200ResponseCWProxyImpl(this._value);

  final GetBriefing200Response _value;

  @override
  GetBriefing200Response data(GetBriefing200ResponseData data) =>
      this(data: data);

  @override
  GetBriefing200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetBriefing200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetBriefing200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetBriefing200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetBriefing200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as GetBriefing200ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetBriefing200ResponseCopyWith on GetBriefing200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetBriefing200Response.copyWith(...)` or like so:`instanceOfGetBriefing200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetBriefing200ResponseCWProxy get copyWith =>
      _$GetBriefing200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetBriefing200Response _$GetBriefing200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetBriefing200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetBriefing200Response(
    data: $checkedConvert(
      'data',
      (v) => GetBriefing200ResponseData.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetBriefing200ResponseToJson(
  GetBriefing200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
