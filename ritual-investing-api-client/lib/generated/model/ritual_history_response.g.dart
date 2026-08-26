// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ritual_history_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RitualHistoryResponseCWProxy {
  RitualHistoryResponse data(List<RitualHistoryItem> data);

  RitualHistoryResponse meta(CollectionMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RitualHistoryResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RitualHistoryResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  RitualHistoryResponse call({
    List<RitualHistoryItem> data,
    CollectionMeta meta,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRitualHistoryResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRitualHistoryResponse.copyWith.fieldName(...)`
class _$RitualHistoryResponseCWProxyImpl
    implements _$RitualHistoryResponseCWProxy {
  const _$RitualHistoryResponseCWProxyImpl(this._value);

  final RitualHistoryResponse _value;

  @override
  RitualHistoryResponse data(List<RitualHistoryItem> data) => this(data: data);

  @override
  RitualHistoryResponse meta(CollectionMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RitualHistoryResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RitualHistoryResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  RitualHistoryResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return RitualHistoryResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<RitualHistoryItem>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as CollectionMeta,
    );
  }
}

extension $RitualHistoryResponseCopyWith on RitualHistoryResponse {
  /// Returns a callable class that can be used as follows: `instanceOfRitualHistoryResponse.copyWith(...)` or like so:`instanceOfRitualHistoryResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RitualHistoryResponseCWProxy get copyWith =>
      _$RitualHistoryResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RitualHistoryResponse _$RitualHistoryResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RitualHistoryResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = RitualHistoryResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => RitualHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => CollectionMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$RitualHistoryResponseToJson(
  RitualHistoryResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
