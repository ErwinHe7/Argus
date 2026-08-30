//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/starpath_evidence.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'starpath_factual_section.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StarpathFactualSection {
  /// Returns a new [StarpathFactualSection] instance.
  StarpathFactualSection({
    required this.body,

    required this.evidence,

    required this.heading,

    required this.kind,

    required this.observedAt,

    required this.ordinal,

    required this.uncertainty,
  });

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'evidence', required: true, includeIfNull: false)
  final List<StarpathEvidence> evidence;

  @JsonKey(name: r'heading', required: true, includeIfNull: false)
  final String heading;

  @JsonKey(
    name: r'kind',
    required: true,
    includeIfNull: false,
    unknownEnumValue: StarpathFactualSectionKindEnum.unknownDefaultOpenApi,
  )
  final StarpathFactualSectionKindEnum kind;

  @JsonKey(name: r'observed_at', required: true, includeIfNull: false)
  final DateTime observedAt;

  // minimum: 1
  // maximum: 12
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  @JsonKey(name: r'uncertainty', required: true, includeIfNull: false)
  final String uncertainty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StarpathFactualSection &&
          other.body == body &&
          other.evidence == evidence &&
          other.heading == heading &&
          other.kind == kind &&
          other.observedAt == observedAt &&
          other.ordinal == ordinal &&
          other.uncertainty == uncertainty;

  @override
  int get hashCode =>
      body.hashCode +
      evidence.hashCode +
      heading.hashCode +
      kind.hashCode +
      observedAt.hashCode +
      ordinal.hashCode +
      uncertainty.hashCode;

  factory StarpathFactualSection.fromJson(Map<String, dynamic> json) =>
      _$StarpathFactualSectionFromJson(json);

  Map<String, dynamic> toJson() => _$StarpathFactualSectionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum StarpathFactualSectionKindEnum {
  @JsonValue(r'fact')
  fact(r'fact'),
  @JsonValue(r'neutral_example')
  neutralExample(r'neutral_example'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const StarpathFactualSectionKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
