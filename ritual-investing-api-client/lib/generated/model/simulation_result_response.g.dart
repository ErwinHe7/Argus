// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simulation_result_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SimulationResultResponseCWProxy {
  SimulationResultResponse data(SimulationResult data);

  SimulationResultResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulationResultResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulationResultResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulationResultResponse call({SimulationResult data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSimulationResultResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSimulationResultResponse.copyWith.fieldName(...)`
class _$SimulationResultResponseCWProxyImpl
    implements _$SimulationResultResponseCWProxy {
  const _$SimulationResultResponseCWProxyImpl(this._value);

  final SimulationResultResponse _value;

  @override
  SimulationResultResponse data(SimulationResult data) => this(data: data);

  @override
  SimulationResultResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulationResultResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulationResultResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulationResultResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return SimulationResultResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as SimulationResult,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $SimulationResultResponseCopyWith on SimulationResultResponse {
  /// Returns a callable class that can be used as follows: `instanceOfSimulationResultResponse.copyWith(...)` or like so:`instanceOfSimulationResultResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SimulationResultResponseCWProxy get copyWith =>
      _$SimulationResultResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimulationResultResponse _$SimulationResultResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SimulationResultResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = SimulationResultResponse(
    data: $checkedConvert(
      'data',
      (v) => SimulationResult.fromJson(v as Map<String, dynamic>),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$SimulationResultResponseToJson(
  SimulationResultResponse instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
