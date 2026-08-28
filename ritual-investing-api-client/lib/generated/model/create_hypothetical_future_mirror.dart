//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/scenario_money.dart';
import 'package:ritual_investing_api_client/generated/model/create_hypothetical_future_mirror_annual_return_bps.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_hypothetical_future_mirror.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateHypotheticalFutureMirror {
  /// Returns a new [CreateHypotheticalFutureMirror] instance.
  CreateHypotheticalFutureMirror({
    required this.annualReturnBps,

    required this.asOfDate,

    required this.baseline,

    required this.monthlyContribution,

    required this.name,
  });

  @JsonKey(name: r'annual_return_bps', required: true, includeIfNull: false)
  final CreateHypotheticalFutureMirrorAnnualReturnBps annualReturnBps;

  @JsonKey(name: r'as_of_date', required: true, includeIfNull: false)
  final DateTime asOfDate;

  @JsonKey(name: r'baseline', required: true, includeIfNull: false)
  final ScenarioMoney baseline;

  @JsonKey(name: r'monthly_contribution', required: true, includeIfNull: false)
  final ScenarioMoney monthlyContribution;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateHypotheticalFutureMirror &&
          other.annualReturnBps == annualReturnBps &&
          other.asOfDate == asOfDate &&
          other.baseline == baseline &&
          other.monthlyContribution == monthlyContribution &&
          other.name == name;

  @override
  int get hashCode =>
      annualReturnBps.hashCode +
      asOfDate.hashCode +
      baseline.hashCode +
      monthlyContribution.hashCode +
      name.hashCode;

  factory CreateHypotheticalFutureMirror.fromJson(Map<String, dynamic> json) =>
      _$CreateHypotheticalFutureMirrorFromJson(json);

  Map<String, dynamic> toJson() => _$CreateHypotheticalFutureMirrorToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
