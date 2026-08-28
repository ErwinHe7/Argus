//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/research_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/coven_qualification.dart';
import 'package:ritual_investing_api_client/generated/model/evidence_detail.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'coven_entry_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CovenEntryDetail {
  /// Returns a new [CovenEntryDetail] instance.
  CovenEntryDetail({
    required this.category,

    required this.company,

    required this.demo,

    required this.effectiveDate,

    required this.evidence,

    required this.focus,

    required this.id,

    required this.inclusionRationale,

    required this.limitations,

    required this.qualifications,

    required this.revisionId,

    required this.saved,

    required this.slug,

    required this.summary,

    required this.symbol,

    required this.teaser,

    required this.verifiedAsOf,
  });

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CovenEntryDetailCategoryEnum.unknownDefaultOpenApi,
  )
  final CovenEntryDetailCategoryEnum category;

  @JsonKey(name: r'company', required: true, includeIfNull: false)
  final String company;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final ResearchDisclosure demo;

  @JsonKey(name: r'effective_date', required: true, includeIfNull: false)
  final DateTime effectiveDate;

  @JsonKey(name: r'evidence', required: true, includeIfNull: false)
  final List<EvidenceDetail> evidence;

  @JsonKey(name: r'focus', required: true, includeIfNull: false)
  final String focus;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'inclusion_rationale', required: true, includeIfNull: false)
  final String inclusionRationale;

  @JsonKey(name: r'limitations', required: true, includeIfNull: false)
  final String limitations;

  @JsonKey(name: r'qualifications', required: true, includeIfNull: false)
  final List<CovenQualification> qualifications;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'saved', required: true, includeIfNull: false)
  final bool saved;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final String summary;

  @JsonKey(name: r'symbol', required: true, includeIfNull: true)
  final String? symbol;

  @JsonKey(name: r'teaser', required: true, includeIfNull: false)
  final String teaser;

  @JsonKey(name: r'verified_as_of', required: true, includeIfNull: false)
  final DateTime verifiedAsOf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CovenEntryDetail &&
          other.category == category &&
          other.company == company &&
          other.demo == demo &&
          other.effectiveDate == effectiveDate &&
          other.evidence == evidence &&
          other.focus == focus &&
          other.id == id &&
          other.inclusionRationale == inclusionRationale &&
          other.limitations == limitations &&
          other.qualifications == qualifications &&
          other.revisionId == revisionId &&
          other.saved == saved &&
          other.slug == slug &&
          other.summary == summary &&
          other.symbol == symbol &&
          other.teaser == teaser &&
          other.verifiedAsOf == verifiedAsOf;

  @override
  int get hashCode =>
      category.hashCode +
      company.hashCode +
      demo.hashCode +
      effectiveDate.hashCode +
      evidence.hashCode +
      focus.hashCode +
      id.hashCode +
      inclusionRationale.hashCode +
      limitations.hashCode +
      qualifications.hashCode +
      revisionId.hashCode +
      saved.hashCode +
      slug.hashCode +
      summary.hashCode +
      (symbol == null ? 0 : symbol.hashCode) +
      teaser.hashCode +
      verifiedAsOf.hashCode;

  factory CovenEntryDetail.fromJson(Map<String, dynamic> json) =>
      _$CovenEntryDetailFromJson(json);

  Map<String, dynamic> toJson() => _$CovenEntryDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CovenEntryDetailCategoryEnum {
  @JsonValue(r'founder')
  founder(r'founder'),
  @JsonValue(r'owner')
  owner(r'owner'),
  @JsonValue(r'chief_executive')
  chiefExecutive(r'chief_executive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CovenEntryDetailCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
