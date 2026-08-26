// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_order_preview_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateOrderPreviewRequestCWProxy {
  CreateOrderPreviewRequest assetId(String assetId);

  CreateOrderPreviewRequest notional(PositiveInputMoney? notional);

  CreateOrderPreviewRequest quantity(Quantity? quantity);

  CreateOrderPreviewRequest side(CreateOrderPreviewRequestSideEnum side);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateOrderPreviewRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateOrderPreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateOrderPreviewRequest call({
    String assetId,
    PositiveInputMoney? notional,
    Quantity? quantity,
    CreateOrderPreviewRequestSideEnum side,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateOrderPreviewRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateOrderPreviewRequest.copyWith.fieldName(...)`
class _$CreateOrderPreviewRequestCWProxyImpl
    implements _$CreateOrderPreviewRequestCWProxy {
  const _$CreateOrderPreviewRequestCWProxyImpl(this._value);

  final CreateOrderPreviewRequest _value;

  @override
  CreateOrderPreviewRequest assetId(String assetId) => this(assetId: assetId);

  @override
  CreateOrderPreviewRequest notional(PositiveInputMoney? notional) =>
      this(notional: notional);

  @override
  CreateOrderPreviewRequest quantity(Quantity? quantity) =>
      this(quantity: quantity);

  @override
  CreateOrderPreviewRequest side(CreateOrderPreviewRequestSideEnum side) =>
      this(side: side);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateOrderPreviewRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateOrderPreviewRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateOrderPreviewRequest call({
    Object? assetId = const $CopyWithPlaceholder(),
    Object? notional = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
    Object? side = const $CopyWithPlaceholder(),
  }) {
    return CreateOrderPreviewRequest(
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      notional: notional == const $CopyWithPlaceholder()
          ? _value.notional
          // ignore: cast_nullable_to_non_nullable
          : notional as PositiveInputMoney?,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as Quantity?,
      side: side == const $CopyWithPlaceholder()
          ? _value.side
          // ignore: cast_nullable_to_non_nullable
          : side as CreateOrderPreviewRequestSideEnum,
    );
  }
}

extension $CreateOrderPreviewRequestCopyWith on CreateOrderPreviewRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateOrderPreviewRequest.copyWith(...)` or like so:`instanceOfCreateOrderPreviewRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateOrderPreviewRequestCWProxy get copyWith =>
      _$CreateOrderPreviewRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateOrderPreviewRequest _$CreateOrderPreviewRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateOrderPreviewRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['asset_id', 'side']);
  final val = CreateOrderPreviewRequest(
    assetId: $checkedConvert('asset_id', (v) => v as String),
    notional: $checkedConvert(
      'notional',
      (v) => v == null
          ? null
          : PositiveInputMoney.fromJson(v as Map<String, dynamic>),
    ),
    quantity: $checkedConvert(
      'quantity',
      (v) => v == null ? null : Quantity.fromJson(v as Map<String, dynamic>),
    ),
    side: $checkedConvert(
      'side',
      (v) => $enumDecode(
        _$CreateOrderPreviewRequestSideEnumEnumMap,
        v,
        unknownValue: CreateOrderPreviewRequestSideEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'assetId': 'asset_id'});

Map<String, dynamic> _$CreateOrderPreviewRequestToJson(
  CreateOrderPreviewRequest instance,
) => <String, dynamic>{
  'asset_id': instance.assetId,
  'notional': ?instance.notional?.toJson(),
  'quantity': ?instance.quantity?.toJson(),
  'side': _$CreateOrderPreviewRequestSideEnumEnumMap[instance.side]!,
};

const _$CreateOrderPreviewRequestSideEnumEnumMap = {
  CreateOrderPreviewRequestSideEnum.buy: 'buy',
  CreateOrderPreviewRequestSideEnum.sell: 'sell',
  CreateOrderPreviewRequestSideEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
