// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coven_evidence_response.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CovenEvidenceResponseCWProxy {
  CovenEvidenceResponse data(List<EvidenceDetail> data);

  CovenEvidenceResponse meta(ResponseMeta meta);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenEvidenceResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenEvidenceResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenEvidenceResponse call({List<EvidenceDetail> data, ResponseMeta meta});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCovenEvidenceResponse.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCovenEvidenceResponse.copyWith.fieldName(...)`
class _$CovenEvidenceResponseCWProxyImpl
    implements _$CovenEvidenceResponseCWProxy {
  const _$CovenEvidenceResponseCWProxyImpl(this._value);

  final CovenEvidenceResponse _value;

  @override
  CovenEvidenceResponse data(List<EvidenceDetail> data) => this(data: data);

  @override
  CovenEvidenceResponse meta(ResponseMeta meta) => this(meta: meta);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenEvidenceResponse(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenEvidenceResponse(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenEvidenceResponse call({
    Object? data = const $CopyWithPlaceholder(),
    Object? meta = const $CopyWithPlaceholder(),
  }) {
    return CovenEvidenceResponse(
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

extension $CovenEvidenceResponseCopyWith on CovenEvidenceResponse {
  /// Returns a callable class that can be used as follows: `instanceOfCovenEvidenceResponse.copyWith(...)` or like so:`instanceOfCovenEvidenceResponse.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CovenEvidenceResponseCWProxy get copyWith =>
      _$CovenEvidenceResponseCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CovenEvidenceResponse _$CovenEvidenceResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CovenEvidenceResponse', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['data', 'meta']);
  final val = CovenEvidenceResponse(
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

Map<String, dynamic> _$CovenEvidenceResponseToJson(
  CovenEvidenceResponse instance,
) => <String, dynamic>{
  'data': instance.data.map((e) => e.toJson()).toList(),
  'meta': instance.meta.toJson(),
};
