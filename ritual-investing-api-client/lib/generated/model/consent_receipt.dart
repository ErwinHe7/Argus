//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'consent_receipt.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ConsentReceipt {
  /// Returns a new [ConsentReceipt] instance.
  ConsentReceipt({
    required this.decision,

    required this.id,

    required this.policyCode,

    required this.policyVersion,

    required this.recordedAt,
  });

  @JsonKey(
    name: r'decision',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ConsentReceiptDecisionEnum.unknownDefaultOpenApi,
  )
  final ConsentReceiptDecisionEnum decision;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'policy_code', required: true, includeIfNull: false)
  final String policyCode;

  @JsonKey(name: r'policy_version', required: true, includeIfNull: false)
  final String policyVersion;

  @JsonKey(name: r'recorded_at', required: true, includeIfNull: false)
  final DateTime recordedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsentReceipt &&
          other.decision == decision &&
          other.id == id &&
          other.policyCode == policyCode &&
          other.policyVersion == policyVersion &&
          other.recordedAt == recordedAt;

  @override
  int get hashCode =>
      decision.hashCode +
      id.hashCode +
      policyCode.hashCode +
      policyVersion.hashCode +
      recordedAt.hashCode;

  factory ConsentReceipt.fromJson(Map<String, dynamic> json) =>
      _$ConsentReceiptFromJson(json);

  Map<String, dynamic> toJson() => _$ConsentReceiptToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ConsentReceiptDecisionEnum {
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'declined')
  declined(r'declined'),
  @JsonValue(r'withdrawn')
  withdrawn(r'withdrawn'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ConsentReceiptDecisionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
