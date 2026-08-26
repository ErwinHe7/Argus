//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/recurring_plan.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_recurring_plan201_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateRecurringPlan201Response {
  /// Returns a new [CreateRecurringPlan201Response] instance.
  CreateRecurringPlan201Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final RecurringPlan data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateRecurringPlan201Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory CreateRecurringPlan201Response.fromJson(Map<String, dynamic> json) =>
      _$CreateRecurringPlan201ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreateRecurringPlan201ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
