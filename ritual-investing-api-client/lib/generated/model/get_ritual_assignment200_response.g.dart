// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_ritual_assignment200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GetRitualAssignment200ResponseCWProxy {
  GetRitualAssignment200Response data(DailyRitualDetail data);

  GetRitualAssignment200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetRitualAssignment200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetRitualAssignment200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetRitualAssignment200Response call({
    DailyRitualDetail data,
    ResponseMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGetRitualAssignment200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGetRitualAssignment200Response.copyWith.fieldName(...)`
class _$GetRitualAssignment200ResponseCWProxyImpl
    implements _$GetRitualAssignment200ResponseCWProxy {
  const _$GetRitualAssignment200ResponseCWProxyImpl(this._value);

  final GetRitualAssignment200Response _value;

  @override
  GetRitualAssignment200Response data(DailyRitualDetail data) =>
      this(data: data);

  @override
  GetRitualAssignment200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GetRitualAssignment200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GetRitualAssignment200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  GetRitualAssignment200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return GetRitualAssignment200Response(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as DailyRitualDetail,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $GetRitualAssignment200ResponseCopyWith
    on GetRitualAssignment200Response {
  /// Returns a callable class that can be used as follows: `instanceOfGetRitualAssignment200Response.copyWith(...)` or like so:`instanceOfGetRitualAssignment200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GetRitualAssignment200ResponseCWProxy get copyWith =>
      _$GetRitualAssignment200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetRitualAssignment200Response _$GetRitualAssignment200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GetRitualAssignment200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = GetRitualAssignment200Response(
    data: $checkedConvert(
      'data',
      (v) => DailyRitualDetail.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$GetRitualAssignment200ResponseToJson(
  GetRitualAssignment200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
