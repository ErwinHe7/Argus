// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_evidence.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathEvidenceCWProxy {
  StarpathEvidence canonicalUrl(String canonicalUrl);

  StarpathEvidence claimSummary(String claimSummary);

  StarpathEvidence currentUntil(DateTime currentUntil);

  StarpathEvidence effectiveAt(DateTime? effectiveAt);

  StarpathEvidence ordinal(int ordinal);

  StarpathEvidence publisher(String publisher);

  StarpathEvidence retrievedAt(DateTime retrievedAt);

  StarpathEvidence sourceObservedAt(DateTime sourceObservedAt);

  StarpathEvidence sourceTitle(String sourceTitle);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathEvidence(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathEvidence(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathEvidence call({
    String canonicalUrl,
    String claimSummary,
    DateTime currentUntil,
    DateTime? effectiveAt,
    int ordinal,
    String publisher,
    DateTime retrievedAt,
    DateTime sourceObservedAt,
    String sourceTitle,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathEvidence.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathEvidence.copyWith.fieldName(...)`
class _$StarpathEvidenceCWProxyImpl implements _$StarpathEvidenceCWProxy {
  const _$StarpathEvidenceCWProxyImpl(this._value);

  final StarpathEvidence _value;

  @override
  StarpathEvidence canonicalUrl(String canonicalUrl) =>
      this(canonicalUrl: canonicalUrl);

  @override
  StarpathEvidence claimSummary(String claimSummary) =>
      this(claimSummary: claimSummary);

  @override
  StarpathEvidence currentUntil(DateTime currentUntil) =>
      this(currentUntil: currentUntil);

  @override
  StarpathEvidence effectiveAt(DateTime? effectiveAt) =>
      this(effectiveAt: effectiveAt);

  @override
  StarpathEvidence ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  StarpathEvidence publisher(String publisher) => this(publisher: publisher);

  @override
  StarpathEvidence retrievedAt(DateTime retrievedAt) =>
      this(retrievedAt: retrievedAt);

  @override
  StarpathEvidence sourceObservedAt(DateTime sourceObservedAt) =>
      this(sourceObservedAt: sourceObservedAt);

  @override
  StarpathEvidence sourceTitle(String sourceTitle) =>
      this(sourceTitle: sourceTitle);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathEvidence(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathEvidence(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathEvidence call({
    Object? canonicalUrl = const $CopyWithPlaceholder(),
    Object? claimSummary = const $CopyWithPlaceholder(),
    Object? currentUntil = const $CopyWithPlaceholder(),
    Object? effectiveAt = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? publisher = const $CopyWithPlaceholder(),
    Object? retrievedAt = const $CopyWithPlaceholder(),
    Object? sourceObservedAt = const $CopyWithPlaceholder(),
    Object? sourceTitle = const $CopyWithPlaceholder(),
  }) {
    return StarpathEvidence(
      canonicalUrl: canonicalUrl == const $CopyWithPlaceholder()
          ? _value.canonicalUrl
          // ignore: cast_nullable_to_non_nullable
          : canonicalUrl as String,
      claimSummary: claimSummary == const $CopyWithPlaceholder()
          ? _value.claimSummary
          // ignore: cast_nullable_to_non_nullable
          : claimSummary as String,
      currentUntil: currentUntil == const $CopyWithPlaceholder()
          ? _value.currentUntil
          // ignore: cast_nullable_to_non_nullable
          : currentUntil as DateTime,
      effectiveAt: effectiveAt == const $CopyWithPlaceholder()
          ? _value.effectiveAt
          // ignore: cast_nullable_to_non_nullable
          : effectiveAt as DateTime?,
      ordinal: ordinal == const $CopyWithPlaceholder()
          ? _value.ordinal
          // ignore: cast_nullable_to_non_nullable
          : ordinal as int,
      publisher: publisher == const $CopyWithPlaceholder()
          ? _value.publisher
          // ignore: cast_nullable_to_non_nullable
          : publisher as String,
      retrievedAt: retrievedAt == const $CopyWithPlaceholder()
          ? _value.retrievedAt
          // ignore: cast_nullable_to_non_nullable
          : retrievedAt as DateTime,
      sourceObservedAt: sourceObservedAt == const $CopyWithPlaceholder()
          ? _value.sourceObservedAt
          // ignore: cast_nullable_to_non_nullable
          : sourceObservedAt as DateTime,
      sourceTitle: sourceTitle == const $CopyWithPlaceholder()
          ? _value.sourceTitle
          // ignore: cast_nullable_to_non_nullable
          : sourceTitle as String,
    );
  }
}

extension $StarpathEvidenceCopyWith on StarpathEvidence {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathEvidence.copyWith(...)` or like so:`instanceOfStarpathEvidence.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathEvidenceCWProxy get copyWith => _$StarpathEvidenceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathEvidence _$StarpathEvidenceFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StarpathEvidence',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'canonical_url',
            'claim_summary',
            'current_until',
            'effective_at',
            'ordinal',
            'publisher',
            'retrieved_at',
            'source_observed_at',
            'source_title',
          ],
        );
        final val = StarpathEvidence(
          canonicalUrl: $checkedConvert('canonical_url', (v) => v as String),
          claimSummary: $checkedConvert('claim_summary', (v) => v as String),
          currentUntil: $checkedConvert(
            'current_until',
            (v) => DateTime.parse(v as String),
          ),
          effectiveAt: $checkedConvert(
            'effective_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
          publisher: $checkedConvert('publisher', (v) => v as String),
          retrievedAt: $checkedConvert(
            'retrieved_at',
            (v) => DateTime.parse(v as String),
          ),
          sourceObservedAt: $checkedConvert(
            'source_observed_at',
            (v) => DateTime.parse(v as String),
          ),
          sourceTitle: $checkedConvert('source_title', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'canonicalUrl': 'canonical_url',
        'claimSummary': 'claim_summary',
        'currentUntil': 'current_until',
        'effectiveAt': 'effective_at',
        'retrievedAt': 'retrieved_at',
        'sourceObservedAt': 'source_observed_at',
        'sourceTitle': 'source_title',
      },
    );

Map<String, dynamic> _$StarpathEvidenceToJson(StarpathEvidence instance) =>
    <String, dynamic>{
      'canonical_url': instance.canonicalUrl,
      'claim_summary': instance.claimSummary,
      'current_until': instance.currentUntil.toIso8601String(),
      'effective_at': instance.effectiveAt?.toIso8601String(),
      'ordinal': instance.ordinal,
      'publisher': instance.publisher,
      'retrieved_at': instance.retrievedAt.toIso8601String(),
      'source_observed_at': instance.sourceObservedAt.toIso8601String(),
      'source_title': instance.sourceTitle,
    };
