// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AssetSummaryCWProxy {
  AssetSummary appearanceReason(String appearanceReason);

  AssetSummary assetType(AssetSummaryAssetTypeEnum assetType);

  AssetSummary currency(AssetSummaryCurrencyEnum currency);

  AssetSummary demo(DemoDisclosure demo);

  AssetSummary id(String id);

  AssetSummary name(String name);

  AssetSummary revisionId(String revisionId);

  AssetSummary slug(String slug);

  AssetSummary symbol(String symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetSummary call({
    String appearanceReason,
    AssetSummaryAssetTypeEnum assetType,
    AssetSummaryCurrencyEnum currency,
    DemoDisclosure demo,
    String id,
    String name,
    String revisionId,
    String slug,
    String symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAssetSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAssetSummary.copyWith.fieldName(...)`
class _$AssetSummaryCWProxyImpl implements _$AssetSummaryCWProxy {
  const _$AssetSummaryCWProxyImpl(this._value);

  final AssetSummary _value;

  @override
  AssetSummary appearanceReason(String appearanceReason) =>
      this(appearanceReason: appearanceReason);

  @override
  AssetSummary assetType(AssetSummaryAssetTypeEnum assetType) =>
      this(assetType: assetType);

  @override
  AssetSummary currency(AssetSummaryCurrencyEnum currency) =>
      this(currency: currency);

  @override
  AssetSummary demo(DemoDisclosure demo) => this(demo: demo);

  @override
  AssetSummary id(String id) => this(id: id);

  @override
  AssetSummary name(String name) => this(name: name);

  @override
  AssetSummary revisionId(String revisionId) => this(revisionId: revisionId);

  @override
  AssetSummary slug(String slug) => this(slug: slug);

  @override
  AssetSummary symbol(String symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AssetSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AssetSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  AssetSummary call({
    Object? appearanceReason = const $CopyWithPlaceholder(),
    Object? assetType = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return AssetSummary(
      appearanceReason: appearanceReason == const $CopyWithPlaceholder()
          ? _value.appearanceReason
          // ignore: cast_nullable_to_non_nullable
          : appearanceReason as String,
      assetType: assetType == const $CopyWithPlaceholder()
          ? _value.assetType
          // ignore: cast_nullable_to_non_nullable
          : assetType as AssetSummaryAssetTypeEnum,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as AssetSummaryCurrencyEnum,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as DemoDisclosure,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      revisionId: revisionId == const $CopyWithPlaceholder()
          ? _value.revisionId
          // ignore: cast_nullable_to_non_nullable
          : revisionId as String,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
    );
  }
}

extension $AssetSummaryCopyWith on AssetSummary {
  /// Returns a callable class that can be used as follows: `instanceOfAssetSummary.copyWith(...)` or like so:`instanceOfAssetSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AssetSummaryCWProxy get copyWith => _$AssetSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AssetSummary _$AssetSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AssetSummary',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'appearance_reason',
            'asset_type',
            'currency',
            'demo',
            'id',
            'name',
            'revision_id',
            'slug',
            'symbol',
          ],
        );
        final val = AssetSummary(
          appearanceReason: $checkedConvert(
            'appearance_reason',
            (v) => v as String,
          ),
          assetType: $checkedConvert(
            'asset_type',
            (v) => $enumDecode(
              _$AssetSummaryAssetTypeEnumEnumMap,
              v,
              unknownValue: AssetSummaryAssetTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          currency: $checkedConvert(
            'currency',
            (v) => $enumDecode(
              _$AssetSummaryCurrencyEnumEnumMap,
              v,
              unknownValue: AssetSummaryCurrencyEnum.unknownDefaultOpenApi,
            ),
          ),
          demo: $checkedConvert(
            'demo',
            (v) => DemoDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          id: $checkedConvert('id', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String),
          revisionId: $checkedConvert('revision_id', (v) => v as String),
          slug: $checkedConvert('slug', (v) => v as String),
          symbol: $checkedConvert('symbol', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'appearanceReason': 'appearance_reason',
        'assetType': 'asset_type',
        'revisionId': 'revision_id',
      },
    );

Map<String, dynamic> _$AssetSummaryToJson(AssetSummary instance) =>
    <String, dynamic>{
      'appearance_reason': instance.appearanceReason,
      'asset_type': _$AssetSummaryAssetTypeEnumEnumMap[instance.assetType]!,
      'currency': _$AssetSummaryCurrencyEnumEnumMap[instance.currency]!,
      'demo': instance.demo.toJson(),
      'id': instance.id,
      'name': instance.name,
      'revision_id': instance.revisionId,
      'slug': instance.slug,
      'symbol': instance.symbol,
    };

const _$AssetSummaryAssetTypeEnumEnumMap = {
  AssetSummaryAssetTypeEnum.equity: 'equity',
  AssetSummaryAssetTypeEnum.etf: 'etf',
  AssetSummaryAssetTypeEnum.marketIndex: 'index',
  AssetSummaryAssetTypeEnum.cash: 'cash',
  AssetSummaryAssetTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$AssetSummaryCurrencyEnumEnumMap = {
  AssetSummaryCurrencyEnum.USD: 'USD',
  AssetSummaryCurrencyEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
