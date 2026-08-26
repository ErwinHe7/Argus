//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_coven_entry_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateCovenEntryRequest {
  /// Returns a new [CreateCovenEntryRequest] instance.
  CreateCovenEntryRequest({
    required this.companyId,

    required this.inclusionRationale,

    required this.limitations,

    required this.slug,

    required this.summary,
  });

  @JsonKey(name: r'company_id', required: true, includeIfNull: false)
  final String companyId;

  @JsonKey(name: r'inclusion_rationale', required: true, includeIfNull: false)
  final String inclusionRationale;

  @JsonKey(name: r'limitations', required: true, includeIfNull: false)
  final String limitations;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final String summary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateCovenEntryRequest &&
          other.companyId == companyId &&
          other.inclusionRationale == inclusionRationale &&
          other.limitations == limitations &&
          other.slug == slug &&
          other.summary == summary;

  @override
  int get hashCode =>
      companyId.hashCode +
      inclusionRationale.hashCode +
      limitations.hashCode +
      slug.hashCode +
      summary.hashCode;

  factory CreateCovenEntryRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCovenEntryRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateCovenEntryRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
