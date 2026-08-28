// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_capability.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageCapabilityCWProxy {
  BrokerageCapability available(bool available);

  BrokerageCapability capability(BrokerageCapabilityCapabilityEnum capability);

  BrokerageCapability providerCode(String providerCode);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageCapability(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageCapability(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageCapability call({
    bool available,
    BrokerageCapabilityCapabilityEnum capability,
    String providerCode,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageCapability.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageCapability.copyWith.fieldName(...)`
class _$BrokerageCapabilityCWProxyImpl implements _$BrokerageCapabilityCWProxy {
  const _$BrokerageCapabilityCWProxyImpl(this._value);

  final BrokerageCapability _value;

  @override
  BrokerageCapability available(bool available) => this(available: available);

  @override
  BrokerageCapability capability(
    BrokerageCapabilityCapabilityEnum capability,
  ) => this(capability: capability);

  @override
  BrokerageCapability providerCode(String providerCode) =>
      this(providerCode: providerCode);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageCapability(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageCapability(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageCapability call({
    Object? available = const $CopyWithPlaceholder(),
    Object? capability = const $CopyWithPlaceholder(),
    Object? providerCode = const $CopyWithPlaceholder(),
  }) {
    return BrokerageCapability(
      available: available == const $CopyWithPlaceholder()
          ? _value.available
          // ignore: cast_nullable_to_non_nullable
          : available as bool,
      capability: capability == const $CopyWithPlaceholder()
          ? _value.capability
          // ignore: cast_nullable_to_non_nullable
          : capability as BrokerageCapabilityCapabilityEnum,
      providerCode: providerCode == const $CopyWithPlaceholder()
          ? _value.providerCode
          // ignore: cast_nullable_to_non_nullable
          : providerCode as String,
    );
  }
}

extension $BrokerageCapabilityCopyWith on BrokerageCapability {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageCapability.copyWith(...)` or like so:`instanceOfBrokerageCapability.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageCapabilityCWProxy get copyWith =>
      _$BrokerageCapabilityCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageCapability _$BrokerageCapabilityFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BrokerageCapability', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['available', 'capability', 'provider_code'],
      );
      final val = BrokerageCapability(
        available: $checkedConvert('available', (v) => v as bool),
        capability: $checkedConvert(
          'capability',
          (v) => $enumDecode(
            _$BrokerageCapabilityCapabilityEnumEnumMap,
            v,
            unknownValue:
                BrokerageCapabilityCapabilityEnum.unknownDefaultOpenApi,
          ),
        ),
        providerCode: $checkedConvert('provider_code', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'providerCode': 'provider_code'});

Map<String, dynamic> _$BrokerageCapabilityToJson(
  BrokerageCapability instance,
) => <String, dynamic>{
  'available': instance.available,
  'capability':
      _$BrokerageCapabilityCapabilityEnumEnumMap[instance.capability]!,
  'provider_code': instance.providerCode,
};

const _$BrokerageCapabilityCapabilityEnumEnumMap = {
  BrokerageCapabilityCapabilityEnum.balancesRead: 'balances_read',
  BrokerageCapabilityCapabilityEnum.positionsRead: 'positions_read',
  BrokerageCapabilityCapabilityEnum.ordersRead: 'orders_read',
  BrokerageCapabilityCapabilityEnum.manualOrders: 'manual_orders',
  BrokerageCapabilityCapabilityEnum.unsupported: 'unsupported',
  BrokerageCapabilityCapabilityEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
