// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_admin_asset_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchAdminAssetRequestCWProxy {
  PatchAdminAssetRequest assetType(String? assetType);

  PatchAdminAssetRequest currency(PatchAdminAssetRequestCurrencyEnum? currency);

  PatchAdminAssetRequest exchange(String? exchange);

  PatchAdminAssetRequest name(String? name);

  PatchAdminAssetRequest status(PatchAdminAssetRequestStatusEnum? status);

  PatchAdminAssetRequest symbol(String? symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminAssetRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminAssetRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminAssetRequest call({
    String? assetType,
    PatchAdminAssetRequestCurrencyEnum? currency,
    String? exchange,
    String? name,
    PatchAdminAssetRequestStatusEnum? status,
    String? symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchAdminAssetRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchAdminAssetRequest.copyWith.fieldName(...)`
class _$PatchAdminAssetRequestCWProxyImpl
    implements _$PatchAdminAssetRequestCWProxy {
  const _$PatchAdminAssetRequestCWProxyImpl(this._value);

  final PatchAdminAssetRequest _value;

  @override
  PatchAdminAssetRequest assetType(String? assetType) =>
      this(assetType: assetType);

  @override
  PatchAdminAssetRequest currency(
    PatchAdminAssetRequestCurrencyEnum? currency,
  ) => this(currency: currency);

  @override
  PatchAdminAssetRequest exchange(String? exchange) => this(exchange: exchange);

  @override
  PatchAdminAssetRequest name(String? name) => this(name: name);

  @override
  PatchAdminAssetRequest status(PatchAdminAssetRequestStatusEnum? status) =>
      this(status: status);

  @override
  PatchAdminAssetRequest symbol(String? symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchAdminAssetRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchAdminAssetRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchAdminAssetRequest call({
    Object? assetType = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? exchange = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return PatchAdminAssetRequest(
      assetType: assetType == const $CopyWithPlaceholder()
          ? _value.assetType
          // ignore: cast_nullable_to_non_nullable
          : assetType as String?,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as PatchAdminAssetRequestCurrencyEnum?,
      exchange: exchange == const $CopyWithPlaceholder()
          ? _value.exchange
          // ignore: cast_nullable_to_non_nullable
          : exchange as String?,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as PatchAdminAssetRequestStatusEnum?,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String?,
    );
  }
}

extension $PatchAdminAssetRequestCopyWith on PatchAdminAssetRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchAdminAssetRequest.copyWith(...)` or like so:`instanceOfPatchAdminAssetRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchAdminAssetRequestCWProxy get copyWith =>
      _$PatchAdminAssetRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchAdminAssetRequest _$PatchAdminAssetRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PatchAdminAssetRequest', json, ($checkedConvert) {
  final val = PatchAdminAssetRequest(
    assetType: $checkedConvert('asset_type', (v) => v as String?),
    currency: $checkedConvert(
      'currency',
      (v) => $enumDecodeNullable(
        _$PatchAdminAssetRequestCurrencyEnumEnumMap,
        v,
        unknownValue: PatchAdminAssetRequestCurrencyEnum.unknownDefaultOpenApi,
      ),
    ),
    exchange: $checkedConvert('exchange', (v) => v as String?),
    name: $checkedConvert('name', (v) => v as String?),
    status: $checkedConvert(
      'status',
      (v) => $enumDecodeNullable(
        _$PatchAdminAssetRequestStatusEnumEnumMap,
        v,
        unknownValue: PatchAdminAssetRequestStatusEnum.unknownDefaultOpenApi,
      ),
    ),
    symbol: $checkedConvert('symbol', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'assetType': 'asset_type'});

Map<String, dynamic> _$PatchAdminAssetRequestToJson(
  PatchAdminAssetRequest instance,
) => <String, dynamic>{
  'asset_type': ?instance.assetType,
  'currency': ?_$PatchAdminAssetRequestCurrencyEnumEnumMap[instance.currency],
  'exchange': ?instance.exchange,
  'name': ?instance.name,
  'status': ?_$PatchAdminAssetRequestStatusEnumEnumMap[instance.status],
  'symbol': ?instance.symbol,
};

const _$PatchAdminAssetRequestCurrencyEnumEnumMap = {
  PatchAdminAssetRequestCurrencyEnum.USD: 'USD',
  PatchAdminAssetRequestCurrencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$PatchAdminAssetRequestStatusEnumEnumMap = {
  PatchAdminAssetRequestStatusEnum.active: 'active',
  PatchAdminAssetRequestStatusEnum.inactive: 'inactive',
  PatchAdminAssetRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
