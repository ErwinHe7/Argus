// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_template_detail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleTemplateDetailCWProxy {
  CircleTemplateDetail assets(List<CircleTemplateAsset> assets);

  CircleTemplateDetail creator(SeededCreator creator);

  CircleTemplateDetail demo(ResearchDisclosure demo);

  CircleTemplateDetail description(String description);

  CircleTemplateDetail id(String id);

  CircleTemplateDetail revisionId(String revisionId);

  CircleTemplateDetail saved(bool saved);

  CircleTemplateDetail slug(String slug);

  CircleTemplateDetail theme(String theme);

  CircleTemplateDetail title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateDetail call({
    List<CircleTemplateAsset> assets,
    SeededCreator creator,
    ResearchDisclosure demo,
    String description,
    String id,
    String revisionId,
    bool saved,
    String slug,
    String theme,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleTemplateDetail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleTemplateDetail.copyWith.fieldName(...)`
class _$CircleTemplateDetailCWProxyImpl
    implements _$CircleTemplateDetailCWProxy {
  const _$CircleTemplateDetailCWProxyImpl(this._value);

  final CircleTemplateDetail _value;

  @override
  CircleTemplateDetail assets(List<CircleTemplateAsset> assets) =>
      this(assets: assets);

  @override
  CircleTemplateDetail creator(SeededCreator creator) => this(creator: creator);

  @override
  CircleTemplateDetail demo(ResearchDisclosure demo) => this(demo: demo);

  @override
  CircleTemplateDetail description(String description) =>
      this(description: description);

  @override
  CircleTemplateDetail id(String id) => this(id: id);

  @override
  CircleTemplateDetail revisionId(String revisionId) =>
      this(revisionId: revisionId);

  @override
  CircleTemplateDetail saved(bool saved) => this(saved: saved);

  @override
  CircleTemplateDetail slug(String slug) => this(slug: slug);

  @override
  CircleTemplateDetail theme(String theme) => this(theme: theme);

  @override
  CircleTemplateDetail title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateDetail call({
    Object? assets = const $CopyWithPlaceholder(),
    Object? creator = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? saved = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? theme = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CircleTemplateDetail(
      assets: assets == const $CopyWithPlaceholder()
          ? _value.assets
          // ignore: cast_nullable_to_non_nullable
          : assets as List<CircleTemplateAsset>,
      creator: creator == const $CopyWithPlaceholder()
          ? _value.creator
          // ignore: cast_nullable_to_non_nullable
          : creator as SeededCreator,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as ResearchDisclosure,
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String,
      saved: saved == const $CopyWithPlaceholder()
          ? _value.saved
          // ignore: cast_nullable_to_non_nullable
          : saved as bool,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      theme: theme == const $CopyWithPlaceholder()
          ? _value.theme
          // ignore: cast_nullable_to_non_nullable
          : theme as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $CircleTemplateDetailCopyWith on CircleTemplateDetail {
  /// Returns a callable class that can be used as follows: `instanceOfCircleTemplateDetail.copyWith(...)` or like so:`instanceOfCircleTemplateDetail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleTemplateDetailCWProxy get copyWith =>
      _$CircleTemplateDetailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleTemplateDetail _$CircleTemplateDetailFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CircleTemplateDetail', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'assets',
      'creator',
      'demo',
      'description',
      'id',
      'revision_id',
      'saved',
      'slug',
      'theme',
      'title',
    ],
  );
  final val = CircleTemplateDetail(
    assets: $checkedConvert(
      'assets',
      (v) => (v as List<dynamic>)
          .map((e) => CircleTemplateAsset.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    creator: $checkedConvert(
      'creator',
      (v) => SeededCreator.fromJson(v as Map<String, dynamic>),
    ),
    demo: $checkedConvert(
      'demo',
      (v) => ResearchDisclosure.fromJson(v as Map<String, dynamic>),
    ),
    description: $checkedConvert('description', (v) => v as String),
    id: $checkedConvert('id', (v) => v as String),
    revisionId: $checkedConvert('revision_id', (v) => v as String),
    saved: $checkedConvert('saved', (v) => v as bool),
    slug: $checkedConvert('slug', (v) => v as String),
    theme: $checkedConvert('theme', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'revisionId': 'revision_id'});

Map<String, dynamic> _$CircleTemplateDetailToJson(
  CircleTemplateDetail instance,
) => <String, dynamic>{
  'assets': instance.assets.map((e) => e.toJson()).toList(),
  'creator': instance.creator.toJson(),
  'demo': instance.demo.toJson(),
  'description': instance.description,
  'id': instance.id,
  'revision_id': instance.revisionId,
  'saved': instance.saved,
  'slug': instance.slug,
  'theme': instance.theme,
  'title': instance.title,
};
