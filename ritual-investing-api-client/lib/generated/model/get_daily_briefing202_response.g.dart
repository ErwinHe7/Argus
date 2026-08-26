// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_daily_briefing202_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetDailyBriefing202ResponseCWProxy {
  GetDailyBriefing202Response data(GetDailyBriefing202ResponseData data);

  GetDailyBriefing202Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetDailyBriefing202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetDailyBriefing202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetDailyBriefing202Response call({
    GetDailyBriefing202ResponseData data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetDailyBriefing202Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetDailyBriefing202Response.copyWith.fieldName(...)`
class _$GetDailyBriefing202ResponseCWProxyImpl
    implements _$GetDailyBriefing202ResponseCWProxy {
  const _$GetDailyBriefing202ResponseCWProxyImpl(this._value);

  final GetDailyBriefing202Response _value;

  @override
  GetDailyBriefing202Response data(GetDailyBriefing202ResponseData data) =>
      this(data: data);

  @override
  GetDailyBriefing202Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetDailyBriefing202Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetDailyBriefing202Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetDailyBriefing202Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetDailyBriefing202Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as GetDailyBriefing202ResponseData,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetDailyBriefing202ResponseCopyWith on GetDailyBriefing202Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetDailyBriefing202Response.copyWith(...)` or like so:`instanceOfGetDailyBriefing202Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetDailyBriefing202ResponseCWProxy get copyWith =>
      _$GetDailyBriefing202ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetDailyBriefing202Response _$GetDailyBriefing202ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetDailyBriefing202Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetDailyBriefing202Response(
    data: $checkedConvert(
      'data',
      (v) =>
          GetDailyBriefing202ResponseData.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetDailyBriefing202ResponseToJson(
  GetDailyBriefing202Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
