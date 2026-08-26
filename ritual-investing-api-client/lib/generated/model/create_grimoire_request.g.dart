// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_grimoire_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateGrimoireRequestCWProxy {
  CreateGrimoireRequest artMediaId(String? artMediaId);

  CreateGrimoireRequest assets(
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
    >
    assets,
  );

  CreateGrimoireRequest curatorLabel(String curatorLabel);

  CreateGrimoireRequest description(String description);

  CreateGrimoireRequest slug(String slug);

  CreateGrimoireRequest themeCode(String themeCode);

  CreateGrimoireRequest title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateGrimoireRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateGrimoireRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateGrimoireRequest call({
    String? artMediaId,
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
    >
    assets,
    String curatorLabel,
    String description,
    String slug,
    String themeCode,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateGrimoireRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateGrimoireRequest.copyWith.fieldName(...)`
class _$CreateGrimoireRequestCWProxyImpl
    implements _$CreateGrimoireRequestCWProxy {
  const _$CreateGrimoireRequestCWProxyImpl(this._value);

  final CreateGrimoireRequest _value;

  @override
  CreateGrimoireRequest artMediaId(String? artMediaId) =>
      this(artMediaId: artMediaId);

  @override
  CreateGrimoireRequest assets(
    List<
      ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
    >
    assets,
  ) => this(assets: assets);

  @override
  CreateGrimoireRequest curatorLabel(String curatorLabel) =>
      this(curatorLabel: curatorLabel);

  @override
  CreateGrimoireRequest description(String description) =>
      this(description: description);

  @override
  CreateGrimoireRequest slug(String slug) => this(slug: slug);

  @override
  CreateGrimoireRequest themeCode(String themeCode) =>
      this(themeCode: themeCode);

  @override
  CreateGrimoireRequest title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateGrimoireRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateGrimoireRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateGrimoireRequest call({
    Object? artMediaId = const $CopyWithPlaceholder(),
    Object? assets = const $CopyWithPlaceholder(),
    Object? curatorLabel = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? themeCode = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CreateGrimoireRequest(
      artMediaId: artMediaId == const $CopyWithPlaceholder()
          ? _value.artMediaId
          // ignore: cast_nullable_to_non_nullable
          : artMediaId as String?,
      assets: assets == const $CopyWithPlaceholder()
          ? _value.assets
          // ignore: cast_nullable_to_non_nullable
          : assets
                as List<
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner
                >,
      curatorLabel: curatorLabel == const $CopyWithPlaceholder()
          ? _value.curatorLabel
          // ignore: cast_nullable_to_non_nullable
          : curatorLabel as String,
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

extension $CreateGrimoireRequestCopyWith on CreateGrimoireRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateGrimoireRequest.copyWith(...)` or like so:`instanceOfCreateGrimoireRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateGrimoireRequestCWProxy get copyWith =>
      _$CreateGrimoireRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateGrimoireRequest _$CreateGrimoireRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateGrimoireRequest',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'assets',
        'curator_label',
        'description',
        'slug',
        'theme_code',
        'title',
      ],
    );
    final val = CreateGrimoireRequest(
      artMediaId: $checkedConvert('art_media_id', (v) => v as String?),
      assets: $checkedConvert(
        'assets',
        (v) => (v as List<dynamic>)
            .map(
              (e) =>
                  ListAdminAssetCodex200ResponseDataInnerRevisionPayloadAnyOf3AssetsInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
            )
            .toList(),
      ),
      curatorLabel: $checkedConvert('curator_label', (v) => v as String),
      description: $checkedConvert('description', (v) => v as String),
      slug: $checkedConvert('slug', (v) => v as String),
      themeCode: $checkedConvert('theme_code', (v) => v as String),
      title: $checkedConvert('title', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'artMediaId': 'art_media_id',
    'curatorLabel': 'curator_label',
    'themeCode': 'theme_code',
  },
);

Map<String, dynamic> _$CreateGrimoireRequestToJson(
  CreateGrimoireRequest instance,
) => <String, dynamic>{
  'art_media_id': ?instance.artMediaId,
  'assets': instance.assets.map((e) => e.toJson()).toList(),
  'curator_label': instance.curatorLabel,
  'description': instance.description,
  'slug': instance.slug,
  'theme_code': instance.themeCode,
  'title': instance.title,
};
