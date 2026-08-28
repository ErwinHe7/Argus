//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/brokerage_position.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'brokerage_positions_projection.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrokeragePositionsProjection {
  /// Returns a new [BrokeragePositionsProjection] instance.
  BrokeragePositionsProjection({
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
  final List<BrokeragePosition>? data;

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
        BrokeragePositionsProjectionResourceEnum.unknownDefaultOpenApi,
  )
  final BrokeragePositionsProjectionResourceEnum resource;

  @JsonKey(
    name: r'state',
    required: true,
    includeIfNull: false,
    unknownEnumValue:
        BrokeragePositionsProjectionStateEnum.unknownDefaultOpenApi,
  )
  final BrokeragePositionsProjectionStateEnum state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrokeragePositionsProjection &&
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

  factory BrokeragePositionsProjection.fromJson(Map<String, dynamic> json) =>
      _$BrokeragePositionsProjectionFromJson(json);

  Map<String, dynamic> toJson() => _$BrokeragePositionsProjectionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum BrokeragePositionsProjectionResourceEnum {
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

  const BrokeragePositionsProjectionResourceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum BrokeragePositionsProjectionStateEnum {
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

  const BrokeragePositionsProjectionStateEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
