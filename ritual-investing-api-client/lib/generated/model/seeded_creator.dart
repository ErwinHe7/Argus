//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/research_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'seeded_creator.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SeededCreator {
  /// Returns a new [SeededCreator] instance.
  SeededCreator({
    required this.bio,

    required this.demo,

    required this.displayName,

    required this.id,

    required this.isFictional,

    required this.slug,
  });

  @JsonKey(name: r'bio', required: true, includeIfNull: false)
  final String bio;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final ResearchDisclosure demo;

  @JsonKey(name: r'display_name', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'is_fictional', required: true, includeIfNull: false)
  final bool isFictional;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeededCreator &&
          other.bio == bio &&
          other.demo == demo &&
          other.displayName == displayName &&
          other.id == id &&
          other.isFictional == isFictional &&
          other.slug == slug;

  @override
  int get hashCode =>
      bio.hashCode +
      demo.hashCode +
      displayName.hashCode +
      id.hashCode +
      isFictional.hashCode +
      slug.hashCode;

  factory SeededCreator.fromJson(Map<String, dynamic> json) =>
      _$SeededCreatorFromJson(json);

  Map<String, dynamic> toJson() => _$SeededCreatorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
