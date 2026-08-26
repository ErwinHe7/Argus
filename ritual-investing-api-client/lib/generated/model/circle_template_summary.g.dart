// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_template_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleTemplateSummaryCWProxy {
  CircleTemplateSummary creator(SeededCreator creator);

  CircleTemplateSummary demo(DemoDisclosure demo);

  CircleTemplateSummary description(String description);

  CircleTemplateSummary id(String id);

  CircleTemplateSummary revisionId(String revisionId);

  CircleTemplateSummary slug(String slug);

  CircleTemplateSummary theme(String theme);

  CircleTemplateSummary title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateSummary call({
    SeededCreator creator,
    DemoDisclosure demo,
    String description,
    String id,
    String revisionId,
    String slug,
    String theme,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleTemplateSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleTemplateSummary.copyWith.fieldName(...)`
class _$CircleTemplateSummaryCWProxyImpl
    implements _$CircleTemplateSummaryCWProxy {
  const _$CircleTemplateSummaryCWProxyImpl(this._value);

  final CircleTemplateSummary _value;

  @override
  CircleTemplateSummary creator(SeededCreator creator) =>
      this(creator: creator);

  @override
  CircleTemplateSummary demo(DemoDisclosure demo) => this(demo: demo);

  @override
  CircleTemplateSummary description(String description) =>
      this(description: description);

  @override
  CircleTemplateSummary id(String id) => this(id: id);

  @override
  CircleTemplateSummary revisionId(String revisionId) =>
      this(revisionId: revisionId);

  @override
  CircleTemplateSummary slug(String slug) => this(slug: slug);

  @override
  CircleTemplateSummary theme(String theme) => this(theme: theme);

  @override
  CircleTemplateSummary title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateSummary call({
    Object? creator = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? theme = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return CircleTemplateSummary(
      creator: creator == const $CopyWithPlaceholder()
          ? _value.creator
          // ignore: cast_nullable_to_non_nullable
          : creator as SeededCreator,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
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

extension $CircleTemplateSummaryCopyWith on CircleTemplateSummary {
  /// Returns a callable class that can be used as follows: `instanceOfCircleTemplateSummary.copyWith(...)` or like so:`instanceOfCircleTemplateSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleTemplateSummaryCWProxy get copyWith =>
      _$CircleTemplateSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleTemplateSummary _$CircleTemplateSummaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CircleTemplateSummary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'creator',
      'demo',
      'description',
      'id',
      'revision_id',
      'slug',
      'theme',
      'title',
    ],
  );
  final val = CircleTemplateSummary(
    creator: $checkedConvert(
      'creator',
      (v) => SeededCreator.fromJson(v as Map<String, dynamic>),
    ),
    demo: $checkedConvert(
      'demo',
      (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
    ),
    description: $checkedConvert('description', (v) => v as String),
    id: $checkedConvert('id', (v) => v as String),
    revisionId: $checkedConvert('revision_id', (v) => v as String),
    slug: $checkedConvert('slug', (v) => v as String),
    theme: $checkedConvert('theme', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'revisionId': 'revision_id'});

Map<String, dynamic> _$CircleTemplateSummaryToJson(
  CircleTemplateSummary instance,
) => <String, dynamic>{
  'creator': instance.creator.toJson(),
  'demo': instance.demo.toJson(),
  'description': instance.description,
  'id': instance.id,
  'revision_id': instance.revisionId,
  'slug': instance.slug,
  'theme': instance.theme,
  'title': instance.title,
};
