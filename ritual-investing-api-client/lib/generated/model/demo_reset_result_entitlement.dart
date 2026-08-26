//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'demo_reset_result_entitlement.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DemoResetResultEntitlement {
  /// Returns a new [DemoResetResultEntitlement] instance.
  DemoResetResultEntitlement({
    required this.id,

    required this.planCode,

    required this.source_,

    required this.status,

    required this.version,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'plan_code',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        DemoResetResultEntitlementPlanCodeEnum.unknownDefaultOpenApi,
  )
  final DemoResetResultEntitlementPlanCodeEnum planCode;

  @JsonKey(
    name: r'source',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        DemoResetResultEntitlementSource_Enum.unknownDefaultOpenApi,
  )
  final DemoResetResultEntitlementSource_Enum source_;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        DemoResetResultEntitlementStatusEnum.unknownDefaultOpenApi,
  )
  final DemoResetResultEntitlementStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoResetResultEntitlement &&
          other.id == id &&
          other.planCode == planCode &&
          other.source_ == source_ &&
          other.status == status &&
          other.version == version;

  @override
  int get hashCode =>
      id.hashCode +
      planCode.hashCode +
      source_.hashCode +
      status.hashCode +
      version.hashCode;

  factory DemoResetResultEntitlement.fromJson(Map<String, dynamic> json) =>
      _$DemoResetResultEntitlementFromJson(json);

  Map<String, dynamic> toJson() => _$DemoResetResultEntitlementToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum DemoResetResultEntitlementPlanCodeEnum {
  @JsonValue(r'free')
  free(r'free'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoResetResultEntitlementPlanCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DemoResetResultEntitlementSource_Enum {
  @JsonValue(r'demo')
  demo(r'demo'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoResetResultEntitlementSource_Enum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum DemoResetResultEntitlementStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DemoResetResultEntitlementStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
