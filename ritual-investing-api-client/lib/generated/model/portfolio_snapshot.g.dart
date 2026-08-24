// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_snapshot.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PortfolioSnapshotCWProxy {
  PortfolioSnapshot asOf(DateTime asOf);

  PortfolioSnapshot asOfTransactionId(String asOfTransactionId);

  PortfolioSnapshot cash(Money cash);

  PortfolioSnapshot demo(SimulationDemoDisclosure demo);

  PortfolioSnapshot id(String id);

  PortfolioSnapshot ledgerWatermark(int ledgerWatermark);

  PortfolioSnapshot marketValue(Money marketValue);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PortfolioSnapshot(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PortfolioSnapshot(...).copyWith(id: 12, name: "My name")
  /// ````
  PortfolioSnapshot call({
    DateTime asOf,
    String asOfTransactionId,
    Money cash,
    SimulationDemoDisclosure demo,
    String id,
    int ledgerWatermark,
    Money marketValue,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPortfolioSnapshot.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPortfolioSnapshot.copyWith.fieldName(...)`
class _$PortfolioSnapshotCWProxyImpl implements _$PortfolioSnapshotCWProxy {
  const _$PortfolioSnapshotCWProxyImpl(this._value);

  final PortfolioSnapshot _value;

  @override
  PortfolioSnapshot asOf(DateTime asOf) => this(asOf: asOf);

  @override
  PortfolioSnapshot asOfTransactionId(String asOfTransactionId) =>
      this(asOfTransactionId: asOfTransactionId);

  @override
  PortfolioSnapshot cash(Money cash) => this(cash: cash);

  @override
  PortfolioSnapshot demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  PortfolioSnapshot id(String id) => this(id: id);

  @override
  PortfolioSnapshot ledgerWatermark(int ledgerWatermark) =>
      this(ledgerWatermark: ledgerWatermark);

  @override
  PortfolioSnapshot marketValue(Money marketValue) =>
      this(marketValue: marketValue);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PortfolioSnapshot(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PortfolioSnapshot(...).copyWith(id: 12, name: "My name")
  /// ````
  PortfolioSnapshot call({
    Object? asOf = const $CopyWithPlaceholder(),
    Object? asOfTransactionId = const $CopyWithPlaceholder(),
    Object? cash = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? ledgerWatermark = const $CopyWithPlaceholder(),
    Object? marketValue = const $CopyWithPlaceholder(),
  }) {
    return PortfolioSnapshot(
      asOf: asOf == const $CopyWithPlaceholder()
          ? _value.asOf
          // ignore: cast_nullable_to_non_nullable
          : asOf as DateTime,
      asOfTransactionId: asOfTransactionId == const $CopyWithPlaceholder()
          ? _value.asOfTransactionId
          // ignore: cast_nullable_to_non_nullable
          : asOfTransactionId as String,
      cash: cash == const $CopyWithPlaceholder()
          ? _value.cash
          // ignore: cast_nullable_to_non_nullable
          : cash as Money,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      ledgerWatermark: ledgerWatermark == const $CopyWithPlaceholder()
          ? _value.ledgerWatermark
          // ignore: cast_nullable_to_non_nullable
          : ledgerWatermark as int,
      marketValue: marketValue == const $CopyWithPlaceholder()
          ? _value.marketValue
          // ignore: cast_nullable_to_non_nullable
          : marketValue as Money,
    );
  }
}

extension $PortfolioSnapshotCopyWith on PortfolioSnapshot {
  /// Returns a callable class that can be used as follows: `instanceOfPortfolioSnapshot.copyWith(...)` or like so:`instanceOfPortfolioSnapshot.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PortfolioSnapshotCWProxy get copyWith =>
      _$PortfolioSnapshotCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PortfolioSnapshot _$PortfolioSnapshotFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PortfolioSnapshot',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'as_of',
            'as_of_transaction_id',
            'cash',
            'demo',
            'id',
            'ledger_watermark',
            'market_value',
          ],
        );
        final val = PortfolioSnapshot(
          asOf: $checkedConvert('as_of', (v) => DateTime.parse(v as String)),
          asOfTransactionId: $checkedConvert(
            'as_of_transaction_id',
            (v) => v as String,
          ),
          cash: $checkedConvert(
            'cash',
            (v) => Money.fromJson(v as Map<String, dynamic>),
          ),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          id: $checkedConvert('id', (v) => v as String),
          ledgerWatermark: $checkedConvert(
            'ledger_watermark',
            (v) => (v as num).toInt(),
          ),
          marketValue: $checkedConvert(
            'market_value',
            (v) => Money.fromJson(v as Map<String, dynamic>),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'asOf': 'as_of',
        'asOfTransactionId': 'as_of_transaction_id',
        'ledgerWatermark': 'ledger_watermark',
        'marketValue': 'market_value',
      },
    );

Map<String, dynamic> _$PortfolioSnapshotToJson(PortfolioSnapshot instance) =>
    <String, dynamic>{
      'as_of': instance.asOf.toIso8601String(),
      'as_of_transaction_id': instance.asOfTransactionId,
      'cash': instance.cash.toJson(),
      'demo': instance.demo.toJson(),
      'id': instance.id,
      'ledger_watermark': instance.ledgerWatermark,
      'market_value': instance.marketValue.toJson(),
    };
