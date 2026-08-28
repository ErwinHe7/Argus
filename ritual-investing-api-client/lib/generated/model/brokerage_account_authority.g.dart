// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_account_authority.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageAccountAuthorityCWProxy {
  BrokerageAccountAuthority baseCurrency(String baseCurrency);

  BrokerageAccountAuthority capabilities(
    List<BrokerageCapability> capabilities,
  );

  BrokerageAccountAuthority capabilityVersion(int capabilityVersion);

  BrokerageAccountAuthority displayLabel(String displayLabel);

  BrokerageAccountAuthority marketTimezone(String marketTimezone);

  BrokerageAccountAuthority status(BrokerageAccountAuthorityStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageAccountAuthority(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageAccountAuthority(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageAccountAuthority call({
    String baseCurrency,
    List<BrokerageCapability> capabilities,
    int capabilityVersion,
    String displayLabel,
    String marketTimezone,
    BrokerageAccountAuthorityStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageAccountAuthority.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageAccountAuthority.copyWith.fieldName(...)`
class _$BrokerageAccountAuthorityCWProxyImpl
    implements _$BrokerageAccountAuthorityCWProxy {
  const _$BrokerageAccountAuthorityCWProxyImpl(this._value);

  final BrokerageAccountAuthority _value;

  @override
  BrokerageAccountAuthority baseCurrency(String baseCurrency) =>
      this(baseCurrency: baseCurrency);

  @override
  BrokerageAccountAuthority capabilities(
    List<BrokerageCapability> capabilities,
  ) => this(capabilities: capabilities);

  @override
  BrokerageAccountAuthority capabilityVersion(int capabilityVersion) =>
      this(capabilityVersion: capabilityVersion);

  @override
  BrokerageAccountAuthority displayLabel(String displayLabel) =>
      this(displayLabel: displayLabel);

  @override
  BrokerageAccountAuthority marketTimezone(String marketTimezone) =>
      this(marketTimezone: marketTimezone);

  @override
  BrokerageAccountAuthority status(
    BrokerageAccountAuthorityStatusEnum status,
  ) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageAccountAuthority(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageAccountAuthority(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageAccountAuthority call({
    Object? baseCurrency = const $CopyWithPlaceholder(),
    Object? capabilities = const $CopyWithPlaceholder(),
    Object? capabilityVersion = const $CopyWithPlaceholder(),
    Object? displayLabel = const $CopyWithPlaceholder(),
    Object? marketTimezone = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return BrokerageAccountAuthority(
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
      displayLabel: displayLabel == const $CopyWithPlaceholder()
          ? _value.displayLabel
          // ignore: cast_nullable_to_non_nullable
          : displayLabel as String,
      marketTimezone: marketTimezone == const $CopyWithPlaceholder()
          ? _value.marketTimezone
          // ignore: cast_nullable_to_non_nullable
          : marketTimezone as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as BrokerageAccountAuthorityStatusEnum,
    );
  }
}

extension $BrokerageAccountAuthorityCopyWith on BrokerageAccountAuthority {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageAccountAuthority.copyWith(...)` or like so:`instanceOfBrokerageAccountAuthority.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageAccountAuthorityCWProxy get copyWith =>
      _$BrokerageAccountAuthorityCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageAccountAuthority _$BrokerageAccountAuthorityFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'BrokerageAccountAuthority',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'base_currency',
        'capabilities',
        'capability_version',
        'display_label',
        'market_timezone',
        'status',
      ],
    );
    final val = BrokerageAccountAuthority(
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
      displayLabel: $checkedConvert('display_label', (v) => v as String),
      marketTimezone: $checkedConvert('market_timezone', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$BrokerageAccountAuthorityStatusEnumEnumMap,
          v,
          unknownValue:
              BrokerageAccountAuthorityStatusEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'baseCurrency': 'base_currency',
    'capabilityVersion': 'capability_version',
    'displayLabel': 'display_label',
    'marketTimezone': 'market_timezone',
  },
);

Map<String, dynamic> _$BrokerageAccountAuthorityToJson(
  BrokerageAccountAuthority instance,
) => <String, dynamic>{
  'base_currency': instance.baseCurrency,
  'capabilities': instance.capabilities.map((e) => e.toJson()).toList(),
  'capability_version': instance.capabilityVersion,
  'display_label': instance.displayLabel,
  'market_timezone': instance.marketTimezone,
  'status': _$BrokerageAccountAuthorityStatusEnumEnumMap[instance.status]!,
};

const _$BrokerageAccountAuthorityStatusEnumEnumMap = {
  BrokerageAccountAuthorityStatusEnum.available: 'available',
  BrokerageAccountAuthorityStatusEnum.restricted: 'restricted',
  BrokerageAccountAuthorityStatusEnum.closed: 'closed',
  BrokerageAccountAuthorityStatusEnum.unavailable: 'unavailable',
  BrokerageAccountAuthorityStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
