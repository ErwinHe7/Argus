// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_discover_item_one_of3.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicDiscoverItemOneOf3CWProxy {
  PublicDiscoverItemOneOf3 creatorLabel(String creatorLabel);

  PublicDiscoverItemOneOf3 demo(DemoDisclosure demo);

  PublicDiscoverItemOneOf3 isFictional(bool isFictional);

  PublicDiscoverItemOneOf3 kind(PublicDiscoverItemOneOf3KindEnum kind);

  PublicDiscoverItemOneOf3 slug(String slug);

  PublicDiscoverItemOneOf3 teaser(String teaser);

  PublicDiscoverItemOneOf3 title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItemOneOf3(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItemOneOf3(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItemOneOf3 call({
    String creatorLabel,
    DemoDisclosure demo,
    bool isFictional,
    PublicDiscoverItemOneOf3KindEnum kind,
    String slug,
    String teaser,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicDiscoverItemOneOf3.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicDiscoverItemOneOf3.copyWith.fieldName(...)`
class _$PublicDiscoverItemOneOf3CWProxyImpl
    implements _$PublicDiscoverItemOneOf3CWProxy {
  const _$PublicDiscoverItemOneOf3CWProxyImpl(this._value);

  final PublicDiscoverItemOneOf3 _value;

  @override
  PublicDiscoverItemOneOf3 creatorLabel(String creatorLabel) =>
      this(creatorLabel: creatorLabel);

  @override
  PublicDiscoverItemOneOf3 demo(DemoDisclosure demo) => this(demo: demo);

  @override
  PublicDiscoverItemOneOf3 isFictional(bool isFictional) =>
      this(isFictional: isFictional);

  @override
  PublicDiscoverItemOneOf3 kind(PublicDiscoverItemOneOf3KindEnum kind) =>
      this(kind: kind);

  @override
  PublicDiscoverItemOneOf3 slug(String slug) => this(slug: slug);

  @override
  PublicDiscoverItemOneOf3 teaser(String teaser) => this(teaser: teaser);

  @override
  PublicDiscoverItemOneOf3 title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItemOneOf3(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItemOneOf3(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItemOneOf3 call({
    Object? creatorLabel = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? isFictional = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? teaser = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return PublicDiscoverItemOneOf3(
      creatorLabel: creatorLabel == const $CopyWithPlaceholder()
          ? _value.creatorLabel
          // ignore: cast_nullable_to_non_nullable
          : creatorLabel as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      isFictional: isFictional == const $CopyWithPlaceholder()
          ? _value.isFictional
          // ignore: cast_nullable_to_non_nullable
          : isFictional as bool,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as PublicDiscoverItemOneOf3KindEnum,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      teaser: teaser == const $CopyWithPlaceholder()
          ? _value.teaser
          // ignore: cast_nullable_to_non_nullable
          : teaser as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
    );
  }
}

extension $PublicDiscoverItemOneOf3CopyWith on PublicDiscoverItemOneOf3 {
  /// Returns a callable class that can be used as follows: `instanceOfPublicDiscoverItemOneOf3.copyWith(...)` or like so:`instanceOfPublicDiscoverItemOneOf3.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicDiscoverItemOneOf3CWProxy get copyWith =>
      _$PublicDiscoverItemOneOf3CWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicDiscoverItemOneOf3 _$PublicDiscoverItemOneOf3FromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PublicDiscoverItemOneOf3',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'creator_label',
        'demo',
        'is_fictional',
        'kind',
        'slug',
        'teaser',
        'title',
      ],
    );
    final val = PublicDiscoverItemOneOf3(
      creatorLabel: $checkedConvert('creator_label', (v) => v as String),
      demo: $checkedConvert(
        'demo',
        (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
      ),
      isFictional: $checkedConvert('is_fictional', (v) => v as bool),
      kind: $checkedConvert(
        'kind',
        (v) => $enumDecode(
          _$PublicDiscoverItemOneOf3KindEnumEnumMap,
          v,
          unknownValue: PublicDiscoverItemOneOf3KindEnum.unknownDefaultOpenApi,
        ),
      ),
      slug: $checkedConvert('slug', (v) => v as String),
      teaser: $checkedConvert('teaser', (v) => v as String),
      title: $checkedConvert('title', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'creatorLabel': 'creator_label',
    'isFictional': 'is_fictional',
  },
);

Map<String, dynamic> _$PublicDiscoverItemOneOf3ToJson(
  PublicDiscoverItemOneOf3 instance,
) => <String, dynamic>{
  'creator_label': instance.creatorLabel,
  'demo': instance.demo.toJson(),
  'is_fictional': instance.isFictional,
  'kind': _$PublicDiscoverItemOneOf3KindEnumEnumMap[instance.kind]!,
  'slug': instance.slug,
  'teaser': instance.teaser,
  'title': instance.title,
};

const _$PublicDiscoverItemOneOf3KindEnumEnumMap = {
  PublicDiscoverItemOneOf3KindEnum.circleTemplate: 'circle_template',
  PublicDiscoverItemOneOf3KindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
