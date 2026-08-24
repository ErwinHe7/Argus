//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'admin_evidence_source.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AdminEvidenceSource {
  /// Returns a new [AdminEvidenceSource] instance.
  AdminEvidenceSource({
    required this.canonicalUrl,

    required this.etag,

    required this.id,

    required this.publishedAt,

    required this.publisher,

    required this.retrievedAt,

    required this.sourceKind,

    required this.status,

    required this.title,

    required this.version,
  });

  @JsonKey(name: r'canonical_url', required: true, includeIfNull: false)
  final String canonicalUrl;

  @JsonKey(name: r'etag', required: true, includeIfNull: false)
  final String etag;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

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
    unknownEnumValue: AdminEvidenceSourceSourceKindEnum.unknownDefaultOpenApi,
  )
  final AdminEvidenceSourceSourceKindEnum sourceKind;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AdminEvidenceSourceStatusEnum.unknownDefaultOpenApi,
  )
  final AdminEvidenceSourceStatusEnum status;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminEvidenceSource &&
          other.canonicalUrl == canonicalUrl &&
          other.etag == etag &&
          other.id == id &&
          other.publishedAt == publishedAt &&
          other.publisher == publisher &&
          other.retrievedAt == retrievedAt &&
          other.sourceKind == sourceKind &&
          other.status == status &&
          other.title == title &&
          other.version == version;

  @override
  int get hashCode =>
      canonicalUrl.hashCode +
      etag.hashCode +
      id.hashCode +
      (publishedAt == null ? 0 : publishedAt.hashCode) +
      publisher.hashCode +
      retrievedAt.hashCode +
      sourceKind.hashCode +
      status.hashCode +
      title.hashCode +
      version.hashCode;

  factory AdminEvidenceSource.fromJson(Map<String, dynamic> json) =>
      _$AdminEvidenceSourceFromJson(json);

  Map<String, dynamic> toJson() => _$AdminEvidenceSourceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum AdminEvidenceSourceSourceKindEnum {
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

  const AdminEvidenceSourceSourceKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum AdminEvidenceSourceStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'retired')
  retired(r'retired'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AdminEvidenceSourceStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
