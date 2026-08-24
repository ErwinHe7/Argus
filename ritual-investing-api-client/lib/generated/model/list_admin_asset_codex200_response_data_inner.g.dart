// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_admin_asset_codex200_response_data_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListAdminAssetCodex200ResponseDataInnerCWProxy {
  ListAdminAssetCodex200ResponseDataInner currentPublishedRevisionId(
    String? currentPublishedRevisionId,
  );

  ListAdminAssetCodex200ResponseDataInner etag(String etag);

  ListAdminAssetCodex200ResponseDataInner id(String id);

  ListAdminAssetCodex200ResponseDataInner kind(
    ListAdminAssetCodex200ResponseDataInnerKindEnum kind,
  );

  ListAdminAssetCodex200ResponseDataInner revision(
    ListAdminAssetCodex200ResponseDataInnerRevision? revision,
  );

  ListAdminAssetCodex200ResponseDataInner slug(String slug);

  ListAdminAssetCodex200ResponseDataInner status(
    ListAdminAssetCodex200ResponseDataInnerStatusEnum status,
  );

  ListAdminAssetCodex200ResponseDataInner version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInner call({
    String? currentPublishedRevisionId,
    String etag,
    String id,
    ListAdminAssetCodex200ResponseDataInnerKindEnum kind,
    ListAdminAssetCodex200ResponseDataInnerRevision? revision,
    String slug,
    ListAdminAssetCodex200ResponseDataInnerStatusEnum status,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListAdminAssetCodex200ResponseDataInner.copyWith.fieldName(...)`
class _$ListAdminAssetCodex200ResponseDataInnerCWProxyImpl
    implements _$ListAdminAssetCodex200ResponseDataInnerCWProxy {
  const _$ListAdminAssetCodex200ResponseDataInnerCWProxyImpl(this._value);

  final ListAdminAssetCodex200ResponseDataInner _value;

  @override
  ListAdminAssetCodex200ResponseDataInner currentPublishedRevisionId(
    String? currentPublishedRevisionId,
  ) => this(currentPublishedRevisionId: currentPublishedRevisionId);

  @override
  ListAdminAssetCodex200ResponseDataInner etag(String etag) => this(etag: etag);

  @override
  ListAdminAssetCodex200ResponseDataInner id(String id) => this(id: id);

  @override
  ListAdminAssetCodex200ResponseDataInner kind(
    ListAdminAssetCodex200ResponseDataInnerKindEnum kind,
  ) => this(kind: kind);

  @override
  ListAdminAssetCodex200ResponseDataInner revision(
    ListAdminAssetCodex200ResponseDataInnerRevision? revision,
  ) => this(revision: revision);

  @override
  ListAdminAssetCodex200ResponseDataInner slug(String slug) => this(slug: slug);

  @override
  ListAdminAssetCodex200ResponseDataInner status(
    ListAdminAssetCodex200ResponseDataInnerStatusEnum status,
  ) => this(status: status);

  @override
  ListAdminAssetCodex200ResponseDataInner version(int version) =>
      this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListAdminAssetCodex200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListAdminAssetCodex200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListAdminAssetCodex200ResponseDataInner call({
    Object? currentPublishedRevisionId = const $CopyWithPlaceholder(),
    Object? etag = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? revision = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return ListAdminAssetCodex200ResponseDataInner(
      currentPublishedRevisionId:
          currentPublishedRevisionId == const $CopyWithPlaceholder()
          ? _value.currentPublishedRevisionId
          // ignore: cast_nullable_to_non_nullable
          : currentPublishedRevisionId as String?,
      etag: etag == const $CopyWithPlaceholder()
          ? _value.etag
          // ignore: cast_nullable_to_non_nullable
          : etag as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as ListAdminAssetCodex200ResponseDataInnerKindEnum,
      revision: revision == const $CopyWithPlaceholder()
          ? _value.revision
          // ignore: cast_nullable_to_non_nullable
          : revision as ListAdminAssetCodex200ResponseDataInnerRevision?,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as ListAdminAssetCodex200ResponseDataInnerStatusEnum,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $ListAdminAssetCodex200ResponseDataInnerCopyWith
    on ListAdminAssetCodex200ResponseDataInner {
  /// Returns a callable class that can be used as follows: `instanceOfListAdminAssetCodex200ResponseDataInner.copyWith(...)` or like so:`instanceOfListAdminAssetCodex200ResponseDataInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListAdminAssetCodex200ResponseDataInnerCWProxy get copyWith =>
      _$ListAdminAssetCodex200ResponseDataInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListAdminAssetCodex200ResponseDataInner
_$ListAdminAssetCodex200ResponseDataInnerFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ListAdminAssetCodex200ResponseDataInner',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'current_published_revision_id',
            'etag',
            'id',
            'kind',
            'slug',
            'status',
            'version',
          ],
        );
        final val = ListAdminAssetCodex200ResponseDataInner(
          currentPublishedRevisionId: $checkedConvert(
            'current_published_revision_id',
            (v) => v as String?,
          ),
          etag: $checkedConvert('etag', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          kind: $checkedConvert(
            'kind',
            (v) => $enumDecode(
              _$ListAdminAssetCodex200ResponseDataInnerKindEnumEnumMap,
              v,
              unknownValue: ListAdminAssetCodex200ResponseDataInnerKindEnum
                  .unknownDefaultOpenApi,
            ),
          ),
          revision: $checkedConvert(
            'revision',
            (v) => v == null
                ? null
                : ListAdminAssetCodex200ResponseDataInnerRevision.fromJson(
                    v as Map<String, dynamic>,
                  ),
          ),
          slug: $checkedConvert('slug', (v) => v as String),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$ListAdminAssetCodex200ResponseDataInnerStatusEnumEnumMap,
              v,
              unknownValue: ListAdminAssetCodex200ResponseDataInnerStatusEnum
                  .unknownDefaultOpenApi,
            ),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'currentPublishedRevisionId': 'current_published_revision_id',
      },
    );

