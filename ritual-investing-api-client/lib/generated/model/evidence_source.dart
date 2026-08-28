//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'evidence_source.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EvidenceSource {
  /// Returns a new [EvidenceSource] instance.
  EvidenceSource({
    required this.canonicalUrl,

    required this.publishedAt,

    required this.publisher,

    required this.retrievedAt,

    required this.sourceKind,

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

  @JsonKey(name: r'source_kind', required: true, includeIfNull: false)
  final String sourceKind;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceSource &&
          other.canonicalUrl == canonicalUrl &&
          other.publishedAt == publishedAt &&
          other.publisher == publisher &&
          other.retrievedAt == retrievedAt &&
          other.sourceKind == sourceKind &&
          other.title == title;

  @override
  int get hashCode =>
      canonicalUrl.hashCode +
      (publishedAt == null ? 0 : publishedAt.hashCode) +
      publisher.hashCode +
      retrievedAt.hashCode +
      sourceKind.hashCode +
      title.hashCode;

  factory EvidenceSource.fromJson(Map<String, dynamic> json) =>
      _$EvidenceSourceFromJson(json);

  Map<String, dynamic> toJson() => _$EvidenceSourceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
