// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_discover_item_one_of1.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicDiscoverItemOneOf1CWProxy {
  PublicDiscoverItemOneOf1 category(
    PublicDiscoverItemOneOf1CategoryEnum category,
  );

  PublicDiscoverItemOneOf1 demo(DemoDisclosure demo);

  PublicDiscoverItemOneOf1 kind(PublicDiscoverItemOneOf1KindEnum kind);

  PublicDiscoverItemOneOf1 slug(String slug);

  PublicDiscoverItemOneOf1 teaser(String teaser);

  PublicDiscoverItemOneOf1 title(String title);

  PublicDiscoverItemOneOf1 verifiedAsOf(DateTime verifiedAsOf);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItemOneOf1(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItemOneOf1(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItemOneOf1 call({
    PublicDiscoverItemOneOf1CategoryEnum category,
    DemoDisclosure demo,
    PublicDiscoverItemOneOf1KindEnum kind,
    String slug,
    String teaser,
    String title,
    DateTime verifiedAsOf,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicDiscoverItemOneOf1.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicDiscoverItemOneOf1.copyWith.fieldName(...)`
class _$PublicDiscoverItemOneOf1CWProxyImpl
    implements _$PublicDiscoverItemOneOf1CWProxy {
  const _$PublicDiscoverItemOneOf1CWProxyImpl(this._value);

  final PublicDiscoverItemOneOf1 _value;

  @override
  PublicDiscoverItemOneOf1 category(
    PublicDiscoverItemOneOf1CategoryEnum category,
  ) => this(category: category);

  @override
  PublicDiscoverItemOneOf1 demo(DemoDisclosure demo) => this(demo: demo);

  @override
  PublicDiscoverItemOneOf1 kind(PublicDiscoverItemOneOf1KindEnum kind) =>
      this(kind: kind);

  @override
  PublicDiscoverItemOneOf1 slug(String slug) => this(slug: slug);

  @override
  PublicDiscoverItemOneOf1 teaser(String teaser) => this(teaser: teaser);

  @override
  PublicDiscoverItemOneOf1 title(String title) => this(title: title);

  @override
  PublicDiscoverItemOneOf1 verifiedAsOf(DateTime verifiedAsOf) =>
      this(verifiedAsOf: verifiedAsOf);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItemOneOf1(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItemOneOf1(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItemOneOf1 call({
    Object? category = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? teaser = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? verifiedAsOf = const $CopyWithPlaceholder(),
  }) {
    return PublicDiscoverItemOneOf1(
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as PublicDiscoverItemOneOf1CategoryEnum,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as PublicDiscoverItemOneOf1KindEnum,
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
      verifiedAsOf: verifiedAsOf == const $CopyWithPlaceholder()
          ? _value.verifiedAsOf
          // ignore: cast_nullable_to_non_nullable
          : verifiedAsOf as DateTime,
    );
  }
}

extension $PublicDiscoverItemOneOf1CopyWith on PublicDiscoverItemOneOf1 {
  /// Returns a callable class that can be used as follows: `instanceOfPublicDiscoverItemOneOf1.copyWith(...)` or like so:`instanceOfPublicDiscoverItemOneOf1.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicDiscoverItemOneOf1CWProxy get copyWith =>
      _$PublicDiscoverItemOneOf1CWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicDiscoverItemOneOf1 _$PublicDiscoverItemOneOf1FromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PublicDiscoverItemOneOf1', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'category',
      'demo',
      'kind',
      'slug',
      'teaser',
      'title',
      'verified_as_of',
    ],
  );
  final val = PublicDiscoverItemOneOf1(
    category: $checkedConvert(
      'category',
      (v) => $enumDecode(
        _$PublicDiscoverItemOneOf1CategoryEnumEnumMap,
        v,
        unknownValue:
            PublicDiscoverItemOneOf1CategoryEnum.unknownDefaultOpenApi,
      ),
    ),
    demo: $checkedConvert(
      'demo',
      (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
    ),
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecode(
        _$PublicDiscoverItemOneOf1KindEnumEnumMap,
        v,
        unknownValue: PublicDiscoverItemOneOf1KindEnum.unknownDefaultOpenApi,
      ),
    ),
    slug: $checkedConvert('slug', (v) => v as String),
    teaser: $checkedConvert('teaser', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    verifiedAsOf: $checkedConvert(
      'verified_as_of',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
}, fieldKeyMap: const {'verifiedAsOf': 'verified_as_of'});

Map<String, dynamic> _$PublicDiscoverItemOneOf1ToJson(
  PublicDiscoverItemOneOf1 instance,
) => <String, dynamic>{
  'category': _$PublicDiscoverItemOneOf1CategoryEnumEnumMap[instance.category]!,
  'demo': instance.demo.toJson(),
  'kind': _$PublicDiscoverItemOneOf1KindEnumEnumMap[instance.kind]!,
  'slug': instance.slug,
  'teaser': instance.teaser,
  'title': instance.title,
  'verified_as_of': instance.verifiedAsOf.toIso8601String(),
};

const _$PublicDiscoverItemOneOf1CategoryEnumEnumMap = {
  PublicDiscoverItemOneOf1CategoryEnum.founder: 'founder',
  PublicDiscoverItemOneOf1CategoryEnum.owner: 'owner',
  PublicDiscoverItemOneOf1CategoryEnum.chiefExecutive: 'chief_executive',
  PublicDiscoverItemOneOf1CategoryEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PublicDiscoverItemOneOf1KindEnumEnumMap = {
  PublicDiscoverItemOneOf1KindEnum.coven: 'coven',
  PublicDiscoverItemOneOf1KindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
