// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EvidenceSummaryCWProxy {
  EvidenceSummary claimId(String claimId);

  EvidenceSummary factorLabel(String factorLabel);

  EvidenceSummary observedAt(DateTime observedAt);

  EvidenceSummary summary(String summary);

  EvidenceSummary uncertainty(String uncertainty);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceSummary call({
    String claimId,
    String factorLabel,
    DateTime observedAt,
    String summary,
    String uncertainty,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEvidenceSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEvidenceSummary.copyWith.fieldName(...)`
class _$EvidenceSummaryCWProxyImpl implements _$EvidenceSummaryCWProxy {
  const _$EvidenceSummaryCWProxyImpl(this._value);

  final EvidenceSummary _value;

  @override
  EvidenceSummary claimId(String claimId) => this(claimId: claimId);

  @override
  EvidenceSummary factorLabel(String factorLabel) =>
      this(factorLabel: factorLabel);

  @override
  EvidenceSummary observedAt(DateTime observedAt) =>
      this(observedAt: observedAt);

  @override
  EvidenceSummary summary(String summary) => this(summary: summary);

  @override
  EvidenceSummary uncertainty(String uncertainty) =>
      this(uncertainty: uncertainty);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceSummary call({
    Object? claimId = const $CopyWithPlaceholder(),
    Object? factorLabel = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
    Object? uncertainty = const $CopyWithPlaceholder(),
  }) {
    return EvidenceSummary(
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

extension $EvidenceSummaryCopyWith on EvidenceSummary {
  /// Returns a callable class that can be used as follows: `instanceOfEvidenceSummary.copyWith(...)` or like so:`instanceOfEvidenceSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EvidenceSummaryCWProxy get copyWith => _$EvidenceSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EvidenceSummary _$EvidenceSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'EvidenceSummary',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'claim_id',
            'factor_label',
            'observed_at',
            'summary',
            'uncertainty',
          ],
        );
        final val = EvidenceSummary(
          claimId: $checkedConvert('claim_id', (v) => v as String),
          factorLabel: $checkedConvert('factor_label', (v) => v as String),
          observedAt: $checkedConvert(
            'observed_at',
            (v) => DateTime.parse(v as String),
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
      },
    );

Map<String, dynamic> _$EvidenceSummaryToJson(EvidenceSummary instance) =>
    <String, dynamic>{
      'claim_id': instance.claimId,
      'factor_label': instance.factorLabel,
      'observed_at': instance.observedAt.toIso8601String(),
      'summary': instance.summary,
      'uncertainty': instance.uncertainty,
    };
