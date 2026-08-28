//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/briefing_section.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'briefing_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BriefingDetail {
  /// Returns a new [BriefingDetail] instance.
  BriefingDetail({
    required this.briefingType,

    required this.generatedAt,

    required this.generation,

    required this.id,

    required this.periodEnd,

    required this.periodStart,

    required this.readAt,

    required this.sections,

    required this.sourceSequence,
  });

  @JsonKey(
    name: r'briefing_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BriefingDetailBriefingTypeEnum.unknownDefaultOpenApi,
  )
  final BriefingDetailBriefingTypeEnum briefingType;

  @JsonKey(name: r'generated_at', required: true, includeIfNull: false)
  final DateTime generatedAt;

  // minimum: 0
  @JsonKey(name: r'generation', required: true, includeIfNull: false)
  final int generation;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'period_end', required: true, includeIfNull: false)
  final DateTime periodEnd;

  @JsonKey(name: r'period_start', required: true, includeIfNull: false)
  final DateTime periodStart;

  @JsonKey(name: r'read_at', required: true, includeIfNull: true)
  final DateTime? readAt;

  @JsonKey(name: r'sections', required: true, includeIfNull: false)
  final List<BriefingSection> sections;

  // minimum: 0
  @JsonKey(name: r'source_sequence', required: true, includeIfNull: false)
  final int sourceSequence;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BriefingDetail &&
          other.briefingType == briefingType &&
          other.generatedAt == generatedAt &&
          other.generation == generation &&
          other.id == id &&
          other.periodEnd == periodEnd &&
          other.periodStart == periodStart &&
          other.readAt == readAt &&
          other.sections == sections &&
          other.sourceSequence == sourceSequence;

  @override
  int get hashCode =>
      briefingType.hashCode +
      generatedAt.hashCode +
      generation.hashCode +
      id.hashCode +
      periodEnd.hashCode +
      periodStart.hashCode +
      (readAt == null ? 0 : readAt.hashCode) +
      sections.hashCode +
      sourceSequence.hashCode;

  factory BriefingDetail.fromJson(Map<String, dynamic> json) =>
      _$BriefingDetailFromJson(json);

  Map<String, dynamic> toJson() => _$BriefingDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BriefingDetailBriefingTypeEnum {
  @JsonValue(r'daily')
  daily(r'daily'),
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'moon_cycle')
  moonCycle(r'moon_cycle'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BriefingDetailBriefingTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
