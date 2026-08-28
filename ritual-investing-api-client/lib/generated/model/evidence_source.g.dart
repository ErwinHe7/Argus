// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evidence_source.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EvidenceSourceCWProxy {
  EvidenceSource canonicalUrl(String canonicalUrl);

  EvidenceSource publishedAt(DateTime? publishedAt);

  EvidenceSource publisher(String publisher);

  EvidenceSource retrievedAt(DateTime retrievedAt);

  EvidenceSource sourceKind(String sourceKind);

  EvidenceSource title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceSource(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceSource(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceSource call({
    String canonicalUrl,
    DateTime? publishedAt,
    String publisher,
    DateTime retrievedAt,
    String sourceKind,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEvidenceSource.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEvidenceSource.copyWith.fieldName(...)`
class _$EvidenceSourceCWProxyImpl implements _$EvidenceSourceCWProxy {
  const _$EvidenceSourceCWProxyImpl(this._value);

  final EvidenceSource _value;

  @override
  EvidenceSource canonicalUrl(String canonicalUrl) =>
      this(canonicalUrl: canonicalUrl);

  @override
  EvidenceSource publishedAt(DateTime? publishedAt) =>
      this(publishedAt: publishedAt);

  @override
  EvidenceSource publisher(String publisher) => this(publisher: publisher);

  @override
  EvidenceSource retrievedAt(DateTime retrievedAt) =>
      this(retrievedAt: retrievedAt);

  @override
  EvidenceSource sourceKind(String sourceKind) => this(sourceKind: sourceKind);

  @override
  EvidenceSource title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EvidenceSource(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EvidenceSource(...).copyWith(id: 12, name: "My name")
  /// ````
  EvidenceSource call({
    Object? canonicalUrl = const $CopyWithPlaceholder(),
    Object? publishedAt = const $CopyWithPlaceholder(),
    Object? publisher = const $CopyWithPlaceholder(),
    Object? retrievedAt = const $CopyWithPlaceholder(),
    Object? sourceKind = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return EvidenceSource(
      canonicalUrl: canonicalUrl == const $CopyWithPlaceholder()
          ? _value.canonicalUrl
          // ignore: cast_nullable_to_non_nullable
          : canonicalUrl as String,
      publishedAt: publishedAt == const $CopyWithPlaceholder()
          ? _value.publishedAt
          // ignore: cast_nullable_to_non_nullable
          : publishedAt as DateTime?,
      publisher: publisher == const $CopyWithPlaceholder()
          ? _value.publisher
          // ignore: cast_nullable_to_non_nullable
          : publisher as String,
      retrievedAt: retrievedAt == const $CopyWithPlaceholder()
          ? _value.retrievedAt
          // ignore: cast_nullable_to_non_nullable
          : retrievedAt as DateTime,
      sourceKind: sourceKind == const $CopyWithPlaceholder()
          ? _value.sourceKind
          // ignore: cast_nullable_to_non_nullable
          : sourceKind as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $EvidenceSourceCopyWith on EvidenceSource {
  /// Returns a callable class that can be used as follows: `instanceOfEvidenceSource.copyWith(...)` or like so:`instanceOfEvidenceSource.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EvidenceSourceCWProxy get copyWith => _$EvidenceSourceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EvidenceSource _$EvidenceSourceFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'EvidenceSource',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'canonical_url',
            'published_at',
            'publisher',
            'retrieved_at',
            'source_kind',
            'title',
          ],
        );
        final val = EvidenceSource(
          canonicalUrl: $checkedConvert('canonical_url', (v) => v as String),
          publishedAt: $checkedConvert(
            'published_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          publisher: $checkedConvert('publisher', (v) => v as String),
          retrievedAt: $checkedConvert(
            'retrieved_at',
            (v) => DateTime.parse(v as String),
          ),
          sourceKind: $checkedConvert('source_kind', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'canonicalUrl': 'canonical_url',
        'publishedAt': 'published_at',
        'retrievedAt': 'retrieved_at',
        'sourceKind': 'source_kind',
      },
    );

Map<String, dynamic> _$EvidenceSourceToJson(EvidenceSource instance) =>
    <String, dynamic>{
      'canonical_url': instance.canonicalUrl,
      'published_at': instance.publishedAt?.toIso8601String(),
      'publisher': instance.publisher,
      'retrieved_at': instance.retrievedAt.toIso8601String(),
      'source_kind': instance.sourceKind,
      'title': instance.title,
    };
