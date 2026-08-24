// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_discover_item_one_of.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicDiscoverItemOneOfCWProxy {
  PublicDiscoverItemOneOf demo(DemoDisclosure demo);

  PublicDiscoverItemOneOf kind(PublicDiscoverItemOneOfKindEnum kind);

  PublicDiscoverItemOneOf slug(String slug);

  PublicDiscoverItemOneOf symbol(String symbol);

  PublicDiscoverItemOneOf teaser(String teaser);

  PublicDiscoverItemOneOf title(String title);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItemOneOf(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItemOneOf(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItemOneOf call({
    DemoDisclosure demo,
    PublicDiscoverItemOneOfKindEnum kind,
    String slug,
    String symbol,
    String teaser,
    String title,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicDiscoverItemOneOf.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicDiscoverItemOneOf.copyWith.fieldName(...)`
class _$PublicDiscoverItemOneOfCWProxyImpl
    implements _$PublicDiscoverItemOneOfCWProxy {
  const _$PublicDiscoverItemOneOfCWProxyImpl(this._value);

  final PublicDiscoverItemOneOf _value;

  @override
  PublicDiscoverItemOneOf demo(DemoDisclosure demo) => this(demo: demo);

  @override
  PublicDiscoverItemOneOf kind(PublicDiscoverItemOneOfKindEnum kind) =>
      this(kind: kind);

  @override
  PublicDiscoverItemOneOf slug(String slug) => this(slug: slug);

  @override
  PublicDiscoverItemOneOf symbol(String symbol) => this(symbol: symbol);

  @override
  PublicDiscoverItemOneOf teaser(String teaser) => this(teaser: teaser);

  @override
  PublicDiscoverItemOneOf title(String title) => this(title: title);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItemOneOf(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItemOneOf(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItemOneOf call({
    Object? demo = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
    Object? teaser = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
  }) {
    return PublicDiscoverItemOneOf(
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as PublicDiscoverItemOneOfKindEnum,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
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

extension $PublicDiscoverItemOneOfCopyWith on PublicDiscoverItemOneOf {
  /// Returns a callable class that can be used as follows: `instanceOfPublicDiscoverItemOneOf.copyWith(...)` or like so:`instanceOfPublicDiscoverItemOneOf.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicDiscoverItemOneOfCWProxy get copyWith =>
      _$PublicDiscoverItemOneOfCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicDiscoverItemOneOf _$PublicDiscoverItemOneOfFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PublicDiscoverItemOneOf', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['demo', 'kind', 'slug', 'symbol', 'teaser', 'title'],
  );
  final val = PublicDiscoverItemOneOf(
    demo: $checkedConvert(
      'demo',
      (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
    ),
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecode(
        _$PublicDiscoverItemOneOfKindEnumEnumMap,
        v,
        unknownValue: PublicDiscoverItemOneOfKindEnum.unknownDefaultOpenApi,
      ),
    ),
    slug: $checkedConvert('slug', (v) => v as String),
    symbol: $checkedConvert('symbol', (v) => v as String),
    teaser: $checkedConvert('teaser', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$PublicDiscoverItemOneOfToJson(
  PublicDiscoverItemOneOf instance,
) => <String, dynamic>{
  'demo': instance.demo.toJson(),
  'kind': _$PublicDiscoverItemOneOfKindEnumEnumMap[instance.kind]!,
  'slug': instance.slug,
  'symbol': instance.symbol,
  'teaser': instance.teaser,
  'title': instance.title,
};

const _$PublicDiscoverItemOneOfKindEnumEnumMap = {
  PublicDiscoverItemOneOfKindEnum.asset: 'asset',
  PublicDiscoverItemOneOfKindEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
