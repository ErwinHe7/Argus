//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_recurring_plan_request_allocations_inner.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateRecurringPlanRequestAllocationsInner {
  /// Returns a new [CreateRecurringPlanRequestAllocationsInner] instance.
  CreateRecurringPlanRequestAllocationsInner({
    required this.assetId,

    required this.weightBps,
  });

  @JsonKey(name: r'asset_id', required: true, includeIfNull: false)
  final String assetId;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'weight_bps', required: true, includeIfNull: false)
  final int weightBps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateRecurringPlanRequestAllocationsInner &&
          other.assetId == assetId &&
          other.weightBps == weightBps;

  @override
  int get hashCode => assetId.hashCode + weightBps.hashCode;

  factory CreateRecurringPlanRequestAllocationsInner.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateRecurringPlanRequestAllocationsInnerFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateRecurringPlanRequestAllocationsInnerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
