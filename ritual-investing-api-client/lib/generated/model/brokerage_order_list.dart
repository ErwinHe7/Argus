//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_order.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_order_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageOrderList {
  /// Returns a new [BrokerageOrderList] instance.
  BrokerageOrderList({
    required this.accountId,

    required this.expiresAt,

    required this.fetchedAt,

    required this.orders,

    required this.providerObservedAt,

    required this.state,
  });

  @JsonKey(name: r'account_id', required: true, includeIfNull: false)
  final String accountId;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: true)
  final DateTime? expiresAt;

  @JsonKey(name: r'fetched_at', required: true, includeIfNull: true)
  final DateTime? fetchedAt;

  @JsonKey(name: r'orders', required: true, includeIfNull: false)
  final List<BrokerageOrder> orders;

  @JsonKey(name: r'provider_observed_at', required: true, includeIfNull: true)
  final DateTime? providerObservedAt;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageOrderListStateEnum.unknownDefaultOpenApi,
  )
  final BrokerageOrderListStateEnum state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageOrderList &&
          other.accountId == accountId &&
          other.expiresAt == expiresAt &&
          other.fetchedAt == fetchedAt &&
          other.orders == orders &&
          other.providerObservedAt == providerObservedAt &&
          other.state == state;

  @override
  int get hashCode =>
      accountId.hashCode +
      (expiresAt == null ? 0 : expiresAt.hashCode) +
      (fetchedAt == null ? 0 : fetchedAt.hashCode) +
      orders.hashCode +
      (providerObservedAt == null ? 0 : providerObservedAt.hashCode) +
      state.hashCode;

  factory BrokerageOrderList.fromJson(Map<String, dynamic> json) =>
      _$BrokerageOrderListFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageOrderListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageOrderListStateEnum {
  @JsonValue(r'fresh')
  fresh(r'fresh'),
  @JsonValue(r'empty')
  empty(r'empty'),
  @JsonValue(r'stale')
  stale(r'stale'),
  @JsonValue(r'partial')
  partial(r'partial'),
  @JsonValue(r'unavailable')
  unavailable(r'unavailable'),
  @JsonValue(r'offline')
  offline(r'offline'),
  @JsonValue(r'rate_limited')
  rateLimited(r'rate_limited'),
  @JsonValue(r'disconnected')
  disconnected(r'disconnected'),
  @JsonValue(r'reauthorization_required')
  reauthorizationRequired(r'reauthorization_required'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageOrderListStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
