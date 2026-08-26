// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_daily_ritual_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicDailyRitualResponseCWProxy {
  PublicDailyRitualResponse data(DailyRitualPreview data);

  PublicDailyRitualResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDailyRitualResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDailyRitualResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDailyRitualResponse call({DailyRitualPreview data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicDailyRitualResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicDailyRitualResponse.copyWith.fieldName(...)`
class _$PublicDailyRitualResponseCWProxyImpl
    implements _$PublicDailyRitualResponseCWProxy {
  const _$PublicDailyRitualResponseCWProxyImpl(this._value);

  final PublicDailyRitualResponse _value;

  @override
  PublicDailyRitualResponse data(DailyRitualPreview data) => this(data: data);

  @override
  PublicDailyRitualResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDailyRitualResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDailyRitualResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDailyRitualResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return PublicDailyRitualResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as DailyRitualPreview,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $PublicDailyRitualResponseCopyWith on PublicDailyRitualResponse {
  /// Returns a callable class that can be used as follows: `instanceOfPublicDailyRitualResponse.copyWith(...)` or like so:`instanceOfPublicDailyRitualResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicDailyRitualResponseCWProxy get copyWith =>
      _$PublicDailyRitualResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicDailyRitualResponse _$PublicDailyRitualResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PublicDailyRitualResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = PublicDailyRitualResponse(
    data: $checkedConvert(
      'data',
      (v) => DailyRitualPreview.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$PublicDailyRitualResponseToJson(
  PublicDailyRitualResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
