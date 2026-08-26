//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'simulation_result.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SimulationResult {
  /// Returns a new [SimulationResult] instance.
  SimulationResult({
    required this.commandId,

    required this.demo,

    required this.ledgerTransactionIds,

    required this.portfolioVersion,

    required this.projectionLinks,

    required this.status,

    required this.summary,
  });

  @JsonKey(name: r'command_id', required: true, includeIfNull: false)
  final String commandId;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(
    name: r'ledger_transaction_ids',
    required: true,
    includeIfNull: false,
  )
  final List<String> ledgerTransactionIds;

  // minimum: 0
  @JsonKey(name: r'portfolio_version', required: true, includeIfNull: false)
  final int portfolioVersion;

  @JsonKey(name: r'projection_links', required: true, includeIfNull: false)
  final List<String> projectionLinks;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SimulationResultStatusEnum.unknownDefaultOpenApi,
  )
  final SimulationResultStatusEnum status;

  @JsonKey(name: r'summary', required: true, includeIfNull: false)
  final Map<String, Object?> summary;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimulationResult &&
          other.commandId == commandId &&
          other.demo == demo &&
          other.ledgerTransactionIds == ledgerTransactionIds &&
          other.portfolioVersion == portfolioVersion &&
          other.projectionLinks == projectionLinks &&
          other.status == status &&
          other.summary == summary;

  @override
  int get hashCode =>
      commandId.hashCode +
      demo.hashCode +
      ledgerTransactionIds.hashCode +
      portfolioVersion.hashCode +
      projectionLinks.hashCode +
      status.hashCode +
      summary.hashCode;

  factory SimulationResult.fromJson(Map<String, dynamic> json) =>
      _$SimulationResultFromJson(json);

  Map<String, dynamic> toJson() => _$SimulationResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SimulationResultStatusEnum {
  @JsonValue(r'committed')
  committed(r'committed'),
  @JsonValue(r'rejected')
  rejected(r'rejected'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SimulationResultStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
