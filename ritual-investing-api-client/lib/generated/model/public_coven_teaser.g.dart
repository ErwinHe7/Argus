// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_coven_teaser.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicCovenTeaserCWProxy {
  PublicCovenTeaser category(PublicCovenTeaserCategoryEnum category);

  PublicCovenTeaser company(String company);

  PublicCovenTeaser demo(DemoDisclosure demo);

  PublicCovenTeaser slug(String slug);

  PublicCovenTeaser teaser(String teaser);

  PublicCovenTeaser verifiedAsOf(DateTime verifiedAsOf);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicCovenTeaser(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicCovenTeaser(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicCovenTeaser call({
    PublicCovenTeaserCategoryEnum category,
    String company,
    DemoDisclosure demo,
    String slug,
    String teaser,
    DateTime verifiedAsOf,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicCovenTeaser.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicCovenTeaser.copyWith.fieldName(...)`
class _$PublicCovenTeaserCWProxyImpl implements _$PublicCovenTeaserCWProxy {
  const _$PublicCovenTeaserCWProxyImpl(this._value);

  final PublicCovenTeaser _value;

  @override
  PublicCovenTeaser category(PublicCovenTeaserCategoryEnum category) =>
      this(category: category);

  @override
  PublicCovenTeaser company(String company) => this(company: company);

  @override
  PublicCovenTeaser demo(DemoDisclosure demo) => this(demo: demo);

  @override
  PublicCovenTeaser slug(String slug) => this(slug: slug);

  @override
  PublicCovenTeaser teaser(String teaser) => this(teaser: teaser);

  @override
  PublicCovenTeaser verifiedAsOf(DateTime verifiedAsOf) =>
      this(verifiedAsOf: verifiedAsOf);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicCovenTeaser(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicCovenTeaser(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicCovenTeaser call({
    Object? category = const $CopyWithPlaceholder(),
    Object? company = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? teaser = const $CopyWithPlaceholder(),
    Object? verifiedAsOf = const $CopyWithPlaceholder(),
  }) {
    return PublicCovenTeaser(
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as PublicCovenTeaserCategoryEnum,
      company: company == const $CopyWithPlaceholder()
          ? _value.company
          // ignore: cast_nullable_to_non_nullable
          : company as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      teaser: teaser == const $CopyWithPlaceholder()
          ? _value.teaser
          // ignore: cast_nullable_to_non_nullable
          : teaser as String,
      verifiedAsOf: verifiedAsOf == const $CopyWithPlaceholder()
          ? _value.verifiedAsOf
          // ignore: cast_nullable_to_non_nullable
          : verifiedAsOf as DateTime,
    );
  }
}

extension $PublicCovenTeaserCopyWith on PublicCovenTeaser {
  /// Returns a callable class that can be used as follows: `instanceOfPublicCovenTeaser.copyWith(...)` or like so:`instanceOfPublicCovenTeaser.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicCovenTeaserCWProxy get copyWith =>
      _$PublicCovenTeaserCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicCovenTeaser _$PublicCovenTeaserFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PublicCovenTeaser', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'category',
          'company',
          'demo',
          'slug',
          'teaser',
          'verified_as_of',
        ],
      );
      final val = PublicCovenTeaser(
        category: $checkedConvert(
          'category',
          (v) => $enumDecode(
            _$PublicCovenTeaserCategoryEnumEnumMap,
            v,
            unknownValue: PublicCovenTeaserCategoryEnum.unknownDefaultOpenApi,
          ),
        ),
        company: $checkedConvert('company', (v) => v as String),
        demo: $checkedConvert(
          'demo',
          (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
        ),
        slug: $checkedConvert('slug', (v) => v as String),
        teaser: $checkedConvert('teaser', (v) => v as String),
        verifiedAsOf: $checkedConvert(
          'verified_as_of',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    }, fieldKeyMap: const {'verifiedAsOf': 'verified_as_of'});

Map<String, dynamic> _$PublicCovenTeaserToJson(PublicCovenTeaser instance) =>
    <String, dynamic>{
      'category': _$PublicCovenTeaserCategoryEnumEnumMap[instance.category]!,
      'company': instance.company,
      'demo': instance.demo.toJson(),
      'slug': instance.slug,
      'teaser': instance.teaser,
      'verified_as_of': instance.verifiedAsOf.toIso8601String(),
    };

const _$PublicCovenTeaserCategoryEnumEnumMap = {
  PublicCovenTeaserCategoryEnum.founder: 'founder',
  PublicCovenTeaserCategoryEnum.owner: 'owner',
  PublicCovenTeaserCategoryEnum.chiefExecutive: 'chief_executive',
  PublicCovenTeaserCategoryEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
