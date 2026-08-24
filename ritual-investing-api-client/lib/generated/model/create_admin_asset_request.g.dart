// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_admin_asset_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateAdminAssetRequestCWProxy {
  CreateAdminAssetRequest assetType(String assetType);

  CreateAdminAssetRequest currency(
    CreateAdminAssetRequestCurrencyEnum currency,
  );

  CreateAdminAssetRequest exchange(String? exchange);

  CreateAdminAssetRequest name(String name);

  CreateAdminAssetRequest slug(String slug);

  CreateAdminAssetRequest status(CreateAdminAssetRequestStatusEnum status);

  CreateAdminAssetRequest symbol(String symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAssetRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAssetRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAssetRequest call({
    String assetType,
    CreateAdminAssetRequestCurrencyEnum currency,
    String? exchange,
    String name,
    String slug,
    CreateAdminAssetRequestStatusEnum status,
    String symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateAdminAssetRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateAdminAssetRequest.copyWith.fieldName(...)`
class _$CreateAdminAssetRequestCWProxyImpl
    implements _$CreateAdminAssetRequestCWProxy {
  const _$CreateAdminAssetRequestCWProxyImpl(this._value);

  final CreateAdminAssetRequest _value;

  @override
  CreateAdminAssetRequest assetType(String assetType) =>
      this(assetType: assetType);

  @override
  CreateAdminAssetRequest currency(
    CreateAdminAssetRequestCurrencyEnum currency,
  ) => this(currency: currency);

  @override
  CreateAdminAssetRequest exchange(String? exchange) =>
      this(exchange: exchange);

  @override
  CreateAdminAssetRequest name(String name) => this(name: name);

  @override
  CreateAdminAssetRequest slug(String slug) => this(slug: slug);

  @override
  CreateAdminAssetRequest status(CreateAdminAssetRequestStatusEnum status) =>
      this(status: status);

  @override
  CreateAdminAssetRequest symbol(String symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateAdminAssetRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateAdminAssetRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateAdminAssetRequest call({
    Object? assetType = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? exchange = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return CreateAdminAssetRequest(
      assetType: assetType == const $CopyWithPlaceholder()
          ? _value.assetType
          // ignore: cast_nullable_to_non_nullable
          : assetType as String,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as CreateAdminAssetRequestCurrencyEnum,
      exchange: exchange == const $CopyWithPlaceholder()
          ? _value.exchange
          // ignore: cast_nullable_to_non_nullable
          : exchange as String?,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as CreateAdminAssetRequestStatusEnum,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
    );
  }
}

extension $CreateAdminAssetRequestCopyWith on CreateAdminAssetRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCreateAdminAssetRequest.copyWith(...)` or like so:`instanceOfCreateAdminAssetRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateAdminAssetRequestCWProxy get copyWith =>
      _$CreateAdminAssetRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateAdminAssetRequest _$CreateAdminAssetRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateAdminAssetRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'asset_type',
      'currency',
      'exchange',
      'name',
      'slug',
      'status',
      'symbol',
    ],
  );
  final val = CreateAdminAssetRequest(
    assetType: $checkedConvert('asset_type', (v) => v as String),
    currency: $checkedConvert(
      'currency',
      (v) => $enumDecode(
        _$CreateAdminAssetRequestCurrencyEnumEnumMap,
        v,
        unknownValue: CreateAdminAssetRequestCurrencyEnum.unknownDefaultOpenApi,
      ),
    ),
    exchange: $checkedConvert('exchange', (v) => v as String?),
    name: $checkedConvert('name', (v) => v as String),
    slug: $checkedConvert('slug', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$CreateAdminAssetRequestStatusEnumEnumMap,
        v,
        unknownValue: CreateAdminAssetRequestStatusEnum.unknownDefaultOpenApi,
      ),
    ),
    symbol: $checkedConvert('symbol', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'assetType': 'asset_type'});

Map<String, dynamic> _$CreateAdminAssetRequestToJson(
  CreateAdminAssetRequest instance,
) => <String, dynamic>{
  'asset_type': instance.assetType,
  'currency': _$CreateAdminAssetRequestCurrencyEnumEnumMap[instance.currency]!,
  'exchange': instance.exchange,
  'name': instance.name,
  'slug': instance.slug,
  'status': _$CreateAdminAssetRequestStatusEnumEnumMap[instance.status]!,
  'symbol': instance.symbol,
};

const _$CreateAdminAssetRequestCurrencyEnumEnumMap = {
  CreateAdminAssetRequestCurrencyEnum.USD: 'USD',
  CreateAdminAssetRequestCurrencyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$CreateAdminAssetRequestStatusEnumEnumMap = {
  CreateAdminAssetRequestStatusEnum.active: 'active',
  CreateAdminAssetRequestStatusEnum.inactive: 'inactive',
  CreateAdminAssetRequestStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