Map<String, dynamic> _$ListAdminAssetCodex200ResponseDataInnerToJson(
  ListAdminAssetCodex200ResponseDataInner instance,
) => <String, dynamic>{
  'current_published_revision_id': instance.currentPublishedRevisionId,
  'etag': instance.etag,
  'id': instance.id,
  'kind':
      _$ListAdminAssetCodex200ResponseDataInnerKindEnumEnumMap[instance.kind]!,
  'revision': ?instance.revision?.toJson(),
  'slug': instance.slug,
  'status':
      _$ListAdminAssetCodex200ResponseDataInnerStatusEnumEnumMap[instance
          .status]!,
  'version': instance.version,
};

const _$ListAdminAssetCodex200ResponseDataInnerKindEnumEnumMap = {
  ListAdminAssetCodex200ResponseDataInnerKindEnum.ritualScenario:
      'ritual_scenario',
  ListAdminAssetCodex200ResponseDataInnerKindEnum.assetCodex: 'asset_codex',
  ListAdminAssetCodex200ResponseDataInnerKindEnum.covenEntry: 'coven_entry',
  ListAdminAssetCodex200ResponseDataInnerKindEnum.grimoire: 'grimoire',
  ListAdminAssetCodex200ResponseDataInnerKindEnum.circleTemplate:
      'circle_template',
  ListAdminAssetCodex200ResponseDataInnerKindEnum.rowanScript: 'rowan_script',
  ListAdminAssetCodex200ResponseDataInnerKindEnum.briefingTemplate:
      'briefing_template',
  ListAdminAssetCodex200ResponseDataInnerKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$ListAdminAssetCodex200ResponseDataInnerStatusEnumEnumMap = {
  ListAdminAssetCodex200ResponseDataInnerStatusEnum.draft: 'draft',
  ListAdminAssetCodex200ResponseDataInnerStatusEnum.published: 'published',
  ListAdminAssetCodex200ResponseDataInnerStatusEnum.withdrawn: 'withdrawn',
  ListAdminAssetCodex200ResponseDataInnerStatusEnum.retired: 'retired',
  ListAdminAssetCodex200ResponseDataInnerStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
