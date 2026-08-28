//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_restriction.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_restrictions_projection.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokerageRestrictionsProjection {
  /// Returns a new [BrokerageRestrictionsProjection] instance.
  BrokerageRestrictionsProjection({
    required this.accountId,

    required this.data,

    required this.expiresAt,

    required this.fetchedAt,

    required this.generation,

    required this.providerObservedAt,

    required this.reason,

    required this.resource,

    required this.state,
  });

  @JsonKey(name: r'account_id', required: true, includeIfNull: false)
  final String accountId;

  @JsonKey(name: r'data', required: true, includeIfNull: true)
  final List<BrokerageRestriction>? data;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: true)
  final DateTime? expiresAt;

  @JsonKey(name: r'fetched_at', required: true, includeIfNull: true)
  final DateTime? fetchedAt;

  // minimum: 0
  @JsonKey(name: r'generation', required: true, includeIfNull: true)
  final int? generation;

  @JsonKey(name: r'provider_observed_at', required: true, includeIfNull: true)
  final DateTime? providerObservedAt;

  @JsonKey(name: r'reason', required: true, includeIfNull: true)
  final String? reason;

  @JsonKey(
    name: r'resource',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        BrokerageRestrictionsProjectionResourceEnum.unknownDefaultOpenApi,
  )
  final BrokerageRestrictionsProjectionResourceEnum resource;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        BrokerageRestrictionsProjectionStateEnum.unknownDefaultOpenApi,
  )
  final BrokerageRestrictionsProjectionStateEnum state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokerageRestrictionsProjection &&
          other.accountId == accountId &&
          other.data == data &&
          other.expiresAt == expiresAt &&
          other.fetchedAt == fetchedAt &&
          other.generation == generation &&
          other.providerObservedAt == providerObservedAt &&
          other.reason == reason &&
          other.resource == resource &&
          other.state == state;

  @override
  int get hashCode =>
      accountId.hashCode +
      (data == null ? 0 : data.hashCode) +
      (expiresAt == null ? 0 : expiresAt.hashCode) +
      (fetchedAt == null ? 0 : fetchedAt.hashCode) +
      (generation == null ? 0 : generation.hashCode) +
      (providerObservedAt == null ? 0 : providerObservedAt.hashCode) +
      (reason == null ? 0 : reason.hashCode) +
      resource.hashCode +
      state.hashCode;

  factory BrokerageRestrictionsProjection.fromJson(Map<String, dynamic> json) =>
      _$BrokerageRestrictionsProjectionFromJson(json);

  Map<String, dynamic> toJson() =>
      _$BrokerageRestrictionsProjectionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokerageRestrictionsProjectionResourceEnum {
  @JsonValue(r'account')
  account(r'account'),
  @JsonValue(r'balance')
  balance(r'balance'),
  @JsonValue(r'positions')
  positions(r'positions'),
  @JsonValue(r'restrictions')
  restrictions(r'restrictions'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BrokerageRestrictionsProjectionResourceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokerageRestrictionsProjectionStateEnum {
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

  const BrokerageRestrictionsProjectionStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
