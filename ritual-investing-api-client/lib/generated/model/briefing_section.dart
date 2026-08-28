//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'briefing_section.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BriefingSection {
  /// Returns a new [BriefingSection] instance.
  BriefingSection({
    required this.disclosure,

    required this.ordinal,

    required this.schemaVersion,

    required this.sourceSequence,
  });

  @JsonKey(name: r'disclosure', required: true, includeIfNull: false)
  final String disclosure;

  // minimum: 0
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  // minimum: 0
  @JsonKey(name: r'schema_version', required: true, includeIfNull: false)
  final int schemaVersion;

  // minimum: 0
  @JsonKey(name: r'source_sequence', required: true, includeIfNull: false)
  final int sourceSequence;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BriefingSection &&
          other.disclosure == disclosure &&
          other.ordinal == ordinal &&
          other.schemaVersion == schemaVersion &&
          other.sourceSequence == sourceSequence;

  @override
  int get hashCode =>
      disclosure.hashCode +
      ordinal.hashCode +
      schemaVersion.hashCode +
      sourceSequence.hashCode;

  factory BriefingSection.fromJson(Map<String, dynamic> json) =>
      _$BriefingSectionFromJson(json);

  Map<String, dynamic> toJson() => _$BriefingSectionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
