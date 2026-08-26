//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/response_meta.dart';
import 'package:ritual_investing_api_client/generated/model/demo_plan.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'list_demo_plans200_response.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ListDemoPlans200Response {
  /// Returns a new [ListDemoPlans200Response] instance.
  ListDemoPlans200Response({required this.data, required this.meta});

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final List<DemoPlan> data;

  @JsonKey(name: r'meta', required: true, includeIfNull: false)
  final ResponseMeta meta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListDemoPlans200Response &&
          other.data == data &&
          other.meta == meta;

  @override
  int get hashCode => data.hashCode + meta.hashCode;

  factory ListDemoPlans200Response.fromJson(Map<String, dynamic> json) =>
      _$ListDemoPlans200ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ListDemoPlans200ResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
