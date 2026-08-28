// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coven_qualification.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CovenQualificationCWProxy {
  CovenQualification category(CovenQualificationCategoryEnum category);

  CovenQualification effectiveDate(DateTime effectiveDate);

  CovenQualification evidence(List<EvidenceSummary> evidence);

  CovenQualification personName(String personName);

  CovenQualification validTo(DateTime? validTo);

  CovenQualification verifiedAsOf(DateTime verifiedAsOf);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenQualification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenQualification(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenQualification call({
    CovenQualificationCategoryEnum category,
    DateTime effectiveDate,
    List<EvidenceSummary> evidence,
    String personName,
    DateTime? validTo,
    DateTime verifiedAsOf,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCovenQualification.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCovenQualification.copyWith.fieldName(...)`
class _$CovenQualificationCWProxyImpl implements _$CovenQualificationCWProxy {
  const _$CovenQualificationCWProxyImpl(this._value);

  final CovenQualification _value;

  @override
  CovenQualification category(CovenQualificationCategoryEnum category) =>
      this(category: category);

  @override
  CovenQualification effectiveDate(DateTime effectiveDate) =>
      this(effectiveDate: effectiveDate);

  @override
  CovenQualification evidence(List<EvidenceSummary> evidence) =>
      this(evidence: evidence);

  @override
  CovenQualification personName(String personName) =>
      this(personName: personName);

  @override
  CovenQualification validTo(DateTime? validTo) => this(validTo: validTo);

  @override
  CovenQualification verifiedAsOf(DateTime verifiedAsOf) =>
      this(verifiedAsOf: verifiedAsOf);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CovenQualification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CovenQualification(...).copyWith(id: 12, name: "My name")
  /// ````
  CovenQualification call({
    Object? category = const $CopyWithPlaceholder(),
    Object? effectiveDate = const $CopyWithPlaceholder(),
    Object? evidence = const $CopyWithPlaceholder(),
    Object? personName = const $CopyWithPlaceholder(),
    Object? validTo = const $CopyWithPlaceholder(),
    Object? verifiedAsOf = const $CopyWithPlaceholder(),
  }) {
    return CovenQualification(
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as CovenQualificationCategoryEnum,
      effectiveDate: effectiveDate == const $CopyWithPlaceholder()
          ? _value.effectiveDate
          // ignore: cast_nullable_to_non_nullable
          : effectiveDate as DateTime,
      evidence: evidence == const $CopyWithPlaceholder()
          ? _value.evidence
          // ignore: cast_nullable_to_non_nullable
          : evidence as List<EvidenceSummary>,
      personName: personName == const $CopyWithPlaceholder()
          ? _value.personName
          // ignore: cast_nullable_to_non_nullable
          : personName as String,
      validTo: validTo == const $CopyWithPlaceholder()
          ? _value.validTo
          // ignore: cast_nullable_to_non_nullable
          : validTo as DateTime?,
      verifiedAsOf: verifiedAsOf == const $CopyWithPlaceholder()
          ? _value.verifiedAsOf
          // ignore: cast_nullable_to_non_nullable
          : verifiedAsOf as DateTime,
    );
  }
}

extension $CovenQualificationCopyWith on CovenQualification {
  /// Returns a callable class that can be used as follows: `instanceOfCovenQualification.copyWith(...)` or like so:`instanceOfCovenQualification.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CovenQualificationCWProxy get copyWith =>
      _$CovenQualificationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CovenQualification _$CovenQualificationFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CovenQualification',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'category',
            'effective_date',
            'evidence',
            'person_name',
            'valid_to',
            'verified_as_of',
          ],
        );
        final val = CovenQualification(
          category: $checkedConvert(
            'category',
            (v) => $enumDecode(
              _$CovenQualificationCategoryEnumEnumMap,
              v,
              unknownValue:
                  CovenQualificationCategoryEnum.unknownDefaultOpenApi,
            ),
          ),
          effectiveDate: $checkedConvert(
            'effective_date',
            (v) => DateTime.parse(v as String),
          ),
          evidence: $checkedConvert(
            'evidence',
            (v) => (v as List<dynamic>)
                .map((e) => EvidenceSummary.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
          personName: $checkedConvert('person_name', (v) => v as String),
          validTo: $checkedConvert(
            'valid_to',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          verifiedAsOf: $checkedConvert(
            'verified_as_of',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'effectiveDate': 'effective_date',
        'personName': 'person_name',
        'validTo': 'valid_to',
        'verifiedAsOf': 'verified_as_of',
      },
    );

Map<String, dynamic> _$CovenQualificationToJson(CovenQualification instance) =>
    <String, dynamic>{
      'category': _$CovenQualificationCategoryEnumEnumMap[instance.category]!,
      'effective_date': instance.effectiveDate.toIso8601String(),
      'evidence': instance.evidence.map((e) => e.toJson()).toList(),
      'person_name': instance.personName,
      'valid_to': instance.validTo?.toIso8601String(),
      'verified_as_of': instance.verifiedAsOf.toIso8601String(),
    };

const _$CovenQualificationCategoryEnumEnumMap = {
  CovenQualificationCategoryEnum.founder: 'founder',
  CovenQualificationCategoryEnum.owner: 'owner',
  CovenQualificationCategoryEnum.chiefExecutive: 'chief_executive',
  CovenQualificationCategoryEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
