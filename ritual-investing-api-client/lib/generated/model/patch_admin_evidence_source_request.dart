//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_admin_evidence_source_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchAdminEvidenceSourceRequest {
  /// Returns a new [PatchAdminEvidenceSourceRequest] instance.
  PatchAdminEvidenceSourceRequest({
    this.canonicalUrl,

    this.publishedAt,

    this.publisher,

    this.retrievedAt,

    this.sourceKind,

    this.status,

    this.title,
  });

  @JsonKey(name: r'canonical_url', required: false, includeIfNull: false)
  final String? canonicalUrl;

  @JsonKey(name: r'published_at', required: false, includeIfNull: false)
  final DateTime? publishedAt;

  @JsonKey(name: r'publisher', required: false, includeIfNull: false)
  final String? publisher;

  @JsonKey(name: r'retrieved_at', required: false, includeIfNull: false)
  final DateTime? retrievedAt;

  @JsonKey(
    name: r'source_kind',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PatchAdminEvidenceSourceRequestSourceKindEnum.unknownDefaultOpenApi,
  )
  final PatchAdminEvidenceSourceRequestSourceKindEnum? sourceKind;

  @JsonKey(
    name: r'status',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PatchAdminEvidenceSourceRequestStatusEnum.unknownDefaultOpenApi,
  )
  final PatchAdminEvidenceSourceRequestStatusEnum? status;

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchAdminEvidenceSourceRequest &&
          other.canonicalUrl == canonicalUrl &&
          other.publishedAt == publishedAt &&
          other.publisher == publisher &&
          other.retrievedAt == retrievedAt &&
          other.sourceKind == sourceKind &&
          other.status == status &&
          other.title == title;

  @override
  int get hashCode =>
      canonicalUrl.hashCode +
      (publishedAt == null ? 0 : publishedAt.hashCode) +
      publisher.hashCode +
      retrievedAt.hashCode +
      sourceKind.hashCode +
      status.hashCode +
      title.hashCode;

  factory PatchAdminEvidenceSourceRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchAdminEvidenceSourceRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchAdminEvidenceSourceRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PatchAdminEvidenceSourceRequestSourceKindEnum {
  @JsonValue(r'filing')
  filing(r'filing'),
  @JsonValue(r'company')
  company(r'company'),
  @JsonValue(r'exchange')
  exchange(r'exchange'),
  @JsonValue(r'research')
  research(r'research'),
  @JsonValue(r'news')
  news(r'news'),
  @JsonValue(r'other')
  other(r'other'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchAdminEvidenceSourceRequestSourceKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum PatchAdminEvidenceSourceRequestStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'retired')
  retired(r'retired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchAdminEvidenceSourceRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
