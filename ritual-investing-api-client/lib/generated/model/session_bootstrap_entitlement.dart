//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap_entitlement.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrapEntitlement {
  /// Returns a new [SessionBootstrapEntitlement] instance.
  SessionBootstrapEntitlement({required this.planCode, required this.status});

  @JsonKey(name: r'plan_code', required: true, includeIfNull: false)
  final String planCode;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        SessionBootstrapEntitlementStatusEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapEntitlementStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrapEntitlement &&
          other.planCode == planCode &&
          other.status == status;

  @override
  int get hashCode => planCode.hashCode + status.hashCode;

  factory SessionBootstrapEntitlement.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapEntitlementFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapEntitlementToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionBootstrapEntitlementStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapEntitlementStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
