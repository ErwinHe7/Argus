// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grimoire_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GrimoireSummaryCWProxy {
  GrimoireSummary curatorLabel(String curatorLabel);

  GrimoireSummary demo(ResearchDisclosure demo);

  GrimoireSummary description(String description);

  GrimoireSummary id(String id);

  GrimoireSummary revisionId(String revisionId);

  GrimoireSummary slug(String slug);

  GrimoireSummary theme(String theme);

  GrimoireSummary title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GrimoireSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GrimoireSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  GrimoireSummary call({
    String curatorLabel,
    ResearchDisclosure demo,
    String description,
    String id,
    String revisionId,
    String slug,
    String theme,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGrimoireSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGrimoireSummary.copyWith.fieldName(...)`
class _$GrimoireSummaryCWProxyImpl implements _$GrimoireSummaryCWProxy {
  const _$GrimoireSummaryCWProxyImpl(this._value);

  final GrimoireSummary _value;

  @override
  GrimoireSummary curatorLabel(String curatorLabel) =>
      this(curatorLabel: curatorLabel);

  @override
  GrimoireSummary demo(ResearchDisclosure demo) => this(demo: demo);

  @override
  GrimoireSummary description(String description) =>
      this(description: description);

  @override
  GrimoireSummary id(String id) => this(id: id);

  @override
  GrimoireSummary revisionId(String revisionId) => this(revisionId: revisionId);

  @override
  GrimoireSummary slug(String slug) => this(slug: slug);

  @override
  GrimoireSummary theme(String theme) => this(theme: theme);

  @override
  GrimoireSummary title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GrimoireSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GrimoireSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  GrimoireSummary call({
    Object? curatorLabel = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? theme = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return GrimoireSummary(
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

extension $GrimoireSummaryCopyWith on GrimoireSummary {
  /// Returns a callable class that can be used as follows: `instanceOfGrimoireSummary.copyWith(...)` or like so:`instanceOfGrimoireSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GrimoireSummaryCWProxy get copyWith => _$GrimoireSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GrimoireSummary _$GrimoireSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'GrimoireSummary',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'curator_label',
            'demo',
            'description',
            'id',
            'revision_id',
            'slug',
            'theme',
            'title',
          ],
        );
        final val = GrimoireSummary(
          curatorLabel: $checkedConvert('curator_label', (v) => v as String),
          demo: $checkedConvert(
            'demo',
            (v) => ResearchDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          description: $checkedConvert('description', (v) => v as String),
          id: $checkedConvert('id', (v) => v as String),
          revisionId: $checkedConvert('revision_id', (v) => v as String),
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

Map<String, dynamic> _$GrimoireSummaryToJson(GrimoireSummary instance) =>
    <String, dynamic>{
      'curator_label': instance.curatorLabel,
      'demo': instance.demo.toJson(),
      'description': instance.description,
      'id': instance.id,
      'revision_id': instance.revisionId,
      'slug': instance.slug,
      'theme': instance.theme,
      'title': instance.title,
    };
