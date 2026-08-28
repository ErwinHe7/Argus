// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brokerage_asset.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrokerageAssetCWProxy {
  BrokerageAsset assetKind(BrokerageAssetAssetKindEnum assetKind);

  BrokerageAsset currency(String currency);

  BrokerageAsset exchange(String? exchange);

  BrokerageAsset instrumentId(String instrumentId);

  BrokerageAsset marketTimezone(String marketTimezone);

  BrokerageAsset name(String name);

  BrokerageAsset providerAssetKind(String providerAssetKind);

  BrokerageAsset supported(bool supported);

  BrokerageAsset symbol(String symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageAsset(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageAsset(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageAsset call({
    BrokerageAssetAssetKindEnum assetKind,
    String currency,
    String? exchange,
    String instrumentId,
    String marketTimezone,
    String name,
    String providerAssetKind,
    bool supported,
    String symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrokerageAsset.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrokerageAsset.copyWith.fieldName(...)`
class _$BrokerageAssetCWProxyImpl implements _$BrokerageAssetCWProxy {
  const _$BrokerageAssetCWProxyImpl(this._value);

  final BrokerageAsset _value;

  @override
  BrokerageAsset assetKind(BrokerageAssetAssetKindEnum assetKind) =>
      this(assetKind: assetKind);

  @override
  BrokerageAsset currency(String currency) => this(currency: currency);

  @override
  BrokerageAsset exchange(String? exchange) => this(exchange: exchange);

  @override
  BrokerageAsset instrumentId(String instrumentId) =>
      this(instrumentId: instrumentId);

  @override
  BrokerageAsset marketTimezone(String marketTimezone) =>
      this(marketTimezone: marketTimezone);

  @override
  BrokerageAsset name(String name) => this(name: name);

  @override
  BrokerageAsset providerAssetKind(String providerAssetKind) =>
      this(providerAssetKind: providerAssetKind);

  @override
  BrokerageAsset supported(bool supported) => this(supported: supported);

  @override
  BrokerageAsset symbol(String symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrokerageAsset(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrokerageAsset(...).copyWith(id: 12, name: "My name")
  /// ````
  BrokerageAsset call({
    Object? assetKind = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? exchange = const $CopyWithPlaceholder(),
    Object? instrumentId = const $CopyWithPlaceholder(),
    Object? marketTimezone = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? providerAssetKind = const $CopyWithPlaceholder(),
    Object? supported = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return BrokerageAsset(
      assetKind: assetKind == const $CopyWithPlaceholder()
          ? _value.assetKind
          // ignore: cast_nullable_to_non_nullable
          : assetKind as BrokerageAssetAssetKindEnum,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as String,
      exchange: exchange == const $CopyWithPlaceholder()
          ? _value.exchange
          // ignore: cast_nullable_to_non_nullable
          : exchange as String?,
      instrumentId: instrumentId == const $CopyWithPlaceholder()
          ? _value.instrumentId
          // ignore: cast_nullable_to_non_nullable
          : instrumentId as String,
      marketTimezone: marketTimezone == const $CopyWithPlaceholder()
          ? _value.marketTimezone
          // ignore: cast_nullable_to_non_nullable
          : marketTimezone as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      providerAssetKind: providerAssetKind == const $CopyWithPlaceholder()
          ? _value.providerAssetKind
          // ignore: cast_nullable_to_non_nullable
          : providerAssetKind as String,
      supported: supported == const $CopyWithPlaceholder()
          ? _value.supported
          // ignore: cast_nullable_to_non_nullable
          : supported as bool,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
    );
  }
}

extension $BrokerageAssetCopyWith on BrokerageAsset {
  /// Returns a callable class that can be used as follows: `instanceOfBrokerageAsset.copyWith(...)` or like so:`instanceOfBrokerageAsset.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrokerageAssetCWProxy get copyWith => _$BrokerageAssetCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrokerageAsset _$BrokerageAssetFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'BrokerageAsset',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'asset_kind',
            'currency',
            'exchange',
            'instrument_id',
            'market_timezone',
            'name',
            'provider_asset_kind',
            'supported',
            'symbol',
          ],
        );
        final val = BrokerageAsset(
          assetKind: $checkedConvert(
            'asset_kind',
            (v) => $enumDecode(
              _$BrokerageAssetAssetKindEnumEnumMap,
              v,
              unknownValue: BrokerageAssetAssetKindEnum.unknownDefaultOpenApi,
            ),
          ),
          currency: $checkedConvert('currency', (v) => v as String),
          exchange: $checkedConvert('exchange', (v) => v as String?),
          instrumentId: $checkedConvert('instrument_id', (v) => v as String),
          marketTimezone: $checkedConvert(
            'market_timezone',
            (v) => v as String,
          ),
          name: $checkedConvert('name', (v) => v as String),
          providerAssetKind: $checkedConvert(
            'provider_asset_kind',
            (v) => v as String,
          ),
          supported: $checkedConvert('supported', (v) => v as bool),
          symbol: $checkedConvert('symbol', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'assetKind': 'asset_kind',
        'instrumentId': 'instrument_id',
        'marketTimezone': 'market_timezone',
        'providerAssetKind': 'provider_asset_kind',
      },
    );

Map<String, dynamic> _$BrokerageAssetToJson(BrokerageAsset instance) =>
    <String, dynamic>{
      'asset_kind': _$BrokerageAssetAssetKindEnumEnumMap[instance.assetKind]!,
      'currency': instance.currency,
      'exchange': instance.exchange,
      'instrument_id': instance.instrumentId,
      'market_timezone': instance.marketTimezone,
      'name': instance.name,
      'provider_asset_kind': instance.providerAssetKind,
      'supported': instance.supported,
      'symbol': instance.symbol,
    };

const _$BrokerageAssetAssetKindEnumEnumMap = {
  BrokerageAssetAssetKindEnum.equity: 'equity',
  BrokerageAssetAssetKindEnum.etf: 'etf',
  BrokerageAssetAssetKindEnum.unsupported: 'unsupported',
  BrokerageAssetAssetKindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
