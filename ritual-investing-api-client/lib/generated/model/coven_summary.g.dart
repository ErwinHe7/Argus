// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coven_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CovenSummaryCWProxy {
  CovenSummary category(CovenSummaryCategoryEnum category);

  CovenSummary company(String company);

  CovenSummary demo(DemoDisclosure demo);

  CovenSummary effectiveDate(DateTime effectiveDate);

  CovenSummary id(String id);

  CovenSummary revisionId(String revisionId);

  CovenSummary slug(String slug);

  CovenSummary teaser(String teaser);

  CovenSummary verifiedAsOf(DateTime verifiedAsOf);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenSummary call({
    CovenSummaryCategoryEnum category,
    String company,
    DemoDisclosure demo,
    DateTime effectiveDate,
    String id,
    String revisionId,
    String slug,
    String teaser,
    DateTime verifiedAsOf,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCovenSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCovenSummary.copyWith.fieldName(...)`
class _$CovenSummaryCWProxyImpl implements _$CovenSummaryCWProxy {
  const _$CovenSummaryCWProxyImpl(this._value);

  final CovenSummary _value;

  @override
  CovenSummary category(CovenSummaryCategoryEnum category) =>
      this(category: category);

  @override
  CovenSummary company(String company) => this(company: company);

  @override
  CovenSummary demo(DemoDisclosure demo) => this(demo: demo);

  @override
  CovenSummary effectiveDate(DateTime effectiveDate) =>
      this(effectiveDate: effectiveDate);

  @override
  CovenSummary id(String id) => this(id: id);

  @override
  CovenSummary revisionId(String revisionId) => this(revisionId: revisionId);

  @override
  CovenSummary slug(String slug) => this(slug: slug);

  @override
  CovenSummary teaser(String teaser) => this(teaser: teaser);

  @override
  CovenSummary verifiedAsOf(DateTime verifiedAsOf) =>
      this(verifiedAsOf: verifiedAsOf);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenSummary call({
    Object? category = const $CopyWithPlaceholder(),
    Object? company = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? effectiveDate = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? teaser = const $CopyWithPlaceholder(),
    Object? verifiedAsOf = const $CopyWithPlaceholder(),
  }) {
    return CovenSummary(
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as CovenSummaryCategoryEnum,
      company: company == const $CopyWithPlaceholder()
          ? _value.company
          // ignore: cast_nullable_to_non_nullable
          : company as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      effectiveDate: effectiveDate == const $CopyWithPlaceholder()
          ? _value.effectiveDate
          // ignore: cast_nullable_to_non_nullable
          : effectiveDate as DateTime,
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

extension $CovenSummaryCopyWith on CovenSummary {
  /// Returns a callable class that can be used as follows: `instanceOfCovenSummary.copyWith(...)` or like so:`instanceOfCovenSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CovenSummaryCWProxy get copyWith => _$CovenSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CovenSummary _$CovenSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CovenSummary',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'category',
            'company',
            'demo',
            'effective_date',
            'id',
            'revision_id',
            'slug',
            'teaser',
            'verified_as_of',
          ],
        );
        final val = CovenSummary(
          category: $checkedConvert(
            'category',
            (v) => $enumDecode(
              _$CovenSummaryCategoryEnumEnumMap,
              v,
              unknownValue: CovenSummaryCategoryEnum.unknownDefaultOpenApi,
            ),
          ),
          company: $checkedConvert('company', (v) => v as String),
          demo: $checkedConvert(
            'demo',
            (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          effectiveDate: $checkedConvert(
            'effective_date',
            (v) => DateTime.parse(v as String),
          ),
          id: $checkedConvert('id', (v) => v as String),
          revisionId: $checkedConvert('revision_id', (v) => v as String),
          slug: $checkedConvert('slug', (v) => v as String),
          teaser: $checkedConvert('teaser', (v) => v as String),
          verifiedAsOf: $checkedConvert(
            'verified_as_of',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'effectiveDate': 'effective_date',
        'revisionId': 'revision_id',
        'verifiedAsOf': 'verified_as_of',
      },
    );

Map<String, dynamic> _$CovenSummaryToJson(CovenSummary instance) =>
    <String, dynamic>{
      'category': _$CovenSummaryCategoryEnumEnumMap[instance.category]!,
      'company': instance.company,
      'demo': instance.demo.toJson(),
      'effective_date': instance.effectiveDate.toIso8601String(),
      'id': instance.id,
      'revision_id': instance.revisionId,
      'slug': instance.slug,
      'teaser': instance.teaser,
      'verified_as_of': instance.verifiedAsOf.toIso8601String(),
    };

const _$CovenSummaryCategoryEnumEnumMap = {
  CovenSummaryCategoryEnum.founder: 'founder',
  CovenSummaryCategoryEnum.owner: 'owner',
  CovenSummaryCategoryEnum.chiefExecutive: 'chief_executive',
  CovenSummaryCategoryEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
