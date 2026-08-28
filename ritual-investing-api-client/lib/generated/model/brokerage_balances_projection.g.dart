// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_balances_projection.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageBalancesProjectionCWProxy {
  BrokerageBalancesProjection accountId(String accountId);

  BrokerageBalancesProjection data(BrokerageBalance? data);

  BrokerageBalancesProjection expiresAt(DateTime? expiresAt);

  BrokerageBalancesProjection fetchedAt(DateTime? fetchedAt);

  BrokerageBalancesProjection generation(int? generation);

  BrokerageBalancesProjection providerObservedAt(DateTime? providerObservedAt);

  BrokerageBalancesProjection reason(String? reason);

  BrokerageBalancesProjection resource(
    BrokerageBalancesProjectionResourceEnum resource,
  );

  BrokerageBalancesProjection state(BrokerageBalancesProjectionStateEnum state);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageBalancesProjection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageBalancesProjection(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageBalancesProjection call({
    String accountId,
    BrokerageBalance? data,
    DateTime? expiresAt,
    DateTime? fetchedAt,
    int? generation,
    DateTime? providerObservedAt,
    String? reason,
    BrokerageBalancesProjectionResourceEnum resource,
    BrokerageBalancesProjectionStateEnum state,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageBalancesProjection.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageBalancesProjection.copyWith.fieldName(...)`
class _$BrokerageBalancesProjectionCWProxyImpl
    implements _$BrokerageBalancesProjectionCWProxy {
  const _$BrokerageBalancesProjectionCWProxyImpl(this._value);

  final BrokerageBalancesProjection _value;

  @override
  BrokerageBalancesProjection accountId(String accountId) =>
      this(accountId: accountId);

  @override
  BrokerageBalancesProjection data(BrokerageBalance? data) => this(data: data);

  @override
  BrokerageBalancesProjection expiresAt(DateTime? expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  BrokerageBalancesProjection fetchedAt(DateTime? fetchedAt) =>
      this(fetchedAt: fetchedAt);

  @override
  BrokerageBalancesProjection generation(int? generation) =>
      this(generation: generation);

  @override
  BrokerageBalancesProjection providerObservedAt(
    DateTime? providerObservedAt,
  ) => this(providerObservedAt: providerObservedAt);

  @override
  BrokerageBalancesProjection reason(String? reason) => this(reason: reason);

  @override
  BrokerageBalancesProjection resource(
    BrokerageBalancesProjectionResourceEnum resource,
  ) => this(resource: resource);

  @override
  BrokerageBalancesProjection state(
    BrokerageBalancesProjectionStateEnum state,
  ) => this(state: state);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageBalancesProjection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageBalancesProjection(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageBalancesProjection call({
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
    return BrokerageBalancesProjection(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageBalance?,
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
          : resource as BrokerageBalancesProjectionResourceEnum,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as BrokerageBalancesProjectionStateEnum,
    );
  }
}

extension $BrokerageBalancesProjectionCopyWith on BrokerageBalancesProjection {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageBalancesProjection.copyWith(...)` or like so:`instanceOfBrokerageBalancesProjection.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageBalancesProjectionCWProxy get copyWith =>
      _$BrokerageBalancesProjectionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageBalancesProjection _$BrokerageBalancesProjectionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokerageBalancesProjection',
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
    final val = BrokerageBalancesProjection(
      accountId: $checkedConvert('account_id', (v) => v as String),
      data: $checkedConvert(
        'data',
        (v) => v == null
            ? null
            : BrokerageBalance.fromJson(v as Map<String, dynamic>),
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
          _$BrokerageBalancesProjectionResourceEnumEnumMap,
          v,
          unknownValue:
              BrokerageBalancesProjectionResourceEnum.unknownDefaultOpenApi,
        ),
      ),
      state: $checkedConvert(
        'state',
        (v) => $enumDecode(
          _$BrokerageBalancesProjectionStateEnumEnumMap,
          v,
          unknownValue:
              BrokerageBalancesProjectionStateEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$BrokerageBalancesProjectionToJson(
  BrokerageBalancesProjection instance,
) => <String, dynamic>{
  'account_id': instance.accountId,
  'data': instance.data?.toJson(),
  'expires_at': instance.expiresAt?.toIso8601String(),
  'fetched_at': instance.fetchedAt?.toIso8601String(),
  'generation': instance.generation,
  'provider_observed_at': instance.providerObservedAt?.toIso8601String(),
  'reason': instance.reason,
  'resource':
      _$BrokerageBalancesProjectionResourceEnumEnumMap[instance.resource]!,
  'state': _$BrokerageBalancesProjectionStateEnumEnumMap[instance.state]!,
};

const _$BrokerageBalancesProjectionResourceEnumEnumMap = {
  BrokerageBalancesProjectionResourceEnum.account: 'account',
  BrokerageBalancesProjectionResourceEnum.balance: 'balance',
  BrokerageBalancesProjectionResourceEnum.positions: 'positions',
  BrokerageBalancesProjectionResourceEnum.restrictions: 'restrictions',
  BrokerageBalancesProjectionResourceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$BrokerageBalancesProjectionStateEnumEnumMap = {
  BrokerageBalancesProjectionStateEnum.fresh: 'fresh',
  BrokerageBalancesProjectionStateEnum.empty: 'empty',
  BrokerageBalancesProjectionStateEnum.stale: 'stale',
  BrokerageBalancesProjectionStateEnum.partial: 'partial',
  BrokerageBalancesProjectionStateEnum.unavailable: 'unavailable',
  BrokerageBalancesProjectionStateEnum.offline: 'offline',
  BrokerageBalancesProjectionStateEnum.rateLimited: 'rate_limited',
  BrokerageBalancesProjectionStateEnum.disconnected: 'disconnected',
  BrokerageBalancesProjectionStateEnum.reauthorizationRequired:
      'reauthorization_required',
  BrokerageBalancesProjectionStateEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
