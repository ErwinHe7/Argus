// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_discover_item_one_of2.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicDiscoverItemOneOf2CWProxy {
  PublicDiscoverItemOneOf2 demo(DemoDisclosure demo);

  PublicDiscoverItemOneOf2 kind(PublicDiscoverItemOneOf2KindEnum kind);

  PublicDiscoverItemOneOf2 slug(String slug);

  PublicDiscoverItemOneOf2 teaser(String teaser);

  PublicDiscoverItemOneOf2 title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItemOneOf2(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItemOneOf2(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItemOneOf2 call({
    DemoDisclosure demo,
    PublicDiscoverItemOneOf2KindEnum kind,
    String slug,
    String teaser,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicDiscoverItemOneOf2.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicDiscoverItemOneOf2.copyWith.fieldName(...)`
class _$PublicDiscoverItemOneOf2CWProxyImpl
    implements _$PublicDiscoverItemOneOf2CWProxy {
  const _$PublicDiscoverItemOneOf2CWProxyImpl(this._value);

  final PublicDiscoverItemOneOf2 _value;

  @override
  PublicDiscoverItemOneOf2 demo(DemoDisclosure demo) => this(demo: demo);

  @override
  PublicDiscoverItemOneOf2 kind(PublicDiscoverItemOneOf2KindEnum kind) =>
      this(kind: kind);

  @override
  PublicDiscoverItemOneOf2 slug(String slug) => this(slug: slug);

  @override
  PublicDiscoverItemOneOf2 teaser(String teaser) => this(teaser: teaser);

  @override
  PublicDiscoverItemOneOf2 title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItemOneOf2(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItemOneOf2(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItemOneOf2 call({
    Object? demo = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? teaser = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return PublicDiscoverItemOneOf2(
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as PublicDiscoverItemOneOf2KindEnum,
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

extension $PublicDiscoverItemOneOf2CopyWith on PublicDiscoverItemOneOf2 {
  /// Returns a callable class that can be used as follows: `instanceOfPublicDiscoverItemOneOf2.copyWith(...)` or like so:`instanceOfPublicDiscoverItemOneOf2.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicDiscoverItemOneOf2CWProxy get copyWith =>
      _$PublicDiscoverItemOneOf2CWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicDiscoverItemOneOf2 _$PublicDiscoverItemOneOf2FromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PublicDiscoverItemOneOf2', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['demo', 'kind', 'slug', 'teaser', 'title'],
  );
  final val = PublicDiscoverItemOneOf2(
    demo: $checkedConvert(
      'demo',
      (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
    ),
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecode(
        _$PublicDiscoverItemOneOf2KindEnumEnumMap,
        v,
        unknownValue: PublicDiscoverItemOneOf2KindEnum.unknownDefaultOpenApi,
      ),
    ),
    slug: $checkedConvert('slug', (v) => v as String),
    teaser: $checkedConvert('teaser', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$PublicDiscoverItemOneOf2ToJson(
  PublicDiscoverItemOneOf2 instance,
) => <String, dynamic>{
  'demo': instance.demo.toJson(),
  'kind': _$PublicDiscoverItemOneOf2KindEnumEnumMap[instance.kind]!,
  'slug': instance.slug,
  'teaser': instance.teaser,
  'title': instance.title,
};

const _$PublicDiscoverItemOneOf2KindEnumEnumMap = {
  PublicDiscoverItemOneOf2KindEnum.grimoire: 'grimoire',
  PublicDiscoverItemOneOf2KindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
