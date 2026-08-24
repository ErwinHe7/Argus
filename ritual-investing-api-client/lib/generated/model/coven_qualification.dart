//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/evidence_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'coven_qualification.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CovenQualification {
  /// Returns a new [CovenQualification] instance.
  CovenQualification({
    required this.category,

    required this.effectiveDate,

    required this.evidence,

    required this.personName,

    required this.validTo,

    required this.verifiedAsOf,
  });

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CovenQualificationCategoryEnum.unknownDefaultOpenApi,
  )
  final CovenQualificationCategoryEnum category;

  @JsonKey(name: r'effective_date', required: true, includeIfNull: false)
  final DateTime effectiveDate;

  @JsonKey(name: r'evidence', required: true, includeIfNull: false)
  final List<EvidenceSummary> evidence;

  @JsonKey(name: r'person_name', required: true, includeIfNull: false)
  final String personName;

  @JsonKey(name: r'valid_to', required: true, includeIfNull: true)
  final DateTime? validTo;

  @JsonKey(name: r'verified_as_of', required: true, includeIfNull: false)
  final DateTime verifiedAsOf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CovenQualification &&
          other.category == category &&
          other.effectiveDate == effectiveDate &&
          other.evidence == evidence &&
          other.personName == personName &&
          other.validTo == validTo &&
          other.verifiedAsOf == verifiedAsOf;

  @override
  int get hashCode =>
      category.hashCode +
      effectiveDate.hashCode +
      evidence.hashCode +
      personName.hashCode +
      (validTo == null ? 0 : validTo.hashCode) +
      verifiedAsOf.hashCode;

  factory CovenQualification.fromJson(Map<String, dynamic> json) =>
      _$CovenQualificationFromJson(json);

  Map<String, dynamic> toJson() => _$CovenQualificationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CovenQualificationCategoryEnum {
  @JsonValue(r'founder')
  founder(r'founder'),
  @JsonValue(r'owner')
  owner(r'owner'),
  @JsonValue(r'chief_executive')
  chiefExecutive(r'chief_executive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CovenQualificationCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
