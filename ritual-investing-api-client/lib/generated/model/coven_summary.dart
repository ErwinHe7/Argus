//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/research_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'coven_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CovenSummary {
  /// Returns a new [CovenSummary] instance.
  CovenSummary({
    required this.category,

    required this.company,

    required this.demo,

    required this.effectiveDate,

    required this.focus,

    required this.id,

    required this.revisionId,

    required this.slug,

    required this.symbol,

    required this.teaser,

    required this.verifiedAsOf,
  });

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CovenSummaryCategoryEnum.unknownDefaultOpenApi,
  )
  final CovenSummaryCategoryEnum category;

  @JsonKey(name: r'company', required: true, includeIfNull: false)
  final String company;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final ResearchDisclosure demo;

  @JsonKey(name: r'effective_date', required: true, includeIfNull: false)
  final DateTime effectiveDate;

  @JsonKey(name: r'focus', required: true, includeIfNull: false)
  final String focus;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'symbol', required: true, includeIfNull: true)
  final String? symbol;

  @JsonKey(name: r'teaser', required: true, includeIfNull: false)
  final String teaser;

  @JsonKey(name: r'verified_as_of', required: true, includeIfNull: false)
  final DateTime verifiedAsOf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CovenSummary &&
          other.category == category &&
          other.company == company &&
          other.demo == demo &&
          other.effectiveDate == effectiveDate &&
          other.focus == focus &&
          other.id == id &&
          other.revisionId == revisionId &&
          other.slug == slug &&
          other.symbol == symbol &&
          other.teaser == teaser &&
          other.verifiedAsOf == verifiedAsOf;

  @override
  int get hashCode =>
      category.hashCode +
      company.hashCode +
      demo.hashCode +
      effectiveDate.hashCode +
      focus.hashCode +
      id.hashCode +
      revisionId.hashCode +
      slug.hashCode +
      (symbol == null ? 0 : symbol.hashCode) +
      teaser.hashCode +
      verifiedAsOf.hashCode;

  factory CovenSummary.fromJson(Map<String, dynamic> json) =>
      _$CovenSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$CovenSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CovenSummaryCategoryEnum {
  @JsonValue(r'founder')
  founder(r'founder'),
  @JsonValue(r'owner')
  owner(r'owner'),
  @JsonValue(r'chief_executive')
  chiefExecutive(r'chief_executive'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CovenSummaryCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
