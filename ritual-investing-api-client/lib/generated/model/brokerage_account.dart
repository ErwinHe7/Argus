//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_capability.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_account.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageAccount {
  /// Returns a new [BrokerageAccount] instance.
  BrokerageAccount({
    required this.baseCurrency,

    required this.capabilities,

    required this.capabilityVersion,

    required this.connectionId,

    required this.displayLabel,

    required this.expiresAt,

    required this.fetchedAt,

    required this.id,

    required this.marketTimezone,

    required this.providerObservedAt,

    required this.selected,

    required this.state,

    required this.status,
  });

  @JsonKey(name: r'base_currency', required: true, includeIfNull: false)
  final String baseCurrency;

  @JsonKey(name: r'capabilities', required: true, includeIfNull: false)
  final List<BrokerageCapability> capabilities;

  // minimum: 0
  @JsonKey(name: r'capability_version', required: true, includeIfNull: false)
  final int capabilityVersion;

  @JsonKey(name: r'connection_id', required: true, includeIfNull: false)
  final String connectionId;

  @JsonKey(name: r'display_label', required: true, includeIfNull: false)
  final String displayLabel;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: true)
  final DateTime? expiresAt;

  @JsonKey(name: r'fetched_at', required: true, includeIfNull: true)
  final DateTime? fetchedAt;

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'market_timezone', required: true, includeIfNull: true)
  final String? marketTimezone;

  @JsonKey(name: r'provider_observed_at', required: true, includeIfNull: true)
  final DateTime? providerObservedAt;

  @JsonKey(name: r'selected', required: true, includeIfNull: false)
  final bool selected;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageAccountStateEnum.unknownDefaultOpenApi,
  )
  final BrokerageAccountStateEnum state;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: BrokerageAccountStatusEnum.unknownDefaultOpenApi,
  )
  final BrokerageAccountStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageAccount &&
          other.baseCurrency == baseCurrency &&
          other.capabilities == capabilities &&
          other.capabilityVersion == capabilityVersion &&
          other.connectionId == connectionId &&
          other.displayLabel == displayLabel &&
          other.expiresAt == expiresAt &&
          other.fetchedAt == fetchedAt &&
          other.id == id &&
          other.marketTimezone == marketTimezone &&
          other.providerObservedAt == providerObservedAt &&
          other.selected == selected &&
          other.state == state &&
          other.status == status;

  @override
  int get hashCode =>
      baseCurrency.hashCode +
      capabilities.hashCode +
      capabilityVersion.hashCode +
      connectionId.hashCode +
      displayLabel.hashCode +
      (expiresAt == null ? 0 : expiresAt.hashCode) +
      (fetchedAt == null ? 0 : fetchedAt.hashCode) +
      id.hashCode +
      (marketTimezone == null ? 0 : marketTimezone.hashCode) +
      (providerObservedAt == null ? 0 : providerObservedAt.hashCode) +
      selected.hashCode +
      state.hashCode +
      status.hashCode;

  factory BrokerageAccount.fromJson(Map<String, dynamic> json) =>
      _$BrokerageAccountFromJson(json);

  Map<String, dynamic> toJson() => _$BrokerageAccountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageAccountStateEnum {
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

  const BrokerageAccountStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageAccountStatusEnum {
  @JsonValue(r'available')
  available(r'available'),
  @JsonValue(r'restricted')
  restricted(r'restricted'),
  @JsonValue(r'closed')
  closed(r'closed'),
  @JsonValue(r'unavailable')
  unavailable(r'unavailable'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageAccountStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
