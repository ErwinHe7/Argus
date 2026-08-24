// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_portfolio_holdings200_response_data_inner.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ListPortfolioHoldings200ResponseDataInnerCWProxy {
  ListPortfolioHoldings200ResponseDataInner asOfTransactionId(
    String asOfTransactionId,
  );

  ListPortfolioHoldings200ResponseDataInner assetId(String assetId);

  ListPortfolioHoldings200ResponseDataInner ledgerWatermark(
    int ledgerWatermark,
  );

  ListPortfolioHoldings200ResponseDataInner marketValue(Money marketValue);

  ListPortfolioHoldings200ResponseDataInner quantity(Quantity quantity);

  ListPortfolioHoldings200ResponseDataInner symbol(String symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolioHoldings200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolioHoldings200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolioHoldings200ResponseDataInner call({
    String asOfTransactionId,
    String assetId,
    int ledgerWatermark,
    Money marketValue,
    Quantity quantity,
    String symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfListPortfolioHoldings200ResponseDataInner.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfListPortfolioHoldings200ResponseDataInner.copyWith.fieldName(...)`
class _$ListPortfolioHoldings200ResponseDataInnerCWProxyImpl
    implements _$ListPortfolioHoldings200ResponseDataInnerCWProxy {
  const _$ListPortfolioHoldings200ResponseDataInnerCWProxyImpl(this._value);

  final ListPortfolioHoldings200ResponseDataInner _value;

  @override
  ListPortfolioHoldings200ResponseDataInner asOfTransactionId(
    String asOfTransactionId,
  ) => this(asOfTransactionId: asOfTransactionId);

  @override
  ListPortfolioHoldings200ResponseDataInner assetId(String assetId) =>
      this(assetId: assetId);

  @override
  ListPortfolioHoldings200ResponseDataInner ledgerWatermark(
    int ledgerWatermark,
  ) => this(ledgerWatermark: ledgerWatermark);

  @override
  ListPortfolioHoldings200ResponseDataInner marketValue(Money marketValue) =>
      this(marketValue: marketValue);

  @override
  ListPortfolioHoldings200ResponseDataInner quantity(Quantity quantity) =>
      this(quantity: quantity);

  @override
  ListPortfolioHoldings200ResponseDataInner symbol(String symbol) =>
      this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ListPortfolioHoldings200ResponseDataInner(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ListPortfolioHoldings200ResponseDataInner(...).copyWith(id: 12, name: "My name")
  /// ````
  ListPortfolioHoldings200ResponseDataInner call({
    Object? asOfTransactionId = const $CopyWithPlaceholder(),
    Object? assetId = const $CopyWithPlaceholder(),
    Object? ledgerWatermark = const $CopyWithPlaceholder(),
    Object? marketValue = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return ListPortfolioHoldings200ResponseDataInner(
      asOfTransactionId: asOfTransactionId == const $CopyWithPlaceholder()
          ? _value.asOfTransactionId
          // ignore: cast_nullable_to_non_nullable
          : asOfTransactionId as String,
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      ledgerWatermark: ledgerWatermark == const $CopyWithPlaceholder()
          ? _value.ledgerWatermark
          // ignore: cast_nullable_to_non_nullable
          : ledgerWatermark as int,
      marketValue: marketValue == const $CopyWithPlaceholder()
          ? _value.marketValue
          // ignore: cast_nullable_to_non_nullable
          : marketValue as Money,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as Quantity,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
    );
  }
}

extension $ListPortfolioHoldings200ResponseDataInnerCopyWith
    on ListPortfolioHoldings200ResponseDataInner {
  /// Returns a callable class that can be used as follows: `instanceOfListPortfolioHoldings200ResponseDataInner.copyWith(...)` or like so:`instanceOfListPortfolioHoldings200ResponseDataInner.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ListPortfolioHoldings200ResponseDataInnerCWProxy get copyWith =>
      _$ListPortfolioHoldings200ResponseDataInnerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListPortfolioHoldings200ResponseDataInner
_$ListPortfolioHoldings200ResponseDataInnerFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ListPortfolioHoldings200ResponseDataInner',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'as_of_transaction_id',
        'asset_id',
        'ledger_watermark',
        'market_value',
        'quantity',
        'symbol',
      ],
    );
    final val = ListPortfolioHoldings200ResponseDataInner(
      asOfTransactionId: $checkedConvert(
        'as_of_transaction_id',
        (v) => v as String,
      ),
      assetId: $checkedConvert('asset_id', (v) => v as String),
      ledgerWatermark: $checkedConvert(
        'ledger_watermark',
        (v) => (v as num).toInt(),
      ),
      marketValue: $checkedConvert(
        'market_value',
        (v) => Money.fromJson(v as Map<String, dynamic>),
      ),
      quantity: $checkedConvert(
        'quantity',
        (v) => Quantity.fromJson(v as Map<String, dynamic>),
      ),
      symbol: $checkedConvert('symbol', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'asOfTransactionId': 'as_of_transaction_id',
    'assetId': 'asset_id',
    'ledgerWatermark': 'ledger_watermark',
    'marketValue': 'market_value',
  },
);

Map<String, dynamic> _$ListPortfolioHoldings200ResponseDataInnerToJson(
  ListPortfolioHoldings200ResponseDataInner instance,
) => <String, dynamic>{
  'as_of_transaction_id': instance.asOfTransactionId,
  'asset_id': instance.assetId,
  'ledger_watermark': instance.ledgerWatermark,
  'market_value': instance.marketValue.toJson(),
  'quantity': instance.quantity.toJson(),
  'symbol': instance.symbol,
};
