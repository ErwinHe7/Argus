//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'demo_checkout_session.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DemoCheckoutSession {
  /// Returns a new [DemoCheckoutSession] instance.
  DemoCheckoutSession({
    required this.demo,

    required this.expiresAt,

    required this.id,

    required this.planCode,

    required this.status,

    required this.version,
  });

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'plan_code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DemoCheckoutSessionPlanCodeEnum.unknownDefaultOpenApi,
  )
  final DemoCheckoutSessionPlanCodeEnum planCode;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DemoCheckoutSessionStatusEnum.unknownDefaultOpenApi,
  )
  final DemoCheckoutSessionStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoCheckoutSession &&
          other.demo == demo &&
          other.expiresAt == expiresAt &&
          other.id == id &&
          other.planCode == planCode &&
          other.status == status &&
          other.version == version;

  @override
  int get hashCode =>
      demo.hashCode +
      expiresAt.hashCode +
      id.hashCode +
      planCode.hashCode +
      status.hashCode +
      version.hashCode;

  factory DemoCheckoutSession.fromJson(Map<String, dynamic> json) =>
      _$DemoCheckoutSessionFromJson(json);

  Map<String, dynamic> toJson() => _$DemoCheckoutSessionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DemoCheckoutSessionPlanCodeEnum {
  @JsonValue(r'premium_demo')
  premiumDemo(r'premium_demo'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoCheckoutSessionPlanCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DemoCheckoutSessionStatusEnum {
  @JsonValue(r'open')
  open(r'open'),
  @JsonValue(r'completed')
  completed(r'completed'),
  @JsonValue(r'expired')
  expired(r'expired'),
  @JsonValue(r'cancelled')
  cancelled(r'cancelled'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoCheckoutSessionStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
