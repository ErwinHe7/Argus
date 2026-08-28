// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grimoire_detail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GrimoireDetailCWProxy {
  GrimoireDetail assets(List<AssetSummary> assets);

  GrimoireDetail curatorLabel(String curatorLabel);

  GrimoireDetail demo(ResearchDisclosure demo);

  GrimoireDetail description(String description);

  GrimoireDetail id(String id);

  GrimoireDetail revisionId(String revisionId);

  GrimoireDetail saved(bool saved);

  GrimoireDetail slug(String slug);

  GrimoireDetail theme(String theme);

  GrimoireDetail title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GrimoireDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GrimoireDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  GrimoireDetail call({
    List<AssetSummary> assets,
    String curatorLabel,
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

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGrimoireDetail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGrimoireDetail.copyWith.fieldName(...)`
class _$GrimoireDetailCWProxyImpl implements _$GrimoireDetailCWProxy {
  const _$GrimoireDetailCWProxyImpl(this._value);

  final GrimoireDetail _value;

  @override
  GrimoireDetail assets(List<AssetSummary> assets) => this(assets: assets);

  @override
  GrimoireDetail curatorLabel(String curatorLabel) =>
      this(curatorLabel: curatorLabel);

  @override
  GrimoireDetail demo(ResearchDisclosure demo) => this(demo: demo);

  @override
  GrimoireDetail description(String description) =>
      this(description: description);

  @override
  GrimoireDetail id(String id) => this(id: id);

  @override
  GrimoireDetail revisionId(String revisionId) => this(revisionId: revisionId);

  @override
  GrimoireDetail saved(bool saved) => this(saved: saved);

  @override
  GrimoireDetail slug(String slug) => this(slug: slug);

  @override
  GrimoireDetail theme(String theme) => this(theme: theme);

  @override
  GrimoireDetail title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GrimoireDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GrimoireDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  GrimoireDetail call({
    Object? assets = const $CopyWithPlaceholder(),
    Object? curatorLabel = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? saved = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? theme = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return GrimoireDetail(
      assets: assets == const $CopyWithPlaceholder()
          ? _value.assets
          // ignore: cast_nullable_to_non_nullable
          : assets as List<AssetSummary>,
      curatorLabel: curatorLabel == const $CopyWithPlaceholder()
          ? _value.curatorLabel
          // ignore: cast_nullable_to_non_nullable
          : curatorLabel as String,
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

extension $GrimoireDetailCopyWith on GrimoireDetail {
  /// Returns a callable class that can be used as follows: `instanceOfGrimoireDetail.copyWith(...)` or like so:`instanceOfGrimoireDetail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GrimoireDetailCWProxy get copyWith => _$GrimoireDetailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GrimoireDetail _$GrimoireDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'GrimoireDetail',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'assets',
            'curator_label',
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
        final val = GrimoireDetail(
          assets: $checkedConvert(
            'assets',
            (v) => (v as List<dynamic>)
                .map((e) => AssetSummary.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
          curatorLabel: $checkedConvert('curator_label', (v) => v as String),
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
      },
      fieldKeyMap: const {
        'curatorLabel': 'curator_label',
        'revisionId': 'revision_id',
      },
    );

Map<String, dynamic> _$GrimoireDetailToJson(GrimoireDetail instance) =>
    <String, dynamic>{
      'assets': instance.assets.map((e) => e.toJson()).toList(),
      'curator_label': instance.curatorLabel,
      'demo': instance.demo.toJson(),
      'description': instance.description,
      'id': instance.id,
      'revision_id': instance.revisionId,
      'saved': instance.saved,
      'slug': instance.slug,
      'theme': instance.theme,
      'title': instance.title,
    };
