// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_asset.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AdminAssetCWProxy {
  AdminAsset assetType(String assetType);

  AdminAsset currency(AdminAssetCurrencyEnum currency);

  AdminAsset etag(String etag);

  AdminAsset exchange(String? exchange);

  AdminAsset id(String id);

  AdminAsset isDemo(bool isDemo);

  AdminAsset name(String name);

  AdminAsset slug(String slug);

  AdminAsset status(AdminAssetStatusEnum status);

  AdminAsset symbol(String symbol);

  AdminAsset version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminAsset(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminAsset(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminAsset call({
    String assetType,
    AdminAssetCurrencyEnum currency,
    String etag,
    String? exchange,
    String id,
    bool isDemo,
    String name,
    String slug,
    AdminAssetStatusEnum status,
    String symbol,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAdminAsset.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAdminAsset.copyWith.fieldName(...)`
class _$AdminAssetCWProxyImpl implements _$AdminAssetCWProxy {
  const _$AdminAssetCWProxyImpl(this._value);

  final AdminAsset _value;

  @override
  AdminAsset assetType(String assetType) => this(assetType: assetType);

  @override
  AdminAsset currency(AdminAssetCurrencyEnum currency) =>
      this(currency: currency);

  @override
  AdminAsset etag(String etag) => this(etag: etag);

  @override
  AdminAsset exchange(String? exchange) => this(exchange: exchange);

  @override
  AdminAsset id(String id) => this(id: id);

  @override
  AdminAsset isDemo(bool isDemo) => this(isDemo: isDemo);

  @override
  AdminAsset name(String name) => this(name: name);

  @override
  AdminAsset slug(String slug) => this(slug: slug);

  @override
  AdminAsset status(AdminAssetStatusEnum status) => this(status: status);

  @override
  AdminAsset symbol(String symbol) => this(symbol: symbol);

  @override
  AdminAsset version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AdminAsset(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AdminAsset(...).copyWith(id: 12, name: "My name")
  /// ````
  AdminAsset call({
    Object? assetType = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? etag = const $CopyWithPlaceholder(),
    Object? exchange = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? isDemo = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return AdminAsset(
      assetType: assetType == const $CopyWithPlaceholder()
          ? _value.assetType
          // ignore: cast_nullable_to_non_nullable
          : assetType as String,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as AdminAssetCurrencyEnum,
      etag: etag == const $CopyWithPlaceholder()
          ? _value.etag
          // ignore: cast_nullable_to_non_nullable
          : etag as String,
      exchange: exchange == const $CopyWithPlaceholder()
          ? _value.exchange
          // ignore: cast_nullable_to_non_nullable
          : exchange as String?,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      isDemo: isDemo == const $CopyWithPlaceholder()
          ? _value.isDemo
          // ignore: cast_nullable_to_non_nullable
          : isDemo as bool,
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
          : status as AdminAssetStatusEnum,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $AdminAssetCopyWith on AdminAsset {
  /// Returns a callable class that can be used as follows: `instanceOfAdminAsset.copyWith(...)` or like so:`instanceOfAdminAsset.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AdminAssetCWProxy get copyWith => _$AdminAssetCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdminAsset _$AdminAssetFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AdminAsset', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'asset_type',
          'currency',
          'etag',
          'exchange',
          'id',
          'is_demo',
          'name',
          'slug',
          'status',
          'symbol',
          'version',
        ],
      );
      final val = AdminAsset(
        assetType: $checkedConvert('asset_type', (v) => v as String),
        currency: $checkedConvert(
          'currency',
          (v) => $enumDecode(
            _$AdminAssetCurrencyEnumEnumMap,
            v,
            unknownValue: AdminAssetCurrencyEnum.unknownDefaultOpenApi,
          ),
        ),
        etag: $checkedConvert('etag', (v) => v as String),
        exchange: $checkedConvert('exchange', (v) => v as String?),
        id: $checkedConvert('id', (v) => v as String),
        isDemo: $checkedConvert('is_demo', (v) => v as bool),
        name: $checkedConvert('name', (v) => v as String),
        slug: $checkedConvert('slug', (v) => v as String),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$AdminAssetStatusEnumEnumMap,
            v,
            unknownValue: AdminAssetStatusEnum.unknownDefaultOpenApi,
          ),
        ),
        symbol: $checkedConvert('symbol', (v) => v as String),
        version: $checkedConvert('version', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'assetType': 'asset_type', 'isDemo': 'is_demo'});

Map<String, dynamic> _$AdminAssetToJson(AdminAsset instance) =>
    <String, dynamic>{
      'asset_type': instance.assetType,
      'currency': _$AdminAssetCurrencyEnumEnumMap[instance.currency]!,
      'etag': instance.etag,
      'exchange': instance.exchange,
      'id': instance.id,
      'is_demo': instance.isDemo,
      'name': instance.name,
      'slug': instance.slug,
      'status': _$AdminAssetStatusEnumEnumMap[instance.status]!,
      'symbol': instance.symbol,
      'version': instance.version,
    };

const _$AdminAssetCurrencyEnumEnumMap = {
  AdminAssetCurrencyEnum.USD: 'USD',
  AdminAssetCurrencyEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$AdminAssetStatusEnumEnumMap = {
  AdminAssetStatusEnum.active: 'active',
  AdminAssetStatusEnum.inactive: 'inactive',
  AdminAssetStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
