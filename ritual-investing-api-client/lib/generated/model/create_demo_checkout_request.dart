//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_demo_checkout_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateDemoCheckoutRequest {
  /// Returns a new [CreateDemoCheckoutRequest] instance.
  CreateDemoCheckoutRequest({required this.planCode});

  @JsonKey(
    name: r'plan_code',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        CreateDemoCheckoutRequestPlanCodeEnum.unknownDefaultOpenApi,
  )
  final CreateDemoCheckoutRequestPlanCodeEnum planCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateDemoCheckoutRequest && other.planCode == planCode;

  @override
  int get hashCode => planCode.hashCode;

  factory CreateDemoCheckoutRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateDemoCheckoutRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateDemoCheckoutRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateDemoCheckoutRequestPlanCodeEnum {
  @JsonValue(r'premium_demo')
  premiumDemo(r'premium_demo'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateDemoCheckoutRequestPlanCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
