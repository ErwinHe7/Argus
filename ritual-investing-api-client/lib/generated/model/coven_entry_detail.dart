//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/coven_qualification.dart';
import 'package:ritual_investing_api_client/generated/model/demo_disclosure.dart';
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
    required this.company,

    required this.demo,

    required this.id,

    required this.inclusionRationale,

    required this.limitations,

    required this.qualifications,

    required this.revisionId,

    required this.saved,

    required this.slug,

    required this.summary,

    required this.symbol,
  });

  @JsonKey(name: r'company', required: true, includeIfNull: false)
  final String company;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final DemoDisclosure demo;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CovenEntryDetail &&
          other.company == company &&
          other.demo == demo &&
          other.id == id &&
          other.inclusionRationale == inclusionRationale &&
          other.limitations == limitations &&
          other.qualifications == qualifications &&
          other.revisionId == revisionId &&
          other.saved == saved &&
          other.slug == slug &&
          other.summary == summary &&
          other.symbol == symbol;

  @override
  int get hashCode =>
      company.hashCode +
      demo.hashCode +
      id.hashCode +
      inclusionRationale.hashCode +
      limitations.hashCode +
      qualifications.hashCode +
      revisionId.hashCode +
      saved.hashCode +
      slug.hashCode +
      summary.hashCode +
      (symbol == null ? 0 : symbol.hashCode);

  factory CovenEntryDetail.fromJson(Map<String, dynamic> json) =>
      _$CovenEntryDetailFromJson(json);

  Map<String, dynamic> toJson() => _$CovenEntryDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
