//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_admin_evidence_source_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateAdminEvidenceSourceRequest {
  /// Returns a new [CreateAdminEvidenceSourceRequest] instance.
  CreateAdminEvidenceSourceRequest({
    required this.canonicalUrl,

    required this.publishedAt,

    required this.publisher,

    required this.retrievedAt,

    required this.sourceKind,

    required this.status,

    required this.title,
  });

  @JsonKey(name: r'canonical_url', required: true, includeIfNull: false)
  final String canonicalUrl;

  @JsonKey(name: r'published_at', required: true, includeIfNull: true)
  final DateTime? publishedAt;

  @JsonKey(name: r'publisher', required: true, includeIfNull: false)
  final String publisher;

  @JsonKey(name: r'retrieved_at', required: true, includeIfNull: false)
  final DateTime retrievedAt;

  @JsonKey(
    name: r'source_kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateAdminEvidenceSourceRequestSourceKindEnum.unknownDefaultOpenApi,
  )
  final CreateAdminEvidenceSourceRequestSourceKindEnum sourceKind;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateAdminEvidenceSourceRequestStatusEnum.unknownDefaultOpenApi,
  )
  final CreateAdminEvidenceSourceRequestStatusEnum status;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateAdminEvidenceSourceRequest &&
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

  factory CreateAdminEvidenceSourceRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateAdminEvidenceSourceRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateAdminEvidenceSourceRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateAdminEvidenceSourceRequestSourceKindEnum {
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

  const CreateAdminEvidenceSourceRequestSourceKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CreateAdminEvidenceSourceRequestStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'retired')
  retired(r'retired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateAdminEvidenceSourceRequestStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
