//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_consent_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateConsentRequest {
  /// Returns a new [CreateConsentRequest] instance.
  CreateConsentRequest({
    required this.decision,

    required this.policyCode,

    required this.policyVersion,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreateConsentRequestDecisionEnum.unknownDefaultOpenApi,
  )
  final CreateConsentRequestDecisionEnum decision;

  @JsonKey(
    name: r'policy_code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CreateConsentRequestPolicyCodeEnum.unknownDefaultOpenApi,
  )
  final CreateConsentRequestPolicyCodeEnum policyCode;

  @JsonKey(name: r'policy_version', required: true, includeIfNull: false)
  final String policyVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateConsentRequest &&
          other.decision == decision &&
          other.policyCode == policyCode &&
          other.policyVersion == policyVersion;

  @override
  int get hashCode =>
      decision.hashCode + policyCode.hashCode + policyVersion.hashCode;

  factory CreateConsentRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateConsentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateConsentRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CreateConsentRequestDecisionEnum {
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'declined')
  declined(r'declined'),
  @JsonValue(r'withdrawn')
  withdrawn(r'withdrawn'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateConsentRequestDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CreateConsentRequestPolicyCodeEnum {
  @JsonValue(r'terms')
  terms(r'terms'),
  @JsonValue(r'privacy')
  privacy(r'privacy'),
  @JsonValue(r'demo_disclosure')
  demoDisclosure(r'demo_disclosure'),
  @JsonValue(r'astrology')
  astrology(r'astrology'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CreateConsentRequestPolicyCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
