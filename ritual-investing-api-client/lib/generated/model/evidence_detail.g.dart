// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_detail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EvidenceDetailCWProxy {
  EvidenceDetail claimId(String claimId);

  EvidenceDetail factorLabel(String factorLabel);

  EvidenceDetail observedAt(DateTime observedAt);

  EvidenceDetail source_(EvidenceDetailSource source_);

  EvidenceDetail summary(String summary);

  EvidenceDetail uncertainty(String uncertainty);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceDetail call({
    String claimId,
    String factorLabel,
    DateTime observedAt,
    EvidenceDetailSource source_,
    String summary,
    String uncertainty,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEvidenceDetail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEvidenceDetail.copyWith.fieldName(...)`
class _$EvidenceDetailCWProxyImpl implements _$EvidenceDetailCWProxy {
  const _$EvidenceDetailCWProxyImpl(this._value);

  final EvidenceDetail _value;

  @override
  EvidenceDetail claimId(String claimId) => this(claimId: claimId);

  @override
  EvidenceDetail factorLabel(String factorLabel) =>
      this(factorLabel: factorLabel);

  @override
  EvidenceDetail observedAt(DateTime observedAt) =>
      this(observedAt: observedAt);

  @override
  EvidenceDetail source_(EvidenceDetailSource source_) =>
      this(source_: source_);

  @override
  EvidenceDetail summary(String summary) => this(summary: summary);

  @override
  EvidenceDetail uncertainty(String uncertainty) =>
      this(uncertainty: uncertainty);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceDetail call({
    Object? claimId = const $CopyWithPlaceholder(),
    Object? factorLabel = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
    Object? uncertainty = const $CopyWithPlaceholder(),
  }) {
    return EvidenceDetail(
      claimId: claimId == const $CopyWithPlaceholder()
          ? _value.claimId
          // ignore: cast_nullable_to_non_nullable
          : claimId as String,
      factorLabel: factorLabel == const $CopyWithPlaceholder()
          ? _value.factorLabel
          // ignore: cast_nullable_to_non_nullable
          : factorLabel as String,
      observedAt: observedAt == const $CopyWithPlaceholder()
          ? _value.observedAt
          // ignore: cast_nullable_to_non_nullable
          : observedAt as DateTime,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as EvidenceDetailSource,
      summary: summary == const $CopyWithPlaceholder()
          ? _value.summary
          // ignore: cast_nullable_to_non_nullable
          : summary as String,
      uncertainty: uncertainty == const $CopyWithPlaceholder()
          ? _value.uncertainty
          // ignore: cast_nullable_to_non_nullable
          : uncertainty as String,
    );
  }
}

extension $EvidenceDetailCopyWith on EvidenceDetail {
  /// Returns a callable class that can be used as follows: `instanceOfEvidenceDetail.copyWith(...)` or like so:`instanceOfEvidenceDetail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EvidenceDetailCWProxy get copyWith => _$EvidenceDetailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EvidenceDetail _$EvidenceDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'EvidenceDetail',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'claim_id',
            'factor_label',
            'observed_at',
            'source',
            'summary',
            'uncertainty',
          ],
        );
        final val = EvidenceDetail(
          claimId: $checkedConvert('claim_id', (v) => v as String),
          factorLabel: $checkedConvert('factor_label', (v) => v as String),
          observedAt: $checkedConvert(
            'observed_at',
            (v) => DateTime.parse(v as String),
          ),
          source_: $checkedConvert(
            'source',
            (v) => EvidenceDetailSource.fromJson(v as Map<String, dynamic>),
          ),
          summary: $checkedConvert('summary', (v) => v as String),
          uncertainty: $checkedConvert('uncertainty', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'claimId': 'claim_id',
        'factorLabel': 'factor_label',
        'observedAt': 'observed_at',
        'source_': 'source',
      },
    );

Map<String, dynamic> _$EvidenceDetailToJson(EvidenceDetail instance) =>
    <String, dynamic>{
      'claim_id': instance.claimId,
      'factor_label': instance.factorLabel,
      'observed_at': instance.observedAt.toIso8601String(),
      'source': instance.source_.toJson(),
      'summary': instance.summary,
      'uncertainty': instance.uncertainty,
    };
