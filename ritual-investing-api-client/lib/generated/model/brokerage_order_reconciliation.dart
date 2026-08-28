//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_order_command.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_order_reconciliation.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageOrderReconciliation {
  /// Returns a new [BrokerageOrderReconciliation] instance.
  BrokerageOrderReconciliation({
    required this.attempts,

    required this.command,

    required this.egressStartedAt,

    required this.lastErrorCode,

    required this.nextAttemptAt,

    required this.status,
  });

  // minimum: 0
  @JsonKey(name: r'attempts', required: true, includeIfNull: false)
  final int attempts;

  @JsonKey(name: r'command', required: true, includeIfNull: false)
  final BrokerageOrderCommand command;

  @JsonKey(name: r'egress_started_at', required: true, includeIfNull: false)
  final DateTime egressStartedAt;

  @JsonKey(name: r'last_error_code', required: true, includeIfNull: true)
  final String? lastErrorCode;

  @JsonKey(name: r'next_attempt_at', required: true, includeIfNull: true)
  final DateTime? nextAttemptAt;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: true,
    unknownEnumValue:
        BrokerageOrderReconciliationStatusEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderReconciliationStatusEnum? status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageOrderReconciliation &&
          other.attempts == attempts &&
          other.command == command &&
          other.egressStartedAt == egressStartedAt &&
          other.lastErrorCode == lastErrorCode &&
          other.nextAttemptAt == nextAttemptAt &&
          other.status == status;

  @override
  int get hashCode =>
      attempts.hashCode +
      command.hashCode +
      egressStartedAt.hashCode +
      (lastErrorCode == null ? 0 : lastErrorCode.hashCode) +
      (nextAttemptAt == null ? 0 : nextAttemptAt.hashCode) +
      (status == null ? 0 : status.hashCode);

  factory BrokerageOrderReconciliation.fromJson(Map<String, dynamic> json) =>
      _$BrokerageOrderReconciliationFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageOrderReconciliationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageOrderReconciliationStatusEnum {
  @JsonValue(r'pending')
  pending(r'pending'),
  @JsonValue(r'running')
  running(r'running'),
  @JsonValue(r'resolved')
  resolved(r'resolved'),
  @JsonValue(r'manual_review')
  manualReview(r'manual_review'),
  @JsonValue(r'exhausted')
  exhausted(r'exhausted'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderReconciliationStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
