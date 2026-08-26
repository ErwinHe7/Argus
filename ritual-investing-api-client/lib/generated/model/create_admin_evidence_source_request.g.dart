// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_evidence_source_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminEvidenceSourceRequestCWProxy {
  CreateAdminEvidenceSourceRequest canonicalUrl(String canonicalUrl);

  CreateAdminEvidenceSourceRequest publishedAt(DateTime? publishedAt);

  CreateAdminEvidenceSourceRequest publisher(String publisher);

  CreateAdminEvidenceSourceRequest retrievedAt(DateTime retrievedAt);

  CreateAdminEvidenceSourceRequest sourceKind(
    CreateAdminEvidenceSourceRequestSourceKindEnum sourceKind,
  );

  CreateAdminEvidenceSourceRequest status(
    CreateAdminEvidenceSourceRequestStatusEnum status,
  );

  CreateAdminEvidenceSourceRequest title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEvidenceSourceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEvidenceSourceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEvidenceSourceRequest call({
    String canonicalUrl,
    DateTime? publishedAt,
    String publisher,
    DateTime retrievedAt,
    CreateAdminEvidenceSourceRequestSourceKindEnum sourceKind,
    CreateAdminEvidenceSourceRequestStatusEnum status,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminEvidenceSourceRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminEvidenceSourceRequest.copyWith.fieldName(...)`
class _$CreateAdminEvidenceSourceRequestCWProxyImpl
    implements _$CreateAdminEvidenceSourceRequestCWProxy {
  const _$CreateAdminEvidenceSourceRequestCWProxyImpl(this._value);

  final CreateAdminEvidenceSourceRequest _value;

  @override
  CreateAdminEvidenceSourceRequest canonicalUrl(String canonicalUrl) =>
      this(canonicalUrl: canonicalUrl);

  @override
  CreateAdminEvidenceSourceRequest publishedAt(DateTime? publishedAt) =>
      this(publishedAt: publishedAt);

  @override
  CreateAdminEvidenceSourceRequest publisher(String publisher) =>
      this(publisher: publisher);

  @override
  CreateAdminEvidenceSourceRequest retrievedAt(DateTime retrievedAt) =>
      this(retrievedAt: retrievedAt);

  @override
  CreateAdminEvidenceSourceRequest sourceKind(
    CreateAdminEvidenceSourceRequestSourceKindEnum sourceKind,
  ) => this(sourceKind: sourceKind);

  @override
  CreateAdminEvidenceSourceRequest status(
    CreateAdminEvidenceSourceRequestStatusEnum status,
  ) => this(status: status);

  @override
  CreateAdminEvidenceSourceRequest title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminEvidenceSourceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminEvidenceSourceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminEvidenceSourceRequest call({
    Object? canonicalUrl = const $CopyWithPlaceholder(),
    Object? publishedAt = const $CopyWithPlaceholder(),
    Object? publisher = const $CopyWithPlaceholder(),
    Object? retrievedAt = const $CopyWithPlaceholder(),
    Object? sourceKind = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminEvidenceSourceRequest(
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
          : sourceKind as CreateAdminEvidenceSourceRequestSourceKindEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as CreateAdminEvidenceSourceRequestStatusEnum,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $CreateAdminEvidenceSourceRequestCopyWith
    on CreateAdminEvidenceSourceRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminEvidenceSourceRequest.copyWith(...)` or like so:`instanceOfCreateAdminEvidenceSourceRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminEvidenceSourceRequestCWProxy get copyWith =>
      _$CreateAdminEvidenceSourceRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminEvidenceSourceRequest _$CreateAdminEvidenceSourceRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateAdminEvidenceSourceRequest',
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
        'status',
        'title',
      ],
    );
    final val = CreateAdminEvidenceSourceRequest(
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
      sourceKind: $checkedConvert(
        'source_kind',
        (v) => $enumDecode(
          _$CreateAdminEvidenceSourceRequestSourceKindEnumEnumMap,
          v,
          unknownValue: CreateAdminEvidenceSourceRequestSourceKindEnum
              .unknownDefaultOpenApi,
        ),
      ),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$CreateAdminEvidenceSourceRequestStatusEnumEnumMap,
          v,
          unknownValue:
              CreateAdminEvidenceSourceRequestStatusEnum.unknownDefaultOpenApi,
        ),
      ),
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

Map<String, dynamic> _$CreateAdminEvidenceSourceRequestToJson(
  CreateAdminEvidenceSourceRequest instance,
) => <String, dynamic>{
  'canonical_url': instance.canonicalUrl,
  'published_at': instance.publishedAt?.toIso8601String(),
  'publisher': instance.publisher,
  'retrieved_at': instance.retrievedAt.toIso8601String(),
  'source_kind':
      _$CreateAdminEvidenceSourceRequestSourceKindEnumEnumMap[instance
          .sourceKind]!,
  'status':
      _$CreateAdminEvidenceSourceRequestStatusEnumEnumMap[instance.status]!,
  'title': instance.title,
};

const _$CreateAdminEvidenceSourceRequestSourceKindEnumEnumMap = {
  CreateAdminEvidenceSourceRequestSourceKindEnum.filing: 'filing',
  CreateAdminEvidenceSourceRequestSourceKindEnum.company: 'company',
  CreateAdminEvidenceSourceRequestSourceKindEnum.exchange: 'exchange',
  CreateAdminEvidenceSourceRequestSourceKindEnum.research: 'research',
  CreateAdminEvidenceSourceRequestSourceKindEnum.news: 'news',
  CreateAdminEvidenceSourceRequestSourceKindEnum.other: 'other',
  CreateAdminEvidenceSourceRequestSourceKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$CreateAdminEvidenceSourceRequestStatusEnumEnumMap = {
  CreateAdminEvidenceSourceRequestStatusEnum.active: 'active',
  CreateAdminEvidenceSourceRequestStatusEnum.retired: 'retired',
  CreateAdminEvidenceSourceRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
