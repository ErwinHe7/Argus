// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_account.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageAccountCWProxy {
  BrokerageAccount baseCurrency(String baseCurrency);

  BrokerageAccount capabilities(List<BrokerageCapability> capabilities);

  BrokerageAccount capabilityVersion(int capabilityVersion);

  BrokerageAccount connectionId(String connectionId);

  BrokerageAccount displayLabel(String displayLabel);

  BrokerageAccount expiresAt(DateTime? expiresAt);

  BrokerageAccount fetchedAt(DateTime? fetchedAt);

  BrokerageAccount id(String id);

  BrokerageAccount marketTimezone(String? marketTimezone);

  BrokerageAccount providerObservedAt(DateTime? providerObservedAt);

  BrokerageAccount selected(bool selected);

  BrokerageAccount state(BrokerageAccountStateEnum state);

  BrokerageAccount status(BrokerageAccountStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageAccount call({
    String baseCurrency,
    List<BrokerageCapability> capabilities,
    int capabilityVersion,
    String connectionId,
    String displayLabel,
    DateTime? expiresAt,
    DateTime? fetchedAt,
    String id,
    String? marketTimezone,
    DateTime? providerObservedAt,
    bool selected,
    BrokerageAccountStateEnum state,
    BrokerageAccountStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageAccount.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageAccount.copyWith.fieldName(...)`
class _$BrokerageAccountCWProxyImpl implements _$BrokerageAccountCWProxy {
  const _$BrokerageAccountCWProxyImpl(this._value);

  final BrokerageAccount _value;

  @override
  BrokerageAccount baseCurrency(String baseCurrency) =>
      this(baseCurrency: baseCurrency);

  @override
  BrokerageAccount capabilities(List<BrokerageCapability> capabilities) =>
      this(capabilities: capabilities);

  @override
  BrokerageAccount capabilityVersion(int capabilityVersion) =>
      this(capabilityVersion: capabilityVersion);

  @override
  BrokerageAccount connectionId(String connectionId) =>
      this(connectionId: connectionId);

  @override
  BrokerageAccount displayLabel(String displayLabel) =>
      this(displayLabel: displayLabel);

  @override
  BrokerageAccount expiresAt(DateTime? expiresAt) => this(expiresAt: expiresAt);

  @override
  BrokerageAccount fetchedAt(DateTime? fetchedAt) => this(fetchedAt: fetchedAt);

  @override
  BrokerageAccount id(String id) => this(id: id);

  @override
  BrokerageAccount marketTimezone(String? marketTimezone) =>
      this(marketTimezone: marketTimezone);

  @override
  BrokerageAccount providerObservedAt(DateTime? providerObservedAt) =>
      this(providerObservedAt: providerObservedAt);

  @override
  BrokerageAccount selected(bool selected) => this(selected: selected);

  @override
  BrokerageAccount state(BrokerageAccountStateEnum state) => this(state: state);

  @override
  BrokerageAccount status(BrokerageAccountStatusEnum status) =>
      this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageAccount call({
    Object? baseCurrency = const $CopyWithPlaceholder(),
    Object? capabilities = const $CopyWithPlaceholder(),
    Object? capabilityVersion = const $CopyWithPlaceholder(),
    Object? connectionId = const $CopyWithPlaceholder(),
    Object? displayLabel = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
    Object? fetchedAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? marketTimezone = const $CopyWithPlaceholder(),
    Object? providerObservedAt = const $CopyWithPlaceholder(),
    Object? selected = const $CopyWithPlaceholder(),
    Object? state = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return BrokerageAccount(
      baseCurrency: baseCurrency == const $CopyWithPlaceholder()
          ? _value.baseCurrency
          // ignore: cast_nullable_to_non_nullable
          : baseCurrency as String,
      capabilities: capabilities == const $CopyWithPlaceholder()
          ? _value.capabilities
          // ignore: cast_nullable_to_non_nullable
          : capabilities as List<BrokerageCapability>,
      capabilityVersion: capabilityVersion == const $CopyWithPlaceholder()
          ? _value.capabilityVersion
          // ignore: cast_nullable_to_non_nullable
          : capabilityVersion as int,
      connectionId: connectionId == const $CopyWithPlaceholder()
          ? _value.connectionId
          // ignore: cast_nullable_to_non_nullable
          : connectionId as String,
      displayLabel: displayLabel == const $CopyWithPlaceholder()
          ? _value.displayLabel
          // ignore: cast_nullable_to_non_nullable
          : displayLabel as String,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
      fetchedAt: fetchedAt == const $CopyWithPlaceholder()
          ? _value.fetchedAt
          // ignore: cast_nullable_to_non_nullable
          : fetchedAt as DateTime?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      marketTimezone: marketTimezone == const $CopyWithPlaceholder()
          ? _value.marketTimezone
          // ignore: cast_nullable_to_non_nullable
          : marketTimezone as String?,
      providerObservedAt: providerObservedAt == const $CopyWithPlaceholder()
          ? _value.providerObservedAt
          // ignore: cast_nullable_to_non_nullable
          : providerObservedAt as DateTime?,
      selected: selected == const $CopyWithPlaceholder()
          ? _value.selected
          // ignore: cast_nullable_to_non_nullable
          : selected as bool,
      state: state == const $CopyWithPlaceholder()
          ? _value.state
          // ignore: cast_nullable_to_non_nullable
          : state as BrokerageAccountStateEnum,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as BrokerageAccountStatusEnum,
    );
  }
}

extension $BrokerageAccountCopyWith on BrokerageAccount {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageAccount.copyWith(...)` or like so:`instanceOfBrokerageAccount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageAccountCWProxy get copyWith => _$BrokerageAccountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageAccount _$BrokerageAccountFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokerageAccount',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'base_currency',
        'capabilities',
        'capability_version',
        'connection_id',
        'display_label',
        'expires_at',
        'fetched_at',
        'id',
        'market_timezone',
        'provider_observed_at',
        'selected',
        'state',
        'status',
      ],
    );
    final val = BrokerageAccount(
      baseCurrency: $checkedConvert('base_currency', (v) => v as String),
      capabilities: $checkedConvert(
        'capabilities',
        (v) => (v as List<dynamic>)
            .map((e) => BrokerageCapability.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      capabilityVersion: $checkedConvert(
        'capability_version',
        (v) => (v as num).toInt(),
      ),
      connectionId: $checkedConvert('connection_id', (v) => v as String),
      displayLabel: $checkedConvert('display_label', (v) => v as String),
      expiresAt: $checkedConvert(
        'expires_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      fetchedAt: $checkedConvert(
        'fetched_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      id: $checkedConvert('id', (v) => v as String),
      marketTimezone: $checkedConvert('market_timezone', (v) => v as String?),
      providerObservedAt: $checkedConvert(
        'provider_observed_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      selected: $checkedConvert('selected', (v) => v as bool),
      state: $checkedConvert(
        'state',
        (v) => $enumDecode(
          _$BrokerageAccountStateEnumEnumMap,
          v,
          unknownValue: BrokerageAccountStateEnum.unknownDefaultOpenApi,
        ),
      ),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$BrokerageAccountStatusEnumEnumMap,
          v,
          unknownValue: BrokerageAccountStatusEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'baseCurrency': 'base_currency',
    'capabilityVersion': 'capability_version',
    'connectionId': 'connection_id',
    'displayLabel': 'display_label',
    'expiresAt': 'expires_at',
    'fetchedAt': 'fetched_at',
    'marketTimezone': 'market_timezone',
    'providerObservedAt': 'provider_observed_at',
  },
);

Map<String, dynamic> _$BrokerageAccountToJson(BrokerageAccount instance) =>
    <String, dynamic>{
      'base_currency': instance.baseCurrency,
      'capabilities': instance.capabilities.map((e) => e.toJson()).toList(),
      'capability_version': instance.capabilityVersion,
      'connection_id': instance.connectionId,
      'display_label': instance.displayLabel,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'fetched_at': instance.fetchedAt?.toIso8601String(),
      'id': instance.id,
      'market_timezone': instance.marketTimezone,
      'provider_observed_at': instance.providerObservedAt?.toIso8601String(),
      'selected': instance.selected,
      'state': _$BrokerageAccountStateEnumEnumMap[instance.state]!,
      'status': _$BrokerageAccountStatusEnumEnumMap[instance.status]!,
    };

const _$BrokerageAccountStateEnumEnumMap = {
  BrokerageAccountStateEnum.fresh: 'fresh',
  BrokerageAccountStateEnum.empty: 'empty',
  BrokerageAccountStateEnum.stale: 'stale',
  BrokerageAccountStateEnum.partial: 'partial',
  BrokerageAccountStateEnum.unavailable: 'unavailable',
  BrokerageAccountStateEnum.offline: 'offline',
  BrokerageAccountStateEnum.rateLimited: 'rate_limited',
  BrokerageAccountStateEnum.disconnected: 'disconnected',
  BrokerageAccountStateEnum.reauthorizationRequired: 'reauthorization_required',
  BrokerageAccountStateEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$BrokerageAccountStatusEnumEnumMap = {
  BrokerageAccountStatusEnum.available: 'available',
  BrokerageAccountStatusEnum.restricted: 'restricted',
  BrokerageAccountStatusEnum.closed: 'closed',
  BrokerageAccountStatusEnum.unavailable: 'unavailable',
  BrokerageAccountStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
