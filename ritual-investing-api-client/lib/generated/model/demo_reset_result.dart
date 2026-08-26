//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/demo_reset_result_entitlement.dart';
import 'package:ritual_investing_api_client/generated/model/demo_reset_result_default_portfolio.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'demo_reset_result.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DemoResetResult {
  /// Returns a new [DemoResetResult] instance.
  DemoResetResult({
    required this.defaultPortfolio,

    required this.demo,

    required this.entitlement,

    required this.resetGeneration,
  });

  @JsonKey(name: r'default_portfolio', required: true, includeIfNull: false)
  final DemoResetResultDefaultPortfolio defaultPortfolio;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'entitlement', required: true, includeIfNull: false)
  final DemoResetResultEntitlement entitlement;

  // minimum: 0
  @JsonKey(name: r'reset_generation', required: true, includeIfNull: false)
  final int resetGeneration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoResetResult &&
          other.defaultPortfolio == defaultPortfolio &&
          other.demo == demo &&
          other.entitlement == entitlement &&
          other.resetGeneration == resetGeneration;

  @override
  int get hashCode =>
      defaultPortfolio.hashCode +
      demo.hashCode +
      entitlement.hashCode +
      resetGeneration.hashCode;

  factory DemoResetResult.fromJson(Map<String, dynamic> json) =>
      _$DemoResetResultFromJson(json);

  Map<String, dynamic> toJson() => _$DemoResetResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
