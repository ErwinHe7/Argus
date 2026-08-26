// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_evidence_source.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminEvidenceSourceCWProxy {
  AdminEvidenceSource canonicalUrl(String canonicalUrl);

  AdminEvidenceSource etag(String etag);

  AdminEvidenceSource id(String id);

  AdminEvidenceSource publishedAt(DateTime? publishedAt);

  AdminEvidenceSource publisher(String publisher);

  AdminEvidenceSource retrievedAt(DateTime retrievedAt);

  AdminEvidenceSource sourceKind(AdminEvidenceSourceSourceKindEnum sourceKind);

  AdminEvidenceSource status(AdminEvidenceSourceStatusEnum status);

  AdminEvidenceSource title(String title);

  AdminEvidenceSource version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminEvidenceSource(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminEvidenceSource(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminEvidenceSource call({
    String canonicalUrl,
    String etag,
    String id,
    DateTime? publishedAt,
    String publisher,
    DateTime retrievedAt,
    AdminEvidenceSourceSourceKindEnum sourceKind,
    AdminEvidenceSourceStatusEnum status,
    String title,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminEvidenceSource.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminEvidenceSource.copyWith.fieldName(...)`
class _$AdminEvidenceSourceCWProxyImpl implements _$AdminEvidenceSourceCWProxy {
  const _$AdminEvidenceSourceCWProxyImpl(this._value);

  final AdminEvidenceSource _value;

  @override
  AdminEvidenceSource canonicalUrl(String canonicalUrl) =>
      this(canonicalUrl: canonicalUrl);

  @override
  AdminEvidenceSource etag(String etag) => this(etag: etag);

  @override
  AdminEvidenceSource id(String id) => this(id: id);

  @override
  AdminEvidenceSource publishedAt(DateTime? publishedAt) =>
      this(publishedAt: publishedAt);

  @override
  AdminEvidenceSource publisher(String publisher) => this(publisher: publisher);

  @override
  AdminEvidenceSource retrievedAt(DateTime retrievedAt) =>
      this(retrievedAt: retrievedAt);

  @override
  AdminEvidenceSource sourceKind(
    AdminEvidenceSourceSourceKindEnum sourceKind,
  ) => this(sourceKind: sourceKind);

  @override
  AdminEvidenceSource status(AdminEvidenceSourceStatusEnum status) =>
      this(status: status);

  @override
  AdminEvidenceSource title(String title) => this(title: title);

  @override
  AdminEvidenceSource version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminEvidenceSource(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminEvidenceSource(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminEvidenceSource call({
    Object? canonicalUrl = const $CopyWithPlaceholder(),
    Object? etag = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? publishedAt = const $CopyWithPlaceholder(),
    Object? publisher = const $CopyWithPlaceholder(),
    Object? retrievedAt = const $CopyWithPlaceholder(),
    Object? sourceKind = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return AdminEvidenceSource(
      canonicalUrl: canonicalUrl == const $CopyWithPlaceholder()
          ? _value.canonicalUrl
          // ignore: cast_nullable_to_non_nullable
          : canonicalUrl as String,
      etag: etag == const $CopyWithPlaceholder()
          ? _value.etag
          // ignore: cast_nullable_to_non_nullable
          : etag as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
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
          : sourceKind as AdminEvidenceSourceSourceKindEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as AdminEvidenceSourceStatusEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $AdminEvidenceSourceCopyWith on AdminEvidenceSource {
  /// Returns a callable class that can be used as follows: `instanceOfAdminEvidenceSource.copyWith(...)` or like so:`instanceOfAdminEvidenceSource.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminEvidenceSourceCWProxy get copyWith =>
      _$AdminEvidenceSourceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminEvidenceSource _$AdminEvidenceSourceFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AdminEvidenceSource',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'canonical_url',
            'etag',
            'id',
            'published_at',
            'publisher',
            'retrieved_at',
            'source_kind',
            'status',
            'title',
            'version',
          ],
        );
        final val = AdminEvidenceSource(
          canonicalUrl: $checkedConvert('canonical_url', (v) => v as String),
          etag: $checkedConvert('etag', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          publishedAt: $checkedConvert(
            'published_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          publisher: $checkedConvert('publisher', (v) => v as String),
          retrievedAt: $checkedConvert(
            'retrieved_at',
            (v) => DateTime.parse(v as String),
          ),
          sourceKind: $checkedConvert(
            'source_kind',
            (v) => $enumDecode(
              _$AdminEvidenceSourceSourceKindEnumEnumMap,
              v,
              unknownValue:
                  AdminEvidenceSourceSourceKindEnum.unknownDefaultOpenApi,
            ),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$AdminEvidenceSourceStatusEnumEnumMap,
              v,
              unknownValue: AdminEvidenceSourceStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          title: $checkedConvert('title', (v) => v as String),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
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

Map<String, dynamic> _$AdminEvidenceSourceToJson(
  AdminEvidenceSource instance,
) => <String, dynamic>{
  'canonical_url': instance.canonicalUrl,
  'etag': instance.etag,
  'id': instance.id,
  'published_at': instance.publishedAt?.toIso8601String(),
  'publisher': instance.publisher,
  'retrieved_at': instance.retrievedAt.toIso8601String(),
  'source_kind':
      _$AdminEvidenceSourceSourceKindEnumEnumMap[instance.sourceKind]!,
  'status': _$AdminEvidenceSourceStatusEnumEnumMap[instance.status]!,
  'title': instance.title,
  'version': instance.version,
};

const _$AdminEvidenceSourceSourceKindEnumEnumMap = {
  AdminEvidenceSourceSourceKindEnum.filing: 'filing',
  AdminEvidenceSourceSourceKindEnum.company: 'company',
  AdminEvidenceSourceSourceKindEnum.exchange: 'exchange',
  AdminEvidenceSourceSourceKindEnum.research: 'research',
  AdminEvidenceSourceSourceKindEnum.news: 'news',
  AdminEvidenceSourceSourceKindEnum.other: 'other',
  AdminEvidenceSourceSourceKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$AdminEvidenceSourceStatusEnumEnumMap = {
  AdminEvidenceSourceStatusEnum.active: 'active',
  AdminEvidenceSourceStatusEnum.retired: 'retired',
  AdminEvidenceSourceStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
