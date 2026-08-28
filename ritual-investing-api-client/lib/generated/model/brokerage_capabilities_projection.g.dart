// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_capabilities_projection.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageCapabilitiesProjectionCWProxy {
  BrokerageCapabilitiesProjection accountId(String accountId);

  BrokerageCapabilitiesProjection data(BrokerageAccountAuthority? data);

  BrokerageCapabilitiesProjection expiresAt(DateTime? expiresAt);

  BrokerageCapabilitiesProjection fetchedAt(DateTime? fetchedAt);

  BrokerageCapabilitiesProjection generation(int? generation);

  BrokerageCapabilitiesProjection providerObservedAt(
    DateTime? providerObservedAt,
  );

  BrokerageCapabilitiesProjection reason(String? reason);

  BrokerageCapabilitiesProjection resource(
    BrokerageCapabilitiesProjectionResourceEnum resource,
  );

  BrokerageCapabilitiesProjection state(
    BrokerageCapabilitiesProjectionStateEnum state,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageCapabilitiesProjection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageCapabilitiesProjection(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageCapabilitiesProjection call({
    String accountId,
    BrokerageAccountAuthority? data,
    DateTime? expiresAt,
    DateTime? fetchedAt,
    int? generation,
    DateTime? providerObservedAt,
    String? reason,
    BrokerageCapabilitiesProjectionResourceEnum resource,
    BrokerageCapabilitiesProjectionStateEnum state,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageCapabilitiesProjection.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageCapabilitiesProjection.copyWith.fieldName(...)`
class _$BrokerageCapabilitiesProjectionCWProxyImpl
    implements _$BrokerageCapabilitiesProjectionCWProxy {
  const _$BrokerageCapabilitiesProjectionCWProxyImpl(this._value);

  final BrokerageCapabilitiesProjection _value;

  @override
  BrokerageCapabilitiesProjection accountId(String accountId) =>
      this(accountId: accountId);

  @override
  BrokerageCapabilitiesProjection data(BrokerageAccountAuthority? data) =>
      this(data: data);

  @override
  BrokerageCapabilitiesProjection expiresAt(DateTime? expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  BrokerageCapabilitiesProjection fetchedAt(DateTime? fetchedAt) =>
      this(fetchedAt: fetchedAt);

  @override
  BrokerageCapabilitiesProjection generation(int? generation) =>
      this(generation: generation);

  @override
  BrokerageCapabilitiesProjection providerObservedAt(
    DateTime? providerObservedAt,
  ) => this(providerObservedAt: providerObservedAt);

  @override
  BrokerageCapabilitiesProjection reason(String? reason) =>
      this(reason: reason);

  @override
  BrokerageCapabilitiesProjection resource(
    BrokerageCapabilitiesProjectionResourceEnum resource,
  ) => this(resource: resource);

  @override
  BrokerageCapabilitiesProjection state(
    BrokerageCapabilitiesProjectionStateEnum state,
  ) => this(state: state);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageCapabilitiesProjection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageCapabilitiesProjection(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageCapabilitiesProjection call({
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
    return BrokerageCapabilitiesProjection(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as BrokerageAccountAuthority?,
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
          : resource as BrokerageCapabilitiesProjectionResourceEnum,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as BrokerageCapabilitiesProjectionStateEnum,
    );
  }
}

extension $BrokerageCapabilitiesProjectionCopyWith
    on BrokerageCapabilitiesProjection {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageCapabilitiesProjection.copyWith(...)` or like so:`instanceOfBrokerageCapabilitiesProjection.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageCapabilitiesProjectionCWProxy get copyWith =>
      _$BrokerageCapabilitiesProjectionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageCapabilitiesProjection _$BrokerageCapabilitiesProjectionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokerageCapabilitiesProjection',
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
    final val = BrokerageCapabilitiesProjection(
      accountId: $checkedConvert('account_id', (v) => v as String),
      data: $checkedConvert(
        'data',
        (v) => v == null
            ? null
            : BrokerageAccountAuthority.fromJson(v as Map<String, dynamic>),
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
          _$BrokerageCapabilitiesProjectionResourceEnumEnumMap,
          v,
          unknownValue:
              BrokerageCapabilitiesProjectionResourceEnum.unknownDefaultOpenApi,
        ),
      ),
      state: $checkedConvert(
        'state',
        (v) => $enumDecode(
          _$BrokerageCapabilitiesProjectionStateEnumEnumMap,
          v,
          unknownValue:
              BrokerageCapabilitiesProjectionStateEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$BrokerageCapabilitiesProjectionToJson(
  BrokerageCapabilitiesProjection instance,
) => <String, dynamic>{
  'account_id': instance.accountId,
  'data': instance.data?.toJson(),
  'expires_at': instance.expiresAt?.toIso8601String(),
  'fetched_at': instance.fetchedAt?.toIso8601String(),
  'generation': instance.generation,
  'provider_observed_at': instance.providerObservedAt?.toIso8601String(),
  'reason': instance.reason,
  'resource':
      _$BrokerageCapabilitiesProjectionResourceEnumEnumMap[instance.resource]!,
  'state': _$BrokerageCapabilitiesProjectionStateEnumEnumMap[instance.state]!,
};

const _$BrokerageCapabilitiesProjectionResourceEnumEnumMap = {
  BrokerageCapabilitiesProjectionResourceEnum.account: 'account',
  BrokerageCapabilitiesProjectionResourceEnum.balance: 'balance',
  BrokerageCapabilitiesProjectionResourceEnum.positions: 'positions',
  BrokerageCapabilitiesProjectionResourceEnum.restrictions: 'restrictions',
  BrokerageCapabilitiesProjectionResourceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$BrokerageCapabilitiesProjectionStateEnumEnumMap = {
  BrokerageCapabilitiesProjectionStateEnum.fresh: 'fresh',
  BrokerageCapabilitiesProjectionStateEnum.empty: 'empty',
  BrokerageCapabilitiesProjectionStateEnum.stale: 'stale',
  BrokerageCapabilitiesProjectionStateEnum.partial: 'partial',
  BrokerageCapabilitiesProjectionStateEnum.unavailable: 'unavailable',
  BrokerageCapabilitiesProjectionStateEnum.offline: 'offline',
  BrokerageCapabilitiesProjectionStateEnum.rateLimited: 'rate_limited',
  BrokerageCapabilitiesProjectionStateEnum.disconnected: 'disconnected',
  BrokerageCapabilitiesProjectionStateEnum.reauthorizationRequired:
      'reauthorization_required',
  BrokerageCapabilitiesProjectionStateEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
