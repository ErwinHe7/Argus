//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/positive_input_money.dart';
import 'package:ritual_investing_api_client/generated/model/create_recurring_plan_request_allocations_inner.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patch_recurring_plan_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchRecurringPlanRequest {
  /// Returns a new [PatchRecurringPlanRequest] instance.
  PatchRecurringPlanRequest({this.allocations, this.amount, this.frequency});

  @JsonKey(name: r'allocations', required: false, includeIfNull: false)
  final List<CreateRecurringPlanRequestAllocationsInner>? allocations;

  @JsonKey(name: r'amount', required: false, includeIfNull: false)
  final PositiveInputMoney? amount;

  @JsonKey(
    name: r'frequency',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        PatchRecurringPlanRequestFrequencyEnum.unknownDefaultOpenApi,
  )
  final PatchRecurringPlanRequestFrequencyEnum? frequency;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchRecurringPlanRequest &&
          other.allocations == allocations &&
          other.amount == amount &&
          other.frequency == frequency;

  @override
  int get hashCode =>
      allocations.hashCode + amount.hashCode + frequency.hashCode;

  factory PatchRecurringPlanRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchRecurringPlanRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchRecurringPlanRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum PatchRecurringPlanRequestFrequencyEnum {
  @JsonValue(r'weekly')
  weekly(r'weekly'),
  @JsonValue(r'monthly')
  monthly(r'monthly'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PatchRecurringPlanRequestFrequencyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
