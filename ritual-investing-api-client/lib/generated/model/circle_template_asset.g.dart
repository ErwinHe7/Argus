// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'circle_template_asset.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CircleTemplateAssetCWProxy {
  CircleTemplateAsset appearanceReason(String appearanceReason);

  CircleTemplateAsset assetType(CircleTemplateAssetAssetTypeEnum assetType);

  CircleTemplateAsset currency(String currency);

  CircleTemplateAsset demo(ResearchDisclosure demo);

  CircleTemplateAsset id(String id);

  CircleTemplateAsset name(String name);

  CircleTemplateAsset note(String? note);

  CircleTemplateAsset ordinal(int ordinal);

  CircleTemplateAsset revisionId(String revisionId);

  CircleTemplateAsset slug(String slug);

  CircleTemplateAsset symbol(String symbol);

  CircleTemplateAsset weightBps(int? weightBps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateAsset(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateAsset(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateAsset call({
    String appearanceReason,
    CircleTemplateAssetAssetTypeEnum assetType,
    String currency,
    ResearchDisclosure demo,
    String id,
    String name,
    String? note,
    int ordinal,
    String revisionId,
    String slug,
    String symbol,
    int? weightBps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCircleTemplateAsset.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCircleTemplateAsset.copyWith.fieldName(...)`
class _$CircleTemplateAssetCWProxyImpl implements _$CircleTemplateAssetCWProxy {
  const _$CircleTemplateAssetCWProxyImpl(this._value);

  final CircleTemplateAsset _value;

  @override
  CircleTemplateAsset appearanceReason(String appearanceReason) =>
      this(appearanceReason: appearanceReason);

  @override
  CircleTemplateAsset assetType(CircleTemplateAssetAssetTypeEnum assetType) =>
      this(assetType: assetType);

  @override
  CircleTemplateAsset currency(String currency) => this(currency: currency);

  @override
  CircleTemplateAsset demo(ResearchDisclosure demo) => this(demo: demo);

  @override
  CircleTemplateAsset id(String id) => this(id: id);

  @override
  CircleTemplateAsset name(String name) => this(name: name);

  @override
  CircleTemplateAsset note(String? note) => this(note: note);

  @override
  CircleTemplateAsset ordinal(int ordinal) => this(ordinal: ordinal);

  @override
  CircleTemplateAsset revisionId(String revisionId) =>
      this(revisionId: revisionId);

  @override
  CircleTemplateAsset slug(String slug) => this(slug: slug);

  @override
  CircleTemplateAsset symbol(String symbol) => this(symbol: symbol);

  @override
  CircleTemplateAsset weightBps(int? weightBps) => this(weightBps: weightBps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CircleTemplateAsset(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CircleTemplateAsset(...).copyWith(id: 12, name: "My name")
  /// ````
  CircleTemplateAsset call({
    Object? appearanceReason = const $CopyWithPlaceholder(),
    Object? assetType = const $CopyWithPlaceholder(),
    Object? currency = const $CopyWithPlaceholder(),
    Object? demo = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? ordinal = const $CopyWithPlaceholder(),
    Object? revisionId = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
    Object? weightBps = const $CopyWithPlaceholder(),
  }) {
    return CircleTemplateAsset(
      appearanceReason: appearanceReason == const $CopyWithPlaceholder()
          ? _value.appearanceReason
          // ignore: cast_nullable_to_non_nullable
          : appearanceReason as String,
      assetType: assetType == const $CopyWithPlaceholder()
          ? _value.assetType
          // ignore: cast_nullable_to_non_nullable
          : assetType as CircleTemplateAssetAssetTypeEnum,
      currency: currency == const $CopyWithPlaceholder()
          ? _value.currency
          // ignore: cast_nullable_to_non_nullable
          : currency as String,
      demo: demo == const $CopyWithPlaceholder()
          ? _value.demo
          // ignore: cast_nullable_to_non_nullable
          : demo as ResearchDisclosure,
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String?,
      ordinal: ordinal == const $CopyWithPlaceholder()
          ? _value.ordinal
          // ignore: cast_nullable_to_non_nullable
          : ordinal as int,
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
      weightBps: weightBps == const $CopyWithPlaceholder()
          ? _value.weightBps
          // ignore: cast_nullable_to_non_nullable
          : weightBps as int?,
    );
  }
}

extension $CircleTemplateAssetCopyWith on CircleTemplateAsset {
  /// Returns a callable class that can be used as follows: `instanceOfCircleTemplateAsset.copyWith(...)` or like so:`instanceOfCircleTemplateAsset.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CircleTemplateAssetCWProxy get copyWith =>
      _$CircleTemplateAssetCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CircleTemplateAsset _$CircleTemplateAssetFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CircleTemplateAsset',
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
            'note',
            'ordinal',
            'revision_id',
            'slug',
            'symbol',
            'weight_bps',
          ],
        );
        final val = CircleTemplateAsset(
          appearanceReason: $checkedConvert(
            'appearance_reason',
            (v) => v as String,
          ),
          assetType: $checkedConvert(
            'asset_type',
            (v) => $enumDecode(
              _$CircleTemplateAssetAssetTypeEnumEnumMap,
              v,
              unknownValue:
                  CircleTemplateAssetAssetTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          currency: $checkedConvert('currency', (v) => v as String),
          demo: $checkedConvert(
            'demo',
            (v) => ResearchDisclosure.fromJson(v as Map<String, dynamic>),
          ),
          id: $checkedConvert('id', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String),
          note: $checkedConvert('note', (v) => v as String?),
          ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
          revisionId: $checkedConvert('revision_id', (v) => v as String),
          slug: $checkedConvert('slug', (v) => v as String),
          symbol: $checkedConvert('symbol', (v) => v as String),
          weightBps: $checkedConvert('weight_bps', (v) => (v as num?)?.toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'appearanceReason': 'appearance_reason',
        'assetType': 'asset_type',
        'revisionId': 'revision_id',
        'weightBps': 'weight_bps',
      },
    );

Map<String, dynamic> _$CircleTemplateAssetToJson(
  CircleTemplateAsset instance,
) => <String, dynamic>{
  'appearance_reason': instance.appearanceReason,
  'asset_type': _$CircleTemplateAssetAssetTypeEnumEnumMap[instance.assetType]!,
  'currency': instance.currency,
  'demo': instance.demo.toJson(),
  'id': instance.id,
  'name': instance.name,
  'note': instance.note,
  'ordinal': instance.ordinal,
  'revision_id': instance.revisionId,
  'slug': instance.slug,
  'symbol': instance.symbol,
  'weight_bps': instance.weightBps,
};

const _$CircleTemplateAssetAssetTypeEnumEnumMap = {
  CircleTemplateAssetAssetTypeEnum.equity: 'equity',
  CircleTemplateAssetAssetTypeEnum.etf: 'etf',
  CircleTemplateAssetAssetTypeEnum.marketIndex: 'market_index',
  CircleTemplateAssetAssetTypeEnum.cash: 'cash',
  CircleTemplateAssetAssetTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
