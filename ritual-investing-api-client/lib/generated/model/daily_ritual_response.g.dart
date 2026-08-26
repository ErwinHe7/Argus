// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_ritual_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DailyRitualResponseCWProxy {
  DailyRitualResponse data(DailyRitualDetail data);

  DailyRitualResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DailyRitualResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DailyRitualResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  DailyRitualResponse call({DailyRitualDetail data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDailyRitualResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDailyRitualResponse.copyWith.fieldName(...)`
class _$DailyRitualResponseCWProxyImpl implements _$DailyRitualResponseCWProxy {
  const _$DailyRitualResponseCWProxyImpl(this._value);

  final DailyRitualResponse _value;

  @override
  DailyRitualResponse data(DailyRitualDetail data) => this(data: data);

  @override
  DailyRitualResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DailyRitualResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DailyRitualResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  DailyRitualResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return DailyRitualResponse(
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

extension $DailyRitualResponseCopyWith on DailyRitualResponse {
  /// Returns a callable class that can be used as follows: `instanceOfDailyRitualResponse.copyWith(...)` or like so:`instanceOfDailyRitualResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DailyRitualResponseCWProxy get copyWith =>
      _$DailyRitualResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyRitualResponse _$DailyRitualResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DailyRitualResponse', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['data', 'meta']);
      final val = DailyRitualResponse(
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

Map<String, dynamic> _$DailyRitualResponseToJson(
  DailyRitualResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
