// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_order200_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CommitOrder200ResponseCWProxy {
  CommitOrder200Response data(SimulationResult data);

  CommitOrder200Response meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CommitOrder200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CommitOrder200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CommitOrder200Response call({SimulationResult data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCommitOrder200Response.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCommitOrder200Response.copyWith.fieldName(...)`
class _$CommitOrder200ResponseCWProxyImpl
    implements _$CommitOrder200ResponseCWProxy {
  const _$CommitOrder200ResponseCWProxyImpl(this._value);

  final CommitOrder200Response _value;

  @override
  CommitOrder200Response data(SimulationResult data) => this(data: data);

  @override
  CommitOrder200Response meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CommitOrder200Response(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CommitOrder200Response(...).copyWith(id: 12, name: "My name")
  /// ````
  CommitOrder200Response call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CommitOrder200Response(
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

extension $CommitOrder200ResponseCopyWith on CommitOrder200Response {
  /// Returns a callable class that can be used as follows: `instanceOfCommitOrder200Response.copyWith(...)` or like so:`instanceOfCommitOrder200Response.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CommitOrder200ResponseCWProxy get copyWith =>
      _$CommitOrder200ResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommitOrder200Response _$CommitOrder200ResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CommitOrder200Response', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CommitOrder200Response(
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

Map<String, dynamic> _$CommitOrder200ResponseToJson(
  CommitOrder200Response instance,
) => <String, dynamic>{
  'data': instance.data.toJson(),
  'meta': instance.meta.toJson(),
};
