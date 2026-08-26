// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_view.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PortfolioViewCWProxy {
  PortfolioView asOfTransactionId(String? asOfTransactionId);

  PortfolioView cash(Money cash);

  PortfolioView currency(PortfolioViewCurrencyEnum currency);

  PortfolioView demo(SimulationDemoDisclosure demo);

  PortfolioView id(String id);

  PortfolioView isDefault(bool isDefault);

  PortfolioView latestValuation(Money latestValuation);

  PortfolioView ledgerWatermark(int ledgerWatermark);

  PortfolioView name(String name);

  PortfolioView positions(
    List<ListPortfolioHoldings200ResponseDataInner> positions,
  );

  PortfolioView status(PortfolioViewStatusEnum status);

  PortfolioView targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
  );

  PortfolioView version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PortfolioView(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PortfolioView(...).copyWith(id: 12, name: "My name")
  /// ````
  PortfolioView call({
    String? asOfTransactionId,
    Money cash,
    PortfolioViewCurrencyEnum currency,
    SimulationDemoDisclosure demo,
    String id,
    bool isDefault,
    Money latestValuation,
    int ledgerWatermark,
    String name,
    List<ListPortfolioHoldings200ResponseDataInner> positions,
    PortfolioViewStatusEnum status,
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPortfolioView.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPortfolioView.copyWith.fieldName(...)`
class _$PortfolioViewCWProxyImpl implements _$PortfolioViewCWProxy {
  const _$PortfolioViewCWProxyImpl(this._value);

  final PortfolioView _value;

  @override
  PortfolioView asOfTransactionId(String? asOfTransactionId) =>
      this(asOfTransactionId: asOfTransactionId);

  @override
  PortfolioView cash(Money cash) => this(cash: cash);

  @override
  PortfolioView currency(PortfolioViewCurrencyEnum currency) =>
      this(currency: currency);

  @override
  PortfolioView demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  PortfolioView id(String id) => this(id: id);

  @override
  PortfolioView isDefault(bool isDefault) => this(isDefault: isDefault);

  @override
  PortfolioView latestValuation(Money latestValuation) =>
      this(latestValuation: latestValuation);

  @override
  PortfolioView ledgerWatermark(int ledgerWatermark) =>
      this(ledgerWatermark: ledgerWatermark);

  @override
  PortfolioView name(String name) => this(name: name);

  @override
  PortfolioView positions(
    List<ListPortfolioHoldings200ResponseDataInner> positions,
  ) => this(positions: positions);

  @override
  PortfolioView status(PortfolioViewStatusEnum status) => this(status: status);

  @override
  PortfolioView targetAllocation(
    List<CreatePortfolioRequestTargetAllocationInner> targetAllocation,
  ) => this(targetAllocation: targetAllocation);

  @override
  PortfolioView version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PortfolioView(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PortfolioView(...).copyWith(id: 12, name: "My name")
  /// ````
  PortfolioView call({
    Object? asOfTransactionId = const $CopyWithPlaceholder(),
    Object? cash = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? isDefault = const $CopyWithPlaceholder(),
    Object? latestValuation = const $CopyWithPlaceholder(),
    Object? ledgerWatermark = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? positions = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? targetAllocation = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return PortfolioView(
      asOfTransactionId: asOfTransactionId == const $CopyWithPlaceholder()
          ? _value.asOfTransactionId
          // ignore: cast_nullable_to_non_nullable
          : asOfTransactionId as String?,
      cash: cash == const $CopyWithPlaceholder()
          ? _value.cash
          // ignore: cast_nullable_to_non_nullable
          : cash as Money,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as PortfolioViewCurrencyEnum,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      isDefault: isDefault == const $CopyWithPlaceholder()
          ? _value.isDefault
          // ignore: cast_nullable_to_non_nullable
          : isDefault as bool,
      latestValuation: latestValuation == const $CopyWithPlaceholder()
          ? _value.latestValuation
          // ignore: cast_nullable_to_non_nullable
          : latestValuation as Money,
      ledgerWatermark: ledgerWatermark == const $CopyWithPlaceholder()
          ? _value.ledgerWatermark
          // ignore: cast_nullable_to_non_nullable
          : ledgerWatermark as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      positions: positions == const $CopyWithPlaceholder()
          ? _value.positions
          // ignore: cast_nullable_to_non_nullable
          : positions as List<ListPortfolioHoldings200ResponseDataInner>,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PortfolioViewStatusEnum,
      targetAllocation: targetAllocation == const $CopyWithPlaceholder()
          ? _value.targetAllocation
          // ignore: cast_nullable_to_non_nullable
          : targetAllocation
                as List<CreatePortfolioRequestTargetAllocationInner>,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $PortfolioViewCopyWith on PortfolioView {
  /// Returns a callable class that can be used as follows: `instanceOfPortfolioView.copyWith(...)` or like so:`instanceOfPortfolioView.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PortfolioViewCWProxy get copyWith => _$PortfolioViewCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PortfolioView _$PortfolioViewFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PortfolioView',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'as_of_transaction_id',
            'cash',
            'currency',
            'demo',
            'id',
            'is_default',
            'latest_valuation',
            'ledger_watermark',
            'name',
            'positions',
            'status',
            'target_allocation',
            'version',
          ],
        );
        final val = PortfolioView(
          asOfTransactionId: $checkedConvert(
            'as_of_transaction_id',
            (v) => v as String?,
          ),
          cash: $checkedConvert(
            'cash',
            (v) => Money.fromJson(v as Map<String, dynamic>),
          ),
          currency: $checkedConvert(
            'currency',
            (v) => $enumDecode(
              _$PortfolioViewCurrencyEnumEnumMap,
              v,
              unknownValue: PortfolioViewCurrencyEnum.unknownDefaultOpenApi,
            ),
          ),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          id: $checkedConvert('id', (v) => v as String),
          isDefault: $checkedConvert('is_default', (v) => v as bool),
          latestValuation: $checkedConvert(
            'latest_valuation',
            (v) => Money.fromJson(v as Map<String, dynamic>),
          ),
          ledgerWatermark: $checkedConvert(
            'ledger_watermark',
            (v) => (v as num).toInt(),
          ),
          name: $checkedConvert('name', (v) => v as String),
          positions: $checkedConvert(
            'positions',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => ListPortfolioHoldings200ResponseDataInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$PortfolioViewStatusEnumEnumMap,
              v,
              unknownValue: PortfolioViewStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          targetAllocation: $checkedConvert(
            'target_allocation',
            (v) => (v as List<dynamic>)
                .map(
                  (e) => CreatePortfolioRequestTargetAllocationInner.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'asOfTransactionId': 'as_of_transaction_id',
        'isDefault': 'is_default',
        'latestValuation': 'latest_valuation',
        'ledgerWatermark': 'ledger_watermark',
        'targetAllocation': 'target_allocation',
      },
    );

Map<String, dynamic> _$PortfolioViewToJson(PortfolioView instance) =>
    <String, dynamic>{
      'as_of_transaction_id': instance.asOfTransactionId,
      'cash': instance.cash.toJson(),
      'currency': _$PortfolioViewCurrencyEnumEnumMap[instance.currency]!,
      'demo': instance.demo.toJson(),
      'id': instance.id,
      'is_default': instance.isDefault,
      'latest_valuation': instance.latestValuation.toJson(),
      'ledger_watermark': instance.ledgerWatermark,
      'name': instance.name,
      'positions': instance.positions.map((e) => e.toJson()).toList(),
      'status': _$PortfolioViewStatusEnumEnumMap[instance.status]!,
      'target_allocation': instance.targetAllocation
          .map((e) => e.toJson())
          .toList(),
      'version': instance.version,
    };

const _$PortfolioViewCurrencyEnumEnumMap = {
  PortfolioViewCurrencyEnum.USD: 'USD',
  PortfolioViewCurrencyEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$PortfolioViewStatusEnumEnumMap = {
  PortfolioViewStatusEnum.active: 'active',
  PortfolioViewStatusEnum.archived: 'archived',
  PortfolioViewStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
