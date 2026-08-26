//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:ritual_investing_api_client/generated/model/money.dart';
import 'package:ritual_investing_api_client/generated/model/create_recurring_plan_request_allocations_inner.dart';
import 'package:ritual_investing_api_client/generated/model/recurring_plan_recent_runs_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'recurring_plan.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RecurringPlan {
  /// Returns a new [RecurringPlan] instance.
  RecurringPlan({
    required this.allocations,

    required this.amount,

    required this.demo,

    required this.frequency,

    required this.id,

    required this.nextRunAt,

    required this.portfolioId,

    required this.recentRuns,

    required this.status,

    required this.type,

    required this.version,
  });

  @JsonKey(name: r'allocations', required: true, includeIfNull: false)
  final List<CreateRecurringPlanRequestAllocationsInner> allocations;

  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final Money amount;

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(
    name: r'frequency',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RecurringPlanFrequencyEnum.unknownDefaultOpenApi,
  )
  final RecurringPlanFrequencyEnum frequency;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'next_run_at', required: true, includeIfNull: false)
  final DateTime nextRunAt;

  @JsonKey(name: r'portfolio_id', required: true, includeIfNull: false)
  final String portfolioId;

  @JsonKey(name: r'recent_runs', required: true, includeIfNull: false)
  final List<RecurringPlanRecentRunsInner> recentRuns;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RecurringPlanStatusEnum.unknownDefaultOpenApi,
  )
  final RecurringPlanStatusEnum status;

  @JsonKey(
    name: r'type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RecurringPlanTypeEnum.unknownDefaultOpenApi,
  )
  final RecurringPlanTypeEnum type;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringPlan &&
          other.allocations == allocations &&
          other.amount == amount &&
          other.demo == demo &&
          other.frequency == frequency &&
          other.id == id &&
          other.nextRunAt == nextRunAt &&
          other.portfolioId == portfolioId &&
          other.recentRuns == recentRuns &&
          other.status == status &&
          other.type == type &&
          other.version == version;

  @override
  int get hashCode =>
      allocations.hashCode +
      amount.hashCode +
      demo.hashCode +
      frequency.hashCode +
      id.hashCode +
      nextRunAt.hashCode +
      portfolioId.hashCode +
      recentRuns.hashCode +
      status.hashCode +
      type.hashCode +
      version.hashCode;

  factory RecurringPlan.fromJson(Map<String, dynamic> json) =>
      _$RecurringPlanFromJson(json);

  Map<String, dynamic> toJson() => _$RecurringPlanToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RecurringPlanFrequencyEnum {
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'monthly')
  monthly(r'monthly'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RecurringPlanFrequencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum RecurringPlanStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'paused')
  paused(r'paused'),
  @JsonValue(r'cancelled')
  cancelled(r'cancelled'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RecurringPlanStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum RecurringPlanTypeEnum {
  @JsonValue(r'contribution')
  contribution(r'contribution'),
  @JsonValue(r'allocation')
  allocation(r'allocation'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RecurringPlanTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
