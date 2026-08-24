// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coven_entry_detail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CovenEntryDetailCWProxy {
  CovenEntryDetail company(String company);

  CovenEntryDetail demo(DemoDisclosure demo);

  CovenEntryDetail id(String id);

  CovenEntryDetail inclusionRationale(String inclusionRationale);

  CovenEntryDetail limitations(String limitations);

  CovenEntryDetail qualifications(List<CovenQualification> qualifications);

  CovenEntryDetail revisionId(String revisionId);

  CovenEntryDetail saved(bool saved);

  CovenEntryDetail slug(String slug);

  CovenEntryDetail summary(String summary);

  CovenEntryDetail symbol(String? symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenEntryDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenEntryDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenEntryDetail call({
    String company,
    DemoDisclosure demo,
    String id,
    String inclusionRationale,
    String limitations,
    List<CovenQualification> qualifications,
    String revisionId,
    bool saved,
    String slug,
    String summary,
    String? symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCovenEntryDetail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCovenEntryDetail.copyWith.fieldName(...)`
class _$CovenEntryDetailCWProxyImpl implements _$CovenEntryDetailCWProxy {
  const _$CovenEntryDetailCWProxyImpl(this._value);

  final CovenEntryDetail _value;

  @override
  CovenEntryDetail company(String company) => this(company: company);

  @override
  CovenEntryDetail demo(DemoDisclosure demo) => this(demo: demo);

  @override
  CovenEntryDetail id(String id) => this(id: id);

  @override
  CovenEntryDetail inclusionRationale(String inclusionRationale) =>
      this(inclusionRationale: inclusionRationale);

  @override
  CovenEntryDetail limitations(String limitations) =>
      this(limitations: limitations);

  @override
  CovenEntryDetail qualifications(List<CovenQualification> qualifications) =>
      this(qualifications: qualifications);

  @override
  CovenEntryDetail revisionId(String revisionId) =>
      this(revisionId: revisionId);

  @override
  CovenEntryDetail saved(bool saved) => this(saved: saved);

  @override
  CovenEntryDetail slug(String slug) => this(slug: slug);

  @override
  CovenEntryDetail summary(String summary) => this(summary: summary);

  @override
  CovenEntryDetail symbol(String? symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenEntryDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenEntryDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenEntryDetail call({
    Object? company = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? inclusionRationale = const $CopyWithPlaceholder(),
    Object? limitations = const $CopyWithPlaceholder(),
    Object? qualifications = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? saved = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? summary = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return CovenEntryDetail(
      company: company == const $CopyWithPlaceholder()
          ? _value.company
          // ignore: cast_nullable_to_non_nullable
          : company as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      inclusionRationale: inclusionRationale == const $CopyWithPlaceholder()
          ? _value.inclusionRationale
          // ignore: cast_nullable_to_non_nullable
          : inclusionRationale as String,
      limitations: limitations == const $CopyWithPlaceholder()
          ? _value.limitations
          // ignore: cast_nullable_to_non_nullable
          : limitations as String,
      qualifications: qualifications == const $CopyWithPlaceholder()
          ? _value.qualifications
          // ignore: cast_nullable_to_non_nullable
          : qualifications as List<CovenQualification>,
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
      summary: summary == const $CopyWithPlaceholder()
          ? _value.summary
          // ignore: cast_nullable_to_non_nullable
          : summary as String,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String?,
    );
  }
}

extension $CovenEntryDetailCopyWith on CovenEntryDetail {
  /// Returns a callable class that can be used as follows: `instanceOfCovenEntryDetail.copyWith(...)` or like so:`instanceOfCovenEntryDetail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CovenEntryDetailCWProxy get copyWith => _$CovenEntryDetailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CovenEntryDetail _$CovenEntryDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CovenEntryDetail',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'company',
            'demo',
            'id',
            'inclusion_rationale',
            'limitations',
            'qualifications',
            'revision_id',
            'saved',
            'slug',
            'summary',
            'symbol',
          ],
        );
        final val = CovenEntryDetail(
          company: $checkedConvert('company', (v) => v as String),
          demo: $checkedConvert(
            'demo',
            (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          id: $checkedConvert('id', (v) => v as String),
          inclusionRationale: $checkedConvert(
            'inclusion_rationale',
            (v) => v as String,
          ),
          limitations: $checkedConvert('limitations', (v) => v as String),
          qualifications: $checkedConvert(
            'qualifications',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => CovenQualification.fromJson(e as Map<String, dynamic>),
                )
                .toList(),
          ),
          revisionId: $checkedConvert('revision_id', (v) => v as String),
          saved: $checkedConvert('saved', (v) => v as bool),
          slug: $checkedConvert('slug', (v) => v as String),
          summary: $checkedConvert('summary', (v) => v as String),
          symbol: $checkedConvert('symbol', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'inclusionRationale': 'inclusion_rationale',
        'revisionId': 'revision_id',
      },
    );

Map<String, dynamic> _$CovenEntryDetailToJson(CovenEntryDetail instance) =>
    <String, dynamic>{
      'company': instance.company,
      'demo': instance.demo.toJson(),
      'id': instance.id,
      'inclusion_rationale': instance.inclusionRationale,
      'limitations': instance.limitations,
      'qualifications': instance.qualifications.map((e) => e.toJson()).toList(),
      'revision_id': instance.revisionId,
      'saved': instance.saved,
      'slug': instance.slug,
      'summary': instance.summary,
      'symbol': instance.symbol,
    };
