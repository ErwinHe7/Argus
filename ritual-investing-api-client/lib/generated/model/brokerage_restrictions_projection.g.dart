// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_restrictions_projection.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageRestrictionsProjectionCWProxy {
  BrokerageRestrictionsProjection accountId(String accountId);

  BrokerageRestrictionsProjection data(List<BrokerageRestriction>? data);

  BrokerageRestrictionsProjection expiresAt(DateTime? expiresAt);

  BrokerageRestrictionsProjection fetchedAt(DateTime? fetchedAt);

  BrokerageRestrictionsProjection generation(int? generation);

  BrokerageRestrictionsProjection providerObservedAt(
    DateTime? providerObservedAt,
  );

  BrokerageRestrictionsProjection reason(String? reason);

  BrokerageRestrictionsProjection resource(
    BrokerageRestrictionsProjectionResourceEnum resource,
  );

  BrokerageRestrictionsProjection state(
    BrokerageRestrictionsProjectionStateEnum state,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageRestrictionsProjection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageRestrictionsProjection(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageRestrictionsProjection call({
    String accountId,
    List<BrokerageRestriction>? data,
    DateTime? expiresAt,
    DateTime? fetchedAt,
    int? generation,
    DateTime? providerObservedAt,
    String? reason,
    BrokerageRestrictionsProjectionResourceEnum resource,
    BrokerageRestrictionsProjectionStateEnum state,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageRestrictionsProjection.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageRestrictionsProjection.copyWith.fieldName(...)`
class _$BrokerageRestrictionsProjectionCWProxyImpl
    implements _$BrokerageRestrictionsProjectionCWProxy {
  const _$BrokerageRestrictionsProjectionCWProxyImpl(this._value);

  final BrokerageRestrictionsProjection _value;

  @override
  BrokerageRestrictionsProjection accountId(String accountId) =>
      this(accountId: accountId);

  @override
  BrokerageRestrictionsProjection data(List<BrokerageRestriction>? data) =>
      this(data: data);

  @override
  BrokerageRestrictionsProjection expiresAt(DateTime? expiresAt) =>
      this(expiresAt: expiresAt);

  @override
  BrokerageRestrictionsProjection fetchedAt(DateTime? fetchedAt) =>
      this(fetchedAt: fetchedAt);

  @override
  BrokerageRestrictionsProjection generation(int? generation) =>
      this(generation: generation);

  @override
  BrokerageRestrictionsProjection providerObservedAt(
    DateTime? providerObservedAt,
  ) => this(providerObservedAt: providerObservedAt);

  @override
  BrokerageRestrictionsProjection reason(String? reason) =>
      this(reason: reason);

  @override
  BrokerageRestrictionsProjection resource(
    BrokerageRestrictionsProjectionResourceEnum resource,
  ) => this(resource: resource);

  @override
  BrokerageRestrictionsProjection state(
    BrokerageRestrictionsProjectionStateEnum state,
  ) => this(state: state);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageRestrictionsProjection(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageRestrictionsProjection(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageRestrictionsProjection call({
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
    return BrokerageRestrictionsProjection(
      accountId: accountId == const $CopyWithPlaceholder()
          ? _value.accountId
          // ignore: cast_nullable_to_non_nullable
          : accountId as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as List<BrokerageRestriction>?,
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
          : resource as BrokerageRestrictionsProjectionResourceEnum,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as BrokerageRestrictionsProjectionStateEnum,
    );
  }
}

extension $BrokerageRestrictionsProjectionCopyWith
    on BrokerageRestrictionsProjection {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageRestrictionsProjection.copyWith(...)` or like so:`instanceOfBrokerageRestrictionsProjection.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageRestrictionsProjectionCWProxy get copyWith =>
      _$BrokerageRestrictionsProjectionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageRestrictionsProjection _$BrokerageRestrictionsProjectionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokerageRestrictionsProjection',
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
    final val = BrokerageRestrictionsProjection(
      accountId: $checkedConvert('account_id', (v) => v as String),
      data: $checkedConvert(
        'data',
        (v) => (v as List<dynamic>?)
            ?.map(
              (e) => BrokerageRestriction.fromJson(e as Map<String, dynamic>),
            )
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
          _$BrokerageRestrictionsProjectionResourceEnumEnumMap,
          v,
          unknownValue:
              BrokerageRestrictionsProjectionResourceEnum.unknownDefaultOpenApi,
        ),
      ),
      state: $checkedConvert(
        'state',
        (v) => $enumDecode(
          _$BrokerageRestrictionsProjectionStateEnumEnumMap,
          v,
          unknownValue:
              BrokerageRestrictionsProjectionStateEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$BrokerageRestrictionsProjectionToJson(
  BrokerageRestrictionsProjection instance,
) => <String, dynamic>{
  'account_id': instance.accountId,
  'data': instance.data?.map((e) => e.toJson()).toList(),
  'expires_at': instance.expiresAt?.toIso8601String(),
  'fetched_at': instance.fetchedAt?.toIso8601String(),
  'generation': instance.generation,
  'provider_observed_at': instance.providerObservedAt?.toIso8601String(),
  'reason': instance.reason,
  'resource':
      _$BrokerageRestrictionsProjectionResourceEnumEnumMap[instance.resource]!,
  'state': _$BrokerageRestrictionsProjectionStateEnumEnumMap[instance.state]!,
};

const _$BrokerageRestrictionsProjectionResourceEnumEnumMap = {
  BrokerageRestrictionsProjectionResourceEnum.account: 'account',
  BrokerageRestrictionsProjectionResourceEnum.balance: 'balance',
  BrokerageRestrictionsProjectionResourceEnum.positions: 'positions',
  BrokerageRestrictionsProjectionResourceEnum.restrictions: 'restrictions',
  BrokerageRestrictionsProjectionResourceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$BrokerageRestrictionsProjectionStateEnumEnumMap = {
  BrokerageRestrictionsProjectionStateEnum.fresh: 'fresh',
  BrokerageRestrictionsProjectionStateEnum.empty: 'empty',
  BrokerageRestrictionsProjectionStateEnum.stale: 'stale',
  BrokerageRestrictionsProjectionStateEnum.partial: 'partial',
  BrokerageRestrictionsProjectionStateEnum.unavailable: 'unavailable',
  BrokerageRestrictionsProjectionStateEnum.offline: 'offline',
  BrokerageRestrictionsProjectionStateEnum.rateLimited: 'rate_limited',
  BrokerageRestrictionsProjectionStateEnum.disconnected: 'disconnected',
  BrokerageRestrictionsProjectionStateEnum.reauthorizationRequired:
      'reauthorization_required',
  BrokerageRestrictionsProjectionStateEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
