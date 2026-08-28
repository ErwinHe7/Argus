// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_restriction.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageRestrictionCWProxy {
  BrokerageRestriction active(bool active);

  BrokerageRestriction detail(String? detail);

  BrokerageRestriction providerCode(String providerCode);

  BrokerageRestriction restriction(
    BrokerageRestrictionRestrictionEnum restriction,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageRestriction(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageRestriction(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageRestriction call({
    bool active,
    String? detail,
    String providerCode,
    BrokerageRestrictionRestrictionEnum restriction,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageRestriction.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageRestriction.copyWith.fieldName(...)`
class _$BrokerageRestrictionCWProxyImpl
    implements _$BrokerageRestrictionCWProxy {
  const _$BrokerageRestrictionCWProxyImpl(this._value);

  final BrokerageRestriction _value;

  @override
  BrokerageRestriction active(bool active) => this(active: active);

  @override
  BrokerageRestriction detail(String? detail) => this(detail: detail);

  @override
  BrokerageRestriction providerCode(String providerCode) =>
      this(providerCode: providerCode);

  @override
  BrokerageRestriction restriction(
    BrokerageRestrictionRestrictionEnum restriction,
  ) => this(restriction: restriction);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageRestriction(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageRestriction(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageRestriction call({
    Object? active = const $CopyWithPlaceholder(),
    Object? detail = const $CopyWithPlaceholder(),
    Object? providerCode = const $CopyWithPlaceholder(),
    Object? restriction = const $CopyWithPlaceholder(),
  }) {
    return BrokerageRestriction(
      active: active == const $CopyWithPlaceholder()
          ? _value.active
          // ignore: cast_nullable_to_non_nullable
          : active as bool,
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as String?,
      providerCode: providerCode == const $CopyWithPlaceholder()
          ? _value.providerCode
          // ignore: cast_nullable_to_non_nullable
          : providerCode as String,
      restriction: restriction == const $CopyWithPlaceholder()
          ? _value.restriction
          // ignore: cast_nullable_to_non_nullable
          : restriction as BrokerageRestrictionRestrictionEnum,
    );
  }
}

extension $BrokerageRestrictionCopyWith on BrokerageRestriction {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageRestriction.copyWith(...)` or like so:`instanceOfBrokerageRestriction.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageRestrictionCWProxy get copyWith =>
      _$BrokerageRestrictionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageRestriction _$BrokerageRestrictionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('BrokerageRestriction', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['active', 'detail', 'provider_code', 'restriction'],
  );
  final val = BrokerageRestriction(
    active: $checkedConvert('active', (v) => v as bool),
    detail: $checkedConvert('detail', (v) => v as String?),
    providerCode: $checkedConvert('provider_code', (v) => v as String),
    restriction: $checkedConvert(
      'restriction',
      (v) => $enumDecode(
        _$BrokerageRestrictionRestrictionEnumEnumMap,
        v,
        unknownValue: BrokerageRestrictionRestrictionEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'providerCode': 'provider_code'});

Map<String, dynamic> _$BrokerageRestrictionToJson(
  BrokerageRestriction instance,
) => <String, dynamic>{
  'active': instance.active,
  'detail': instance.detail,
  'provider_code': instance.providerCode,
  'restriction':
      _$BrokerageRestrictionRestrictionEnumEnumMap[instance.restriction]!,
};

const _$BrokerageRestrictionRestrictionEnumEnumMap = {
  BrokerageRestrictionRestrictionEnum.closingOnly: 'closing_only',
  BrokerageRestrictionRestrictionEnum.tradingDisabled: 'trading_disabled',
  BrokerageRestrictionRestrictionEnum.liquidationOnly: 'liquidation_only',
  BrokerageRestrictionRestrictionEnum.unsupported: 'unsupported',
  BrokerageRestrictionRestrictionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
