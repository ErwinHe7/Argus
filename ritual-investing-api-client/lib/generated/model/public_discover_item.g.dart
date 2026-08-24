// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_discover_item.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicDiscoverItemCWProxy {
  PublicDiscoverItem demo(DemoDisclosure demo);

  PublicDiscoverItem kind(PublicDiscoverItemKindEnum kind);

  PublicDiscoverItem slug(String slug);

  PublicDiscoverItem symbol(String symbol);

  PublicDiscoverItem teaser(String teaser);

  PublicDiscoverItem title(String title);

  PublicDiscoverItem category(PublicDiscoverItemCategoryEnum category);

  PublicDiscoverItem verifiedAsOf(DateTime verifiedAsOf);

  PublicDiscoverItem creatorLabel(String creatorLabel);

  PublicDiscoverItem isFictional(bool isFictional);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItem(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItem call({
    DemoDisclosure demo,
    PublicDiscoverItemKindEnum kind,
    String slug,
    String symbol,
    String teaser,
    String title,
    PublicDiscoverItemCategoryEnum category,
    DateTime verifiedAsOf,
    String creatorLabel,
    bool isFictional,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicDiscoverItem.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicDiscoverItem.copyWith.fieldName(...)`
class _$PublicDiscoverItemCWProxyImpl implements _$PublicDiscoverItemCWProxy {
  const _$PublicDiscoverItemCWProxyImpl(this._value);

  final PublicDiscoverItem _value;

  @override
  PublicDiscoverItem demo(DemoDisclosure demo) => this(demo: demo);

  @override
  PublicDiscoverItem kind(PublicDiscoverItemKindEnum kind) => this(kind: kind);

  @override
  PublicDiscoverItem slug(String slug) => this(slug: slug);

  @override
  PublicDiscoverItem symbol(String symbol) => this(symbol: symbol);

  @override
  PublicDiscoverItem teaser(String teaser) => this(teaser: teaser);

  @override
  PublicDiscoverItem title(String title) => this(title: title);

  @override
  PublicDiscoverItem category(PublicDiscoverItemCategoryEnum category) =>
      this(category: category);

  @override
  PublicDiscoverItem verifiedAsOf(DateTime verifiedAsOf) =>
      this(verifiedAsOf: verifiedAsOf);

  @override
  PublicDiscoverItem creatorLabel(String creatorLabel) =>
      this(creatorLabel: creatorLabel);

  @override
  PublicDiscoverItem isFictional(bool isFictional) =>
      this(isFictional: isFictional);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicDiscoverItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicDiscoverItem(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicDiscoverItem call({
    Object? demo = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
    Object? teaser = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? verifiedAsOf = const $CopyWithPlaceholder(),
    Object? creatorLabel = const $CopyWithPlaceholder(),
    Object? isFictional = const $CopyWithPlaceholder(),
  }) {
    return PublicDiscoverItem(
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as PublicDiscoverItemKindEnum,
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
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as PublicDiscoverItemCategoryEnum,
      verifiedAsOf: verifiedAsOf == const $CopyWithPlaceholder()
          ? _value.verifiedAsOf
          // ignore: cast_nullable_to_non_nullable
          : verifiedAsOf as DateTime,
      creatorLabel: creatorLabel == const $CopyWithPlaceholder()
          ? _value.creatorLabel
          // ignore: cast_nullable_to_non_nullable
          : creatorLabel as String,
      isFictional: isFictional == const $CopyWithPlaceholder()
          ? _value.isFictional
          // ignore: cast_nullable_to_non_nullable
          : isFictional as bool,
    );
  }
}

extension $PublicDiscoverItemCopyWith on PublicDiscoverItem {
  /// Returns a callable class that can be used as follows: `instanceOfPublicDiscoverItem.copyWith(...)` or like so:`instanceOfPublicDiscoverItem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicDiscoverItemCWProxy get copyWith =>
      _$PublicDiscoverItemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicDiscoverItem _$PublicDiscoverItemFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PublicDiscoverItem',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'demo',
            'kind',
            'slug',
            'symbol',
            'teaser',
            'title',
            'category',
            'verified_as_of',
            'creator_label',
            'is_fictional',
          ],
        );
        final val = PublicDiscoverItem(
          demo: $checkedConvert(
            'demo',
            (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          kind: $checkedConvert(
            'kind',
            (v) => $enumDecode(
              _$PublicDiscoverItemKindEnumEnumMap,
              v,
              unknownValue: PublicDiscoverItemKindEnum.unknownDefaultOpenApi,
            ),
          ),
          slug: $checkedConvert('slug', (v) => v as String),
          symbol: $checkedConvert('symbol', (v) => v as String),
          teaser: $checkedConvert('teaser', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          category: $checkedConvert(
            'category',
            (v) => $enumDecode(
              _$PublicDiscoverItemCategoryEnumEnumMap,
              v,
              unknownValue:
                  PublicDiscoverItemCategoryEnum.unknownDefaultOpenApi,
            ),
          ),
          verifiedAsOf: $checkedConvert(
            'verified_as_of',
            (v) => DateTime.parse(v as String),
          ),
          creatorLabel: $checkedConvert('creator_label', (v) => v as String),
          isFictional: $checkedConvert('is_fictional', (v) => v as bool),
        );
        return val;
      },
      fieldKeyMap: const {
        'verifiedAsOf': 'verified_as_of',
        'creatorLabel': 'creator_label',
        'isFictional': 'is_fictional',
      },
    );

Map<String, dynamic> _$PublicDiscoverItemToJson(PublicDiscoverItem instance) =>
    <String, dynamic>{
      'demo': instance.demo.toJson(),
      'kind': _$PublicDiscoverItemKindEnumEnumMap[instance.kind]!,
      'slug': instance.slug,
      'symbol': instance.symbol,
      'teaser': instance.teaser,
      'title': instance.title,
      'category': _$PublicDiscoverItemCategoryEnumEnumMap[instance.category]!,
      'verified_as_of': instance.verifiedAsOf.toIso8601String(),
      'creator_label': instance.creatorLabel,
      'is_fictional': instance.isFictional,
    };

const _$PublicDiscoverItemKindEnumEnumMap = {
  PublicDiscoverItemKindEnum.circleTemplate: 'circle_template',
  PublicDiscoverItemKindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$PublicDiscoverItemCategoryEnumEnumMap = {
  PublicDiscoverItemCategoryEnum.founder: 'founder',
  PublicDiscoverItemCategoryEnum.owner: 'owner',
  PublicDiscoverItemCategoryEnum.chiefExecutive: 'chief_executive',
  PublicDiscoverItemCategoryEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
