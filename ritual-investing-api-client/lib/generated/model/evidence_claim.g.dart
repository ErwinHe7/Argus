// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_claim.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EvidenceClaimCWProxy {
  EvidenceClaim claimType(String claimType);

  EvidenceClaim id(String id);

  EvidenceClaim observedAt(DateTime? observedAt);

  EvidenceClaim source_(EvidenceSource source_);

  EvidenceClaim summary(String summary);

  EvidenceClaim uncertainty(String uncertainty);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceClaim(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceClaim(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceClaim call({
    String claimType,
    String id,
    DateTime? observedAt,
    EvidenceSource source_,
    String summary,
    String uncertainty,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEvidenceClaim.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEvidenceClaim.copyWith.fieldName(...)`
class _$EvidenceClaimCWProxyImpl implements _$EvidenceClaimCWProxy {
  const _$EvidenceClaimCWProxyImpl(this._value);

  final EvidenceClaim _value;

  @override
  EvidenceClaim claimType(String claimType) => this(claimType: claimType);

  @override
  EvidenceClaim id(String id) => this(id: id);

  @override
  EvidenceClaim observedAt(DateTime? observedAt) =>
      this(observedAt: observedAt);

  @override
  EvidenceClaim source_(EvidenceSource source_) => this(source_: source_);

  @override
  EvidenceClaim summary(String summary) => this(summary: summary);

  @override
  EvidenceClaim uncertainty(String uncertainty) =>
      this(uncertainty: uncertainty);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceClaim(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceClaim(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceClaim call({
    Object? claimType = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
    Object? uncertainty = const $CopyWithPlaceholder(),
  }) {
    return EvidenceClaim(
      claimType: claimType == const $CopyWithPlaceholder()
          ? _value.claimType
          // ignore: cast_nullable_to_non_nullable
          : claimType as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      observedAt: observedAt == const $CopyWithPlaceholder()
          ? _value.observedAt
          // ignore: cast_nullable_to_non_nullable
          : observedAt as DateTime?,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as EvidenceSource,
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

extension $EvidenceClaimCopyWith on EvidenceClaim {
  /// Returns a callable class that can be used as follows: `instanceOfEvidenceClaim.copyWith(...)` or like so:`instanceOfEvidenceClaim.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EvidenceClaimCWProxy get copyWith => _$EvidenceClaimCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EvidenceClaim _$EvidenceClaimFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'EvidenceClaim',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'claim_type',
            'id',
            'observed_at',
            'source',
            'summary',
            'uncertainty',
          ],
        );
        final val = EvidenceClaim(
          claimType: $checkedConvert('claim_type', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          observedAt: $checkedConvert(
            'observed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          source_: $checkedConvert(
            'source',
            (v) => EvidenceSource.fromJson(v as Map<String, dynamic>),
          ),
          summary: $checkedConvert('summary', (v) => v as String),
          uncertainty: $checkedConvert('uncertainty', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'claimType': 'claim_type',
        'observedAt': 'observed_at',
        'source_': 'source',
      },
    );

Map<String, dynamic> _$EvidenceClaimToJson(EvidenceClaim instance) =>
    <String, dynamic>{
      'claim_type': instance.claimType,
      'id': instance.id,
      'observed_at': instance.observedAt?.toIso8601String(),
      'source': instance.source_.toJson(),
      'summary': instance.summary,
      'uncertainty': instance.uncertainty,
    };
