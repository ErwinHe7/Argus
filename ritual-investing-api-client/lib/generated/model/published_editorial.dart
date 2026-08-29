//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'published_editorial.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublishedEditorial {
  /// Returns a new [PublishedEditorial] instance.
  PublishedEditorial({
    required this.id,

    required this.kind,

    required this.payload,

    required this.revisionId,

    required this.revisionNumber,

    required this.slug,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'kind', required: true, includeIfNull: false)
  final String kind;

  @JsonKey(name: r'payload', required: true, includeIfNull: false)
  final Map<String, Object?> payload;

  @JsonKey(name: r'revision_id', required: true, includeIfNull: false)
  final String revisionId;

  // minimum: 0
  @JsonKey(name: r'revision_number', required: true, includeIfNull: false)
  final int revisionNumber;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublishedEditorial &&
          other.id == id &&
          other.kind == kind &&
          other.payload == payload &&
          other.revisionId == revisionId &&
          other.revisionNumber == revisionNumber &&
          other.slug == slug;

  @override
  int get hashCode =>
      id.hashCode +
      kind.hashCode +
      payload.hashCode +
      revisionId.hashCode +
      revisionNumber.hashCode +
      slug.hashCode;

  factory PublishedEditorial.fromJson(Map<String, dynamic> json) =>
      _$PublishedEditorialFromJson(json);

  Map<String, dynamic> toJson() => _$PublishedEditorialToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
