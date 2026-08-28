//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'research_disclosure.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ResearchDisclosure {
  /// Returns a new [ResearchDisclosure] instance.
  ResearchDisclosure({
    required this.isDemo,

    required this.limitations,

    required this.observedAt,

    required this.sourceLabel,
  });

  @JsonKey(name: r'is_demo', required: true, includeIfNull: false)
  final bool isDemo;

  @JsonKey(name: r'limitations', required: true, includeIfNull: false)
  final List<String> limitations;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: false)
  final DateTime observedAt;

  @JsonKey(name: r'source_label', required: true, includeIfNull: false)
  final String sourceLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResearchDisclosure &&
          other.isDemo == isDemo &&
          other.limitations == limitations &&
          other.observedAt == observedAt &&
          other.sourceLabel == sourceLabel;

  @override
  int get hashCode =>
      isDemo.hashCode +
      limitations.hashCode +
      observedAt.hashCode +
      sourceLabel.hashCode;

  factory ResearchDisclosure.fromJson(Map<String, dynamic> json) =>
      _$ResearchDisclosureFromJson(json);

  Map<String, dynamic> toJson() => _$ResearchDisclosureToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
