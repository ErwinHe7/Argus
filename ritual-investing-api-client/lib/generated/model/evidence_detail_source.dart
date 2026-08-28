//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'evidence_detail_source.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EvidenceDetailSource {
  /// Returns a new [EvidenceDetailSource] instance.
  EvidenceDetailSource({
    required this.publishedAt,

    required this.publisher,

    required this.title,

    required this.url,
  });

  @JsonKey(name: r'published_at', required: true, includeIfNull: true)
  final DateTime? publishedAt;

  @JsonKey(name: r'publisher', required: true, includeIfNull: false)
  final String publisher;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'url', required: true, includeIfNull: true)
  final String? url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvidenceDetailSource &&
          other.publishedAt == publishedAt &&
          other.publisher == publisher &&
          other.title == title &&
          other.url == url;

  @override
  int get hashCode =>
      (publishedAt == null ? 0 : publishedAt.hashCode) +
      publisher.hashCode +
      title.hashCode +
      (url == null ? 0 : url.hashCode);

  factory EvidenceDetailSource.fromJson(Map<String, dynamic> json) =>
      _$EvidenceDetailSourceFromJson(json);

  Map<String, dynamic> toJson() => _$EvidenceDetailSourceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
