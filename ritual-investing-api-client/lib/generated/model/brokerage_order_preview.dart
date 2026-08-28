//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_order_preview.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageOrderPreview {
  /// Returns a new [BrokerageOrderPreview] instance.
  BrokerageOrderPreview({
    required this.accountId,

    required this.capabilityVersion,

    required this.currency,

    required this.estimatedTotal,

    required this.expiresAt,

    required this.id,

    required this.operation,

    required this.policyVersion,

    required this.restrictionGeneration,

    required this.reviewedPayloadHash,

    required this.targetOrderId,
  });

  @JsonKey(name: r'account_id', required: true, includeIfNull: false)
  final String accountId;

  // minimum: 0
  @JsonKey(name: r'capability_version', required: true, includeIfNull: false)
  final int capabilityVersion;

  @JsonKey(name: r'currency', required: true, includeIfNull: true)
  final String? currency;

  @JsonKey(name: r'estimated_total', required: true, includeIfNull: true)
  final String? estimatedTotal;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'operation',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderPreviewOperationEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderPreviewOperationEnum operation;

  @JsonKey(name: r'policy_version', required: true, includeIfNull: false)
  final String policyVersion;

  // minimum: 0
  @JsonKey(
    name: r'restriction_generation',
    required: true,
    includeIfNull: false,
  )
  final int restrictionGeneration;

  @JsonKey(name: r'reviewed_payload_hash', required: true, includeIfNull: false)
  final String reviewedPayloadHash;

  @JsonKey(name: r'target_order_id', required: true, includeIfNull: true)
  final String? targetOrderId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageOrderPreview &&
          other.accountId == accountId &&
          other.capabilityVersion == capabilityVersion &&
          other.currency == currency &&
          other.estimatedTotal == estimatedTotal &&
          other.expiresAt == expiresAt &&
          other.id == id &&
          other.operation == operation &&
          other.policyVersion == policyVersion &&
          other.restrictionGeneration == restrictionGeneration &&
          other.reviewedPayloadHash == reviewedPayloadHash &&
          other.targetOrderId == targetOrderId;

  @override
  int get hashCode =>
      accountId.hashCode +
      capabilityVersion.hashCode +
      (currency == null ? 0 : currency.hashCode) +
      (estimatedTotal == null ? 0 : estimatedTotal.hashCode) +
      expiresAt.hashCode +
      id.hashCode +
      operation.hashCode +
      policyVersion.hashCode +
      restrictionGeneration.hashCode +
      reviewedPayloadHash.hashCode +
      (targetOrderId == null ? 0 : targetOrderId.hashCode);

  factory BrokerageOrderPreview.fromJson(Map<String, dynamic> json) =>
      _$BrokerageOrderPreviewFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageOrderPreviewToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageOrderPreviewOperationEnum {
  @JsonValue(r'place')
  place(r'place'),
  @JsonValue(r'modify')
  modify(r'modify'),
  @JsonValue(r'cancel')
  cancel(r'cancel'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderPreviewOperationEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
