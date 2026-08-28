// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_brokerage_order_intent.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PlaceBrokerageOrderIntentCWProxy {
  PlaceBrokerageOrderIntent instrumentId(String instrumentId);

  PlaceBrokerageOrderIntent limitPrice(String? limitPrice);

  PlaceBrokerageOrderIntent orderType(
    PlaceBrokerageOrderIntentOrderTypeEnum orderType,
  );

  PlaceBrokerageOrderIntent quantity(String quantity);

  PlaceBrokerageOrderIntent side(PlaceBrokerageOrderIntentSideEnum side);

  PlaceBrokerageOrderIntent timeInForce(
    PlaceBrokerageOrderIntentTimeInForceEnum timeInForce,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PlaceBrokerageOrderIntent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PlaceBrokerageOrderIntent(...).copyWith(id: 12, name: "My name")
  /// ````
  PlaceBrokerageOrderIntent call({
    String instrumentId,
    String? limitPrice,
    PlaceBrokerageOrderIntentOrderTypeEnum orderType,
    String quantity,
    PlaceBrokerageOrderIntentSideEnum side,
    PlaceBrokerageOrderIntentTimeInForceEnum timeInForce,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPlaceBrokerageOrderIntent.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPlaceBrokerageOrderIntent.copyWith.fieldName(...)`
class _$PlaceBrokerageOrderIntentCWProxyImpl
    implements _$PlaceBrokerageOrderIntentCWProxy {
  const _$PlaceBrokerageOrderIntentCWProxyImpl(this._value);

  final PlaceBrokerageOrderIntent _value;

  @override
  PlaceBrokerageOrderIntent instrumentId(String instrumentId) =>
      this(instrumentId: instrumentId);

  @override
  PlaceBrokerageOrderIntent limitPrice(String? limitPrice) =>
      this(limitPrice: limitPrice);

  @override
  PlaceBrokerageOrderIntent orderType(
    PlaceBrokerageOrderIntentOrderTypeEnum orderType,
  ) => this(orderType: orderType);

  @override
  PlaceBrokerageOrderIntent quantity(String quantity) =>
      this(quantity: quantity);

  @override
  PlaceBrokerageOrderIntent side(PlaceBrokerageOrderIntentSideEnum side) =>
      this(side: side);

  @override
  PlaceBrokerageOrderIntent timeInForce(
    PlaceBrokerageOrderIntentTimeInForceEnum timeInForce,
  ) => this(timeInForce: timeInForce);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PlaceBrokerageOrderIntent(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PlaceBrokerageOrderIntent(...).copyWith(id: 12, name: "My name")
  /// ````
  PlaceBrokerageOrderIntent call({
    Object? instrumentId = const $CopyWithPlaceholder(),
    Object? limitPrice = const $CopyWithPlaceholder(),
    Object? orderType = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? side = const $CopyWithPlaceholder(),
    Object? timeInForce = const $CopyWithPlaceholder(),
  }) {
    return PlaceBrokerageOrderIntent(
      instrumentId: instrumentId == const $CopyWithPlaceholder()
          ? _value.instrumentId
          // ignore: cast_nullable_to_non_nullable
          : instrumentId as String,
      limitPrice: limitPrice == const $CopyWithPlaceholder()
          ? _value.limitPrice
          // ignore: cast_nullable_to_non_nullable
          : limitPrice as String?,
      orderType: orderType == const $CopyWithPlaceholder()
          ? _value.orderType
          // ignore: cast_nullable_to_non_nullable
          : orderType as PlaceBrokerageOrderIntentOrderTypeEnum,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as String,
      side: side == const $CopyWithPlaceholder()
          ? _value.side
          // ignore: cast_nullable_to_non_nullable
          : side as PlaceBrokerageOrderIntentSideEnum,
      timeInForce: timeInForce == const $CopyWithPlaceholder()
          ? _value.timeInForce
          // ignore: cast_nullable_to_non_nullable
          : timeInForce as PlaceBrokerageOrderIntentTimeInForceEnum,
    );
  }
}

extension $PlaceBrokerageOrderIntentCopyWith on PlaceBrokerageOrderIntent {
  /// Returns a callable class that can be used as follows: `instanceOfPlaceBrokerageOrderIntent.copyWith(...)` or like so:`instanceOfPlaceBrokerageOrderIntent.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PlaceBrokerageOrderIntentCWProxy get copyWith =>
      _$PlaceBrokerageOrderIntentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlaceBrokerageOrderIntent _$PlaceBrokerageOrderIntentFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PlaceBrokerageOrderIntent',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'instrument_id',
        'limit_price',
        'order_type',
        'quantity',
        'side',
        'time_in_force',
      ],
    );
    final val = PlaceBrokerageOrderIntent(
      instrumentId: $checkedConvert('instrument_id', (v) => v as String),
      limitPrice: $checkedConvert('limit_price', (v) => v as String?),
      orderType: $checkedConvert(
        'order_type',
        (v) => $enumDecode(
          _$PlaceBrokerageOrderIntentOrderTypeEnumEnumMap,
          v,
          unknownValue:
              PlaceBrokerageOrderIntentOrderTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      quantity: $checkedConvert('quantity', (v) => v as String),
      side: $checkedConvert(
        'side',
        (v) => $enumDecode(
          _$PlaceBrokerageOrderIntentSideEnumEnumMap,
          v,
          unknownValue: PlaceBrokerageOrderIntentSideEnum.unknownDefaultOpenApi,
        ),
      ),
      timeInForce: $checkedConvert(
        'time_in_force',
        (v) => $enumDecode(
          _$PlaceBrokerageOrderIntentTimeInForceEnumEnumMap,
          v,
          unknownValue:
              PlaceBrokerageOrderIntentTimeInForceEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'instrumentId': 'instrument_id',
    'limitPrice': 'limit_price',
    'orderType': 'order_type',
    'timeInForce': 'time_in_force',
  },
);

Map<String, dynamic> _$PlaceBrokerageOrderIntentToJson(
  PlaceBrokerageOrderIntent instance,
) => <String, dynamic>{
  'instrument_id': instance.instrumentId,
  'limit_price': instance.limitPrice,
  'order_type':
      _$PlaceBrokerageOrderIntentOrderTypeEnumEnumMap[instance.orderType]!,
  'quantity': instance.quantity,
  'side': _$PlaceBrokerageOrderIntentSideEnumEnumMap[instance.side]!,
  'time_in_force':
      _$PlaceBrokerageOrderIntentTimeInForceEnumEnumMap[instance.timeInForce]!,
};

const _$PlaceBrokerageOrderIntentOrderTypeEnumEnumMap = {
  PlaceBrokerageOrderIntentOrderTypeEnum.market: 'market',
  PlaceBrokerageOrderIntentOrderTypeEnum.limit: 'limit',
  PlaceBrokerageOrderIntentOrderTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PlaceBrokerageOrderIntentSideEnumEnumMap = {
  PlaceBrokerageOrderIntentSideEnum.buy: 'buy',
  PlaceBrokerageOrderIntentSideEnum.sell: 'sell',
  PlaceBrokerageOrderIntentSideEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PlaceBrokerageOrderIntentTimeInForceEnumEnumMap = {
  PlaceBrokerageOrderIntentTimeInForceEnum.day: 'day',
  PlaceBrokerageOrderIntentTimeInForceEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
