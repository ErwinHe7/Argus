// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_circle_template_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateCircleTemplateRequestCWProxy {
  CreateCircleTemplateRequest artMediaId(String? artMediaId);

  CreateCircleTemplateRequest assets(
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
    >
    assets,
  );

  CreateCircleTemplateRequest creatorId(String creatorId);

  CreateCircleTemplateRequest description(String description);

  CreateCircleTemplateRequest slug(String slug);

  CreateCircleTemplateRequest themeCode(String themeCode);

  CreateCircleTemplateRequest title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCircleTemplateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCircleTemplateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCircleTemplateRequest call({
    String? artMediaId,
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
    >
    assets,
    String creatorId,
    String description,
    String slug,
    String themeCode,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateCircleTemplateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateCircleTemplateRequest.copyWith.fieldName(...)`
class _$CreateCircleTemplateRequestCWProxyImpl
    implements _$CreateCircleTemplateRequestCWProxy {
  const _$CreateCircleTemplateRequestCWProxyImpl(this._value);

  final CreateCircleTemplateRequest _value;

  @override
  CreateCircleTemplateRequest artMediaId(String? artMediaId) =>
      this(artMediaId: artMediaId);

  @override
  CreateCircleTemplateRequest assets(
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
    >
    assets,
  ) => this(assets: assets);

  @override
  CreateCircleTemplateRequest creatorId(String creatorId) =>
      this(creatorId: creatorId);

  @override
  CreateCircleTemplateRequest description(String description) =>
      this(description: description);

  @override
  CreateCircleTemplateRequest slug(String slug) => this(slug: slug);

  @override
  CreateCircleTemplateRequest themeCode(String themeCode) =>
      this(themeCode: themeCode);

  @override
  CreateCircleTemplateRequest title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateCircleTemplateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateCircleTemplateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateCircleTemplateRequest call({
    Object? artMediaId = const $CopyWithPlaceholder(),
    Object? assets = const $CopyWithPlaceholder(),
    Object? creatorId = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? themeCode = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CreateCircleTemplateRequest(
      artMediaId: artMediaId == const $CopyWithPlaceholder()
          ? _value.artMediaId
          // ignore: cast_nullable_to_non_nullable
          : artMediaId as String?,
      assets: assets == const $CopyWithPlaceholder()
          ? _value.assets
          // ignore: cast_nullable_to_non_nullable
          : assets
                as List<
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner
                >,
      creatorId: creatorId == const $CopyWithPlaceholder()
          ? _value.creatorId
          // ignore: cast_nullable_to_non_nullable
          : creatorId as String,
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      themeCode: themeCode == const $CopyWithPlaceholder()
          ? _value.themeCode
          // ignore: cast_nullable_to_non_nullable
          : themeCode as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $CreateCircleTemplateRequestCopyWith on CreateCircleTemplateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateCircleTemplateRequest.copyWith(...)` or like so:`instanceOfCreateCircleTemplateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateCircleTemplateRequestCWProxy get copyWith =>
      _$CreateCircleTemplateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCircleTemplateRequest _$CreateCircleTemplateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateCircleTemplateRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'assets',
        'creator_id',
        'description',
        'slug',
        'theme_code',
        'title',
      ],
    );
    final val = CreateCircleTemplateRequest(
      artMediaId: $checkedConvert('art_media_id', (v) => v as String?),
      assets: $checkedConvert(
        'assets',
        (v) => (v as List<dynamic>)
            .map(
              (e) =>
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf4AssetsInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
            )
            .toList(),
      ),
      creatorId: $checkedConvert('creator_id', (v) => v as String),
      description: $checkedConvert('description', (v) => v as String),
      slug: $checkedConvert('slug', (v) => v as String),
      themeCode: $checkedConvert('theme_code', (v) => v as String),
      title: $checkedConvert('title', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'artMediaId': 'art_media_id',
    'creatorId': 'creator_id',
    'themeCode': 'theme_code',
  },
);

Map<String, dynamic> _$CreateCircleTemplateRequestToJson(
  CreateCircleTemplateRequest instance,
) => <String, dynamic>{
  'art_media_id': ?instance.artMediaId,
  'assets': instance.assets.map((e) => e.toJson()).toList(),
  'creator_id': instance.creatorId,
  'description': instance.description,
  'slug': instance.slug,
  'theme_code': instance.themeCode,
  'title': instance.title,
};
