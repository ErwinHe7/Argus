// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'portfolio_activity.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PortfolioActivityCWProxy {
  PortfolioActivity cash(SignedMoney cash);

  PortfolioActivity demo(SimulationDemoDisclosure demo);

  PortfolioActivity descriptionCode(String descriptionCode);

  PortfolioActivity effectiveAt(DateTime effectiveAt);

  PortfolioActivity id(String id);

  PortfolioActivity ledgerWatermark(int ledgerWatermark);

  PortfolioActivity type(PortfolioActivityTypeEnum type);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PortfolioActivity(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PortfolioActivity(...).copyWith(id: 12, name: "My name")
  /// ````
  PortfolioActivity call({
    SignedMoney cash,
    SimulationDemoDisclosure demo,
    String descriptionCode,
    DateTime effectiveAt,
    String id,
    int ledgerWatermark,
    PortfolioActivityTypeEnum type,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPortfolioActivity.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPortfolioActivity.copyWith.fieldName(...)`
class _$PortfolioActivityCWProxyImpl implements _$PortfolioActivityCWProxy {
  const _$PortfolioActivityCWProxyImpl(this._value);

  final PortfolioActivity _value;

  @override
  PortfolioActivity cash(SignedMoney cash) => this(cash: cash);

  @override
  PortfolioActivity demo(SimulationDemoDisclosure demo) => this(demo: demo);

  @override
  PortfolioActivity descriptionCode(String descriptionCode) =>
      this(descriptionCode: descriptionCode);

  @override
  PortfolioActivity effectiveAt(DateTime effectiveAt) =>
      this(effectiveAt: effectiveAt);

  @override
  PortfolioActivity id(String id) => this(id: id);

  @override
  PortfolioActivity ledgerWatermark(int ledgerWatermark) =>
      this(ledgerWatermark: ledgerWatermark);

  @override
  PortfolioActivity type(PortfolioActivityTypeEnum type) => this(type: type);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PortfolioActivity(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PortfolioActivity(...).copyWith(id: 12, name: "My name")
  /// ````
  PortfolioActivity call({
    Object? cash = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? descriptionCode = const $CopyWithPlaceholder(),
    Object? effectiveAt = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? ledgerWatermark = const $CopyWithPlaceholder(),
    Object? type = const $CopyWithPlaceholder(),
  }) {
    return PortfolioActivity(
      cash: cash == const $CopyWithPlaceholder()
          ? _value.cash
          // ignore: cast_nullable_to_non_nullable
          : cash as SignedMoney,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as SimulationDemoDisclosure,
      descriptionCode: descriptionCode == const $CopyWithPlaceholder()
          ? _value.descriptionCode
          // ignore: cast_nullable_to_non_nullable
          : descriptionCode as String,
      effectiveAt: effectiveAt == const $CopyWithPlaceholder()
          ? _value.effectiveAt
          // ignore: cast_nullable_to_non_nullable
          : effectiveAt as DateTime,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      ledgerWatermark: ledgerWatermark == const $CopyWithPlaceholder()
          ? _value.ledgerWatermark
          // ignore: cast_nullable_to_non_nullable
          : ledgerWatermark as int,
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as PortfolioActivityTypeEnum,
    );
  }
}

extension $PortfolioActivityCopyWith on PortfolioActivity {
  /// Returns a callable class that can be used as follows: `instanceOfPortfolioActivity.copyWith(...)` or like so:`instanceOfPortfolioActivity.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PortfolioActivityCWProxy get copyWith =>
      _$PortfolioActivityCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PortfolioActivity _$PortfolioActivityFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'PortfolioActivity',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'cash',
            'demo',
            'description_code',
            'effective_at',
            'id',
            'ledger_watermark',
            'type',
          ],
        );
        final val = PortfolioActivity(
          cash: $checkedConvert(
            'cash',
            (v) => SignedMoney.fromJson(v as Map<String, dynamic>),
          ),
          demo: $checkedConvert(
            'demo',
            (v) => SimulationDemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          descriptionCode: $checkedConvert(
            'description_code',
            (v) => v as String,
          ),
          effectiveAt: $checkedConvert(
            'effective_at',
            (v) => DateTime.parse(v as String),
          ),
          id: $checkedConvert('id', (v) => v as String),
          ledgerWatermark: $checkedConvert(
            'ledger_watermark',
            (v) => (v as num).toInt(),
          ),
          type: $checkedConvert(
            'type',
            (v) => $enumDecode(
              _$PortfolioActivityTypeEnumEnumMap,
              v,
              unknownValue: PortfolioActivityTypeEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'descriptionCode': 'description_code',
        'effectiveAt': 'effective_at',
        'ledgerWatermark': 'ledger_watermark',
      },
    );

Map<String, dynamic> _$PortfolioActivityToJson(PortfolioActivity instance) =>
    <String, dynamic>{
      'cash': instance.cash.toJson(),
      'demo': instance.demo.toJson(),
      'description_code': instance.descriptionCode,
      'effective_at': instance.effectiveAt.toIso8601String(),
      'id': instance.id,
      'ledger_watermark': instance.ledgerWatermark,
      'type': _$PortfolioActivityTypeEnumEnumMap[instance.type]!,
    };

const _$PortfolioActivityTypeEnumEnumMap = {
  PortfolioActivityTypeEnum.contribution: 'contribution',
  PortfolioActivityTypeEnum.order: 'order',
  PortfolioActivityTypeEnum.rebalance: 'rebalance',
  PortfolioActivityTypeEnum.recurring: 'recurring',
  PortfolioActivityTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
