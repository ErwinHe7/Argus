//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'record_consent_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RecordConsentRequest {
  /// Returns a new [RecordConsentRequest] instance.
  RecordConsentRequest({
    required this.decision,

    required this.policyCode,

    required this.policyVersion,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RecordConsentRequestDecisionEnum.unknownDefaultOpenApi,
  )
  final RecordConsentRequestDecisionEnum decision;

  @JsonKey(name: r'policyCode', required: true, includeIfNull: false)
  final String policyCode;

  @JsonKey(name: r'policyVersion', required: true, includeIfNull: false)
  final String policyVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordConsentRequest &&
          other.decision == decision &&
          other.policyCode == policyCode &&
          other.policyVersion == policyVersion;

  @override
  int get hashCode =>
      decision.hashCode + policyCode.hashCode + policyVersion.hashCode;

  factory RecordConsentRequest.fromJson(Map<String, dynamic> json) =>
      _$RecordConsentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RecordConsentRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum RecordConsentRequestDecisionEnum {
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'declined')
  declined(r'declined'),
  @JsonValue(r'withdrawn')
  withdrawn(r'withdrawn'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RecordConsentRequestDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
