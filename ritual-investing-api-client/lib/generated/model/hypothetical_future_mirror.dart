//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/hypothetical_future_mirror_annual_return_bps.dart';
import 'package:ritual_investing_api_client/generated/model/scenario_money.dart';
import 'package:ritual_investing_api_client/generated/model/hypothetical_future_mirror_point.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hypothetical_future_mirror.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HypotheticalFutureMirror {
  /// Returns a new [HypotheticalFutureMirror] instance.
  HypotheticalFutureMirror({
    required this.annualReturnBps,

    required this.asOfDate,

    required this.assumptionVersion,

    required this.baseline,

    required this.generatedAt,

    required this.id,

    required this.inputHash,

    required this.intentionId,

    required this.modelVersion,

    required this.monthlyContribution,

    required this.name,

    required this.points,

    required this.targetDate,

    required this.uncertaintyDisclosure,
  });

  @JsonKey(name: r'annual_return_bps', required: true, includeIfNull: false)
  final HypotheticalFutureMirrorAnnualReturnBps annualReturnBps;

  @JsonKey(name: r'as_of_date', required: true, includeIfNull: false)
  final DateTime asOfDate;

  @JsonKey(name: r'assumption_version', required: true, includeIfNull: false)
  final String assumptionVersion;

  @JsonKey(name: r'baseline', required: true, includeIfNull: false)
  final ScenarioMoney baseline;

  @JsonKey(name: r'generated_at', required: true, includeIfNull: false)
  final DateTime generatedAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'input_hash', required: true, includeIfNull: false)
  final String inputHash;

  @JsonKey(name: r'intention_id', required: true, includeIfNull: false)
  final String intentionId;

  @JsonKey(name: r'model_version', required: true, includeIfNull: false)
  final String modelVersion;

  @JsonKey(name: r'monthly_contribution', required: true, includeIfNull: false)
  final ScenarioMoney monthlyContribution;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'points', required: true, includeIfNull: false)
  final List<HypotheticalFutureMirrorPoint> points;

  @JsonKey(name: r'target_date', required: true, includeIfNull: false)
  final DateTime targetDate;

  @JsonKey(
    name: r'uncertainty_disclosure',
    required: true,
    includeIfNull: false,
  )
  final String uncertaintyDisclosure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HypotheticalFutureMirror &&
          other.annualReturnBps == annualReturnBps &&
          other.asOfDate == asOfDate &&
          other.assumptionVersion == assumptionVersion &&
          other.baseline == baseline &&
          other.generatedAt == generatedAt &&
          other.id == id &&
          other.inputHash == inputHash &&
          other.intentionId == intentionId &&
          other.modelVersion == modelVersion &&
          other.monthlyContribution == monthlyContribution &&
          other.name == name &&
          other.points == points &&
          other.targetDate == targetDate &&
          other.uncertaintyDisclosure == uncertaintyDisclosure;

  @override
  int get hashCode =>
      annualReturnBps.hashCode +
      asOfDate.hashCode +
      assumptionVersion.hashCode +
      baseline.hashCode +
      generatedAt.hashCode +
      id.hashCode +
      inputHash.hashCode +
      intentionId.hashCode +
      modelVersion.hashCode +
      monthlyContribution.hashCode +
      name.hashCode +
      points.hashCode +
      targetDate.hashCode +
      uncertaintyDisclosure.hashCode;

  factory HypotheticalFutureMirror.fromJson(Map<String, dynamic> json) =>
      _$HypotheticalFutureMirrorFromJson(json);

  Map<String, dynamic> toJson() => _$HypotheticalFutureMirrorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
