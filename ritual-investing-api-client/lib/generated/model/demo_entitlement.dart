//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/simulation_demo_disclosure.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'demo_entitlement.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DemoEntitlement {
  /// Returns a new [DemoEntitlement] instance.
  DemoEntitlement({
    required this.demo,

    required this.endsAt,

    required this.id,

    required this.planCode,

    required this.source_,

    required this.startsAt,

    required this.status,

    required this.version,
  });

  @JsonKey(name: r'demo', required: true, includeIfNull: false)
  final SimulationDemoDisclosure demo;

  @JsonKey(name: r'ends_at', required: true, includeIfNull: true)
  final DateTime? endsAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'plan_code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DemoEntitlementPlanCodeEnum.unknownDefaultOpenApi,
  )
  final DemoEntitlementPlanCodeEnum planCode;

  @JsonKey(
    name: r'source',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DemoEntitlementSource_Enum.unknownDefaultOpenApi,
  )
  final DemoEntitlementSource_Enum source_;

  @JsonKey(name: r'starts_at', required: true, includeIfNull: false)
  final DateTime startsAt;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DemoEntitlementStatusEnum.unknownDefaultOpenApi,
  )
  final DemoEntitlementStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoEntitlement &&
          other.demo == demo &&
          other.endsAt == endsAt &&
          other.id == id &&
          other.planCode == planCode &&
          other.source_ == source_ &&
          other.startsAt == startsAt &&
          other.status == status &&
          other.version == version;

  @override
  int get hashCode =>
      demo.hashCode +
      (endsAt == null ? 0 : endsAt.hashCode) +
      id.hashCode +
      planCode.hashCode +
      source_.hashCode +
      startsAt.hashCode +
      status.hashCode +
      version.hashCode;

  factory DemoEntitlement.fromJson(Map<String, dynamic> json) =>
      _$DemoEntitlementFromJson(json);

  Map<String, dynamic> toJson() => _$DemoEntitlementToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DemoEntitlementPlanCodeEnum {
  @JsonValue(r'free')
  free(r'free'),
  @JsonValue(r'premium_demo')
  premiumDemo(r'premium_demo'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoEntitlementPlanCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DemoEntitlementSource_Enum {
  @JsonValue(r'demo')
  demo(r'demo'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoEntitlementSource_Enum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DemoEntitlementStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'expired')
  expired(r'expired'),
  @JsonValue(r'revoked')
  revoked(r'revoked'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoEntitlementStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
