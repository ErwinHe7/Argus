// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ritual_evidence_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RitualEvidenceResponseCWProxy {
  RitualEvidenceResponse data(List<EvidenceDetail> data);

  RitualEvidenceResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RitualEvidenceResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RitualEvidenceResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  RitualEvidenceResponse call({List<EvidenceDetail> data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRitualEvidenceResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRitualEvidenceResponse.copyWith.fieldName(...)`
class _$RitualEvidenceResponseCWProxyImpl
    implements _$RitualEvidenceResponseCWProxy {
  const _$RitualEvidenceResponseCWProxyImpl(this._value);

  final RitualEvidenceResponse _value;

  @override
  RitualEvidenceResponse data(List<EvidenceDetail> data) => this(data: data);

  @override
  RitualEvidenceResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RitualEvidenceResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RitualEvidenceResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  RitualEvidenceResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return RitualEvidenceResponse(
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<EvidenceDetail>,
      meta: meta == const $CopyWithPlaceholder()
          ? _value.meta
          // ignore: cast_nullable_to_non_nullable
          : meta as ResponseMeta,
    );
  }
}

extension $RitualEvidenceResponseCopyWith on RitualEvidenceResponse {
  /// Returns a callable class that can be used as follows: `instanceOfRitualEvidenceResponse.copyWith(...)` or like so:`instanceOfRitualEvidenceResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RitualEvidenceResponseCWProxy get copyWith =>
      _$RitualEvidenceResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RitualEvidenceResponse _$RitualEvidenceResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('RitualEvidenceResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = RitualEvidenceResponse(
    data: $checkedConvert(
      'data',
      (v) => (v as List<dynamic>)
          .map((e) => EvidenceDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    meta: $checkedConvert(
      'meta',
      (v) => ResponseMeta.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$RitualEvidenceResponseToJson(
  RitualEvidenceResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
