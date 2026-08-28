//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_order_command.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageOrderCommand {
  /// Returns a new [BrokerageOrderCommand] instance.
  BrokerageOrderCommand({
    required this.accountId,

    required this.ambiguous,

    required this.createdAt,

    required this.id,

    required this.operation,

    required this.orderId,

    required this.state,

    required this.targetOrderId,

    required this.updatedAt,
  });

  @JsonKey(name: r'account_id', required: true, includeIfNull: false)
  final String accountId;

  @JsonKey(name: r'ambiguous', required: true, includeIfNull: false)
  final bool ambiguous;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(
    name: r'operation',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderCommandOperationEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderCommandOperationEnum operation;

  @JsonKey(name: r'order_id', required: true, includeIfNull: true)
  final String? orderId;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderCommandStateEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderCommandStateEnum state;

  @JsonKey(name: r'target_order_id', required: true, includeIfNull: true)
  final String? targetOrderId;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageOrderCommand &&
          other.accountId == accountId &&
          other.ambiguous == ambiguous &&
          other.createdAt == createdAt &&
          other.id == id &&
          other.operation == operation &&
          other.orderId == orderId &&
          other.state == state &&
          other.targetOrderId == targetOrderId &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      accountId.hashCode +
      ambiguous.hashCode +
      createdAt.hashCode +
      id.hashCode +
      operation.hashCode +
      (orderId == null ? 0 : orderId.hashCode) +
      state.hashCode +
      (targetOrderId == null ? 0 : targetOrderId.hashCode) +
      updatedAt.hashCode;

  factory BrokerageOrderCommand.fromJson(Map<String, dynamic> json) =>
      _$BrokerageOrderCommandFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageOrderCommandToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageOrderCommandOperationEnum {
  @JsonValue(r'place')
  place(r'place'),
  @JsonValue(r'modify')
  modify(r'modify'),
  @JsonValue(r'cancel')
  cancel(r'cancel'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderCommandOperationEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageOrderCommandStateEnum {
  @JsonValue(r'dispatching')
  dispatching(r'dispatching'),
  @JsonValue(r'accepted')
  accepted(r'accepted'),
  @JsonValue(r'ambiguous')
  ambiguous(r'ambiguous'),
  @JsonValue(r'reconciling')
  reconciling(r'reconciling'),
  @JsonValue(r'resolved')
  resolved(r'resolved'),
  @JsonValue(r'failed')
  failed(r'failed'),
  @JsonValue(r'manual_review')
  manualReview(r'manual_review'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderCommandStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
