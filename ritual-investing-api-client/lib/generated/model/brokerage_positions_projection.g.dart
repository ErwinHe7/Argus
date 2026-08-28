// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_positions_projection.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokeragePositionsProjectionCWProxy {
  BrokeragePositionsProjection accountId(String accountId);

  BrokeragePositionsProjection data(List<BrokeragePosition>? data);

  BrokeragePositionsProjection expiresAt(DateTime? expiresAt);

  BrokeragePositionsProjection fetchedAt(DateTime? fetchedAt);

  BrokeragePositionsProjection generation(int? generation);

  BrokeragePositionsProjection providerObservedAt(DateTime? providerObservedAt);

  BrokeragePositionsProjection reason(String? reason);

  BrokeragePositionsProjection resource(
    BrokeragePositionsProjectionResourceEnum resource,
  );

  BrokeragePositionsProjection state(
    BrokeragePositionsProjectionStateEnum state,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokeragePositionsProjection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokeragePositionsProjection(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokeragePositionsProjection call({
    String accountId,
    List<BrokeragePosition>? data,
    DateTime? expiresAt,
    DateTime? fetchedAt,
    int? generation,
    DateTime? providerObservedAt,
    String? reason,
    BrokeragePositionsProjectionResourceEnum resource,
    BrokeragePositionsProjectionStateEnum state,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokeragePositionsProjection.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokeragePositionsProjection.copyWith.fieldName(...)`
class _$BrokeragePositionsProjectionCWProxyImpl
    implements _$BrokeragePositionsProjectionCWProxy {
  const _$BrokeragePositionsProjectionCWProxyImpl(this._value);

  final BrokeragePositionsProjection _value;

  @override
  BrokeragePositionsProjection accountId(String accountId) =>
      this(accountId: accountId);

  @override
  BrokeragePositionsProjection data(List<BrokeragePosition>? data) =>
      this(data: data);

  @override
  BrokeragePositionsProjection expiresAt(DateTime? expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  BrokeragePositionsProjection fetchedAt(DateTime? fetchedAt) =>
      this(fetchedAt: fetchedAt);

  @override
  BrokeragePositionsProjection generation(int? generation) =>
      this(generation: generation);

  @override
  BrokeragePositionsProjection providerObservedAt(
    DateTime? providerObservedAt,
  ) => this(providerObservedAt: providerObservedAt);

  @override
  BrokeragePositionsProjection reason(String? reason) => this(reason: reason);

  @override
  BrokeragePositionsProjection resource(
    BrokeragePositionsProjectionResourceEnum resource,
  ) => this(resource: resource);

  @override
  BrokeragePositionsProjection state(
    BrokeragePositionsProjectionStateEnum state,
  ) => this(state: state);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokeragePositionsProjection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokeragePositionsProjection(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokeragePositionsProjection call({
    Object? accountId = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? fetchedAt = const $CopyWithPlaceholder(),
    Object? generation = const $CopyWithPlaceholder(),
    Object? providerObservedAt = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
    Object? resource = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
  }) {
    return BrokeragePositionsProjection(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<BrokeragePosition>?,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
      fetchedAt: fetchedAt == const $CopyWithPlaceholder()
          ? _value.fetchedAt
          // ignore: cast_nullable_to_non_nullable
          : fetchedAt as DateTime?,
      generation: generation == const $CopyWithPlaceholder()
          ? _value.generation
          // ignore: cast_nullable_to_non_nullable
          : generation as int?,
      providerObservedAt: providerObservedAt == const $CopyWithPlaceholder()
          ? _value.providerObservedAt
          // ignore: cast_nullable_to_non_nullable
          : providerObservedAt as DateTime?,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String?,
      resource: resource == const $CopyWithPlaceholder()
          ? _value.resource
          // ignore: cast_nullable_to_non_nullable
          : resource as BrokeragePositionsProjectionResourceEnum,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as BrokeragePositionsProjectionStateEnum,
    );
  }
}

extension $BrokeragePositionsProjectionCopyWith
    on BrokeragePositionsProjection {
  /// Returns a callable class that can be used as follows: `instanceOfBrokeragePositionsProjection.copyWith(...)` or like so:`instanceOfBrokeragePositionsProjection.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokeragePositionsProjectionCWProxy get copyWith =>
      _$BrokeragePositionsProjectionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokeragePositionsProjection _$BrokeragePositionsProjectionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokeragePositionsProjection',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'account_id',
        'data',
        'expires_at',
        'fetched_at',
        'generation',
        'provider_observed_at',
        'reason',
        'resource',
        'state',
      ],
    );
    final val = BrokeragePositionsProjection(
      accountId: $checkedConvert('account_id', (v) => v as String),
      data: $checkedConvert(
        'data',
        (v) => (v as List<dynamic>?)
            ?.map((e) => BrokeragePosition.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      fetchedAt: $checkedConvert(
        'fetched_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      generation: $checkedConvert('generation', (v) => (v as num?)?.toInt()),
      providerObservedAt: $checkedConvert(
        'provider_observed_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      reason: $checkedConvert('reason', (v) => v as String?),
      resource: $checkedConvert(
        'resource',
        (v) => $enumDecode(
          _$BrokeragePositionsProjectionResourceEnumEnumMap,
          v,
          unknownValue:
              BrokeragePositionsProjectionResourceEnum.unknownDefaultOpenApi,
        ),
      ),
      state: $checkedConvert(
        'state',
        (v) => $enumDecode(
          _$BrokeragePositionsProjectionStateEnumEnumMap,
          v,
          unknownValue:
              BrokeragePositionsProjectionStateEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'accountId': 'account_id',
    'expiresAt': 'expires_at',
    'fetchedAt': 'fetched_at',
    'providerObservedAt': 'provider_observed_at',
  },
);

Map<String, dynamic> _$BrokeragePositionsProjectionToJson(
  BrokeragePositionsProjection instance,
) => <String, dynamic>{
  'account_id': instance.accountId,
  'data': instance.data?.map((e) => e.toJson()).toList(),
  'expires_at': instance.expiresAt?.toIso8601String(),
  'fetched_at': instance.fetchedAt?.toIso8601String(),
  'generation': instance.generation,
  'provider_observed_at': instance.providerObservedAt?.toIso8601String(),
  'reason': instance.reason,
  'resource':
      _$BrokeragePositionsProjectionResourceEnumEnumMap[instance.resource]!,
  'state': _$BrokeragePositionsProjectionStateEnumEnumMap[instance.state]!,
};

const _$BrokeragePositionsProjectionResourceEnumEnumMap = {
  BrokeragePositionsProjectionResourceEnum.account: 'account',
  BrokeragePositionsProjectionResourceEnum.balance: 'balance',
  BrokeragePositionsProjectionResourceEnum.positions: 'positions',
  BrokeragePositionsProjectionResourceEnum.restrictions: 'restrictions',
  BrokeragePositionsProjectionResourceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$BrokeragePositionsProjectionStateEnumEnumMap = {
  BrokeragePositionsProjectionStateEnum.fresh: 'fresh',
  BrokeragePositionsProjectionStateEnum.empty: 'empty',
  BrokeragePositionsProjectionStateEnum.stale: 'stale',
  BrokeragePositionsProjectionStateEnum.partial: 'partial',
  BrokeragePositionsProjectionStateEnum.unavailable: 'unavailable',
  BrokeragePositionsProjectionStateEnum.offline: 'offline',
  BrokeragePositionsProjectionStateEnum.rateLimited: 'rate_limited',
  BrokeragePositionsProjectionStateEnum.disconnected: 'disconnected',
  BrokeragePositionsProjectionStateEnum.reauthorizationRequired:
      'reauthorization_required',
  BrokeragePositionsProjectionStateEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
