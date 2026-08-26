//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/positive_input_money.dart';
import 'package:ritual_investing_api_client/generated/model/create_recurring_plan_request_allocations_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_recurring_plan_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateRecurringPlanRequest {
  /// Returns a new [CreateRecurringPlanRequest] instance.
  CreateRecurringPlanRequest({
    required this.allocations,

    required this.amount,

    required this.firstRunAt,

    required this.frequency,

    required this.sourceId,

    required this.type,
  });

  @JsonKey(name: r'allocations', required: true, includeIfNull: false)
  final List<CreateRecurringPlanRequestAllocationsInner> allocations;

  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final PositiveInputMoney amount;

  @JsonKey(name: r'first_run_at', required: true, includeIfNull: false)
  final DateTime firstRunAt;

  @JsonKey(
    name: r'frequency',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateRecurringPlanRequestFrequencyEnum.unknownDefaultOpenApi,
  )
  final CreateRecurringPlanRequestFrequencyEnum frequency;

  @JsonKey(name: r'source_id', required: true, includeIfNull: false)
  final String sourceId;

  @JsonKey(
    name: r'type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreateRecurringPlanRequestTypeEnum.unknownDefaultOpenApi,
  )
  final CreateRecurringPlanRequestTypeEnum type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateRecurringPlanRequest &&
          other.allocations == allocations &&
          other.amount == amount &&
          other.firstRunAt == firstRunAt &&
          other.frequency == frequency &&
          other.sourceId == sourceId &&
          other.type == type;

  @override
  int get hashCode =>
      allocations.hashCode +
      amount.hashCode +
      firstRunAt.hashCode +
      frequency.hashCode +
      sourceId.hashCode +
      type.hashCode;

  factory CreateRecurringPlanRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateRecurringPlanRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateRecurringPlanRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateRecurringPlanRequestFrequencyEnum {
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'monthly')
  monthly(r'monthly'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateRecurringPlanRequestFrequencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CreateRecurringPlanRequestTypeEnum {
  @JsonValue(r'contribution')
  contribution(r'contribution'),
  @JsonValue(r'allocation')
  allocation(r'allocation'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateRecurringPlanRequestTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
