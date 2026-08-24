// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_admin_evidence_source_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchAdminEvidenceSourceRequestCWProxy {
  PatchAdminEvidenceSourceRequest canonicalUrl(String? canonicalUrl);

  PatchAdminEvidenceSourceRequest publishedAt(DateTime? publishedAt);

  PatchAdminEvidenceSourceRequest publisher(String? publisher);

  PatchAdminEvidenceSourceRequest retrievedAt(DateTime? retrievedAt);

  PatchAdminEvidenceSourceRequest sourceKind(
    PatchAdminEvidenceSourceRequestSourceKindEnum? sourceKind,
  );

  PatchAdminEvidenceSourceRequest status(
    PatchAdminEvidenceSourceRequestStatusEnum? status,
  );

  PatchAdminEvidenceSourceRequest title(String? title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminEvidenceSourceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminEvidenceSourceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminEvidenceSourceRequest call({
    String? canonicalUrl,
    DateTime? publishedAt,
    String? publisher,
    DateTime? retrievedAt,
    PatchAdminEvidenceSourceRequestSourceKindEnum? sourceKind,
    PatchAdminEvidenceSourceRequestStatusEnum? status,
    String? title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchAdminEvidenceSourceRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchAdminEvidenceSourceRequest.copyWith.fieldName(...)`
class _$PatchAdminEvidenceSourceRequestCWProxyImpl
    implements _$PatchAdminEvidenceSourceRequestCWProxy {
  const _$PatchAdminEvidenceSourceRequestCWProxyImpl(this._value);

  final PatchAdminEvidenceSourceRequest _value;

  @override
  PatchAdminEvidenceSourceRequest canonicalUrl(String? canonicalUrl) =>
      this(canonicalUrl: canonicalUrl);

  @override
  PatchAdminEvidenceSourceRequest publishedAt(DateTime? publishedAt) =>
      this(publishedAt: publishedAt);

  @override
  PatchAdminEvidenceSourceRequest publisher(String? publisher) =>
      this(publisher: publisher);

  @override
  PatchAdminEvidenceSourceRequest retrievedAt(DateTime? retrievedAt) =>
      this(retrievedAt: retrievedAt);

  @override
  PatchAdminEvidenceSourceRequest sourceKind(
    PatchAdminEvidenceSourceRequestSourceKindEnum? sourceKind,
  ) => this(sourceKind: sourceKind);

  @override
  PatchAdminEvidenceSourceRequest status(
    PatchAdminEvidenceSourceRequestStatusEnum? status,
  ) => this(status: status);

  @override
  PatchAdminEvidenceSourceRequest title(String? title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminEvidenceSourceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminEvidenceSourceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminEvidenceSourceRequest call({
    Object? canonicalUrl = const $CopyWithPlaceholder(),
    Object? publishedAt = const $CopyWithPlaceholder(),
    Object? publisher = const $CopyWithPlaceholder(),
    Object? retrievedAt = const $CopyWithPlaceholder(),
    Object? sourceKind = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return PatchAdminEvidenceSourceRequest(
      canonicalUrl: canonicalUrl == const $CopyWithPlaceholder()
          ? _value.canonicalUrl
          // ignore: cast_nullable_to_non_nullable
          : canonicalUrl as String?,
      publishedAt: publishedAt == const $CopyWithPlaceholder()
          ? _value.publishedAt
          // ignore: cast_nullable_to_non_nullable
          : publishedAt as DateTime?,
      publisher: publisher == const $CopyWithPlaceholder()
          ? _value.publisher
          // ignore: cast_nullable_to_non_nullable
          : publisher as String?,
      retrievedAt: retrievedAt == const $CopyWithPlaceholder()
          ? _value.retrievedAt
          // ignore: cast_nullable_to_non_nullable
          : retrievedAt as DateTime?,
      sourceKind: sourceKind == const $CopyWithPlaceholder()
          ? _value.sourceKind
          // ignore: cast_nullable_to_non_nullable
          : sourceKind as PatchAdminEvidenceSourceRequestSourceKindEnum?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PatchAdminEvidenceSourceRequestStatusEnum?,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
    );
  }
}

extension $PatchAdminEvidenceSourceRequestCopyWith
    on PatchAdminEvidenceSourceRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchAdminEvidenceSourceRequest.copyWith(...)` or like so:`instanceOfPatchAdminEvidenceSourceRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchAdminEvidenceSourceRequestCWProxy get copyWith =>
      _$PatchAdminEvidenceSourceRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchAdminEvidenceSourceRequest _$PatchAdminEvidenceSourceRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PatchAdminEvidenceSourceRequest',
  json,
  ($checkedConvert) {
    final val = PatchAdminEvidenceSourceRequest(
      canonicalUrl: $checkedConvert('canonical_url', (v) => v as String?),
      publishedAt: $checkedConvert(
        'published_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      publisher: $checkedConvert('publisher', (v) => v as String?),
      retrievedAt: $checkedConvert(
        'retrieved_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      sourceKind: $checkedConvert(
        'source_kind',
        (v) => $enumDecodeNullable(
          _$PatchAdminEvidenceSourceRequestSourceKindEnumEnumMap,
          v,
          unknownValue: PatchAdminEvidenceSourceRequestSourceKindEnum
              .unknownDefaultOpenApi,
        ),
      ),
      status: $checkedConvert(
        'status',
        (v) => $enumDecodeNullable(
          _$PatchAdminEvidenceSourceRequestStatusEnumEnumMap,
          v,
          unknownValue:
              PatchAdminEvidenceSourceRequestStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      title: $checkedConvert('title', (v) => v as String?),
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

Map<String, dynamic> _$PatchAdminEvidenceSourceRequestToJson(
  PatchAdminEvidenceSourceRequest instance,
) => <String, dynamic>{
  'canonical_url': ?instance.canonicalUrl,
  'published_at': ?instance.publishedAt?.toIso8601String(),
  'publisher': ?instance.publisher,
  'retrieved_at': ?instance.retrievedAt?.toIso8601String(),
  'source_kind':
      ?_$PatchAdminEvidenceSourceRequestSourceKindEnumEnumMap[instance
          .sourceKind],
  'status':
      ?_$PatchAdminEvidenceSourceRequestStatusEnumEnumMap[instance.status],
  'title': ?instance.title,
};

const _$PatchAdminEvidenceSourceRequestSourceKindEnumEnumMap = {
  PatchAdminEvidenceSourceRequestSourceKindEnum.filing: 'filing',
  PatchAdminEvidenceSourceRequestSourceKindEnum.company: 'company',
  PatchAdminEvidenceSourceRequestSourceKindEnum.exchange: 'exchange',
  PatchAdminEvidenceSourceRequestSourceKindEnum.research: 'research',
  PatchAdminEvidenceSourceRequestSourceKindEnum.news: 'news',
  PatchAdminEvidenceSourceRequestSourceKindEnum.other: 'other',
  PatchAdminEvidenceSourceRequestSourceKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PatchAdminEvidenceSourceRequestStatusEnumEnumMap = {
  PatchAdminEvidenceSourceRequestStatusEnum.active: 'active',
  PatchAdminEvidenceSourceRequestStatusEnum.retired: 'retired',
  PatchAdminEvidenceSourceRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
