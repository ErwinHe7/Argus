// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ritual_asset_idea.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RitualAssetIdeaCWProxy {
  RitualAssetIdea appearanceReason(String appearanceReason);

  RitualAssetIdea assetId(String assetId);

  RitualAssetIdea name(String name);

  RitualAssetIdea riskSummary(String riskSummary);

  RitualAssetIdea symbol(String symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RitualAssetIdea(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RitualAssetIdea(...).copyWith(id: 12, name: "My name")
  /// ````
  RitualAssetIdea call({
    String appearanceReason,
    String assetId,
    String name,
    String riskSummary,
    String symbol,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRitualAssetIdea.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRitualAssetIdea.copyWith.fieldName(...)`
class _$RitualAssetIdeaCWProxyImpl implements _$RitualAssetIdeaCWProxy {
  const _$RitualAssetIdeaCWProxyImpl(this._value);

  final RitualAssetIdea _value;

  @override
  RitualAssetIdea appearanceReason(String appearanceReason) =>
      this(appearanceReason: appearanceReason);

  @override
  RitualAssetIdea assetId(String assetId) => this(assetId: assetId);

  @override
  RitualAssetIdea name(String name) => this(name: name);

  @override
  RitualAssetIdea riskSummary(String riskSummary) =>
      this(riskSummary: riskSummary);

  @override
  RitualAssetIdea symbol(String symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RitualAssetIdea(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RitualAssetIdea(...).copyWith(id: 12, name: "My name")
  /// ````
  RitualAssetIdea call({
    Object? appearanceReason = const $CopyWithPlaceholder(),
    Object? assetId = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? riskSummary = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return RitualAssetIdea(
      appearanceReason: appearanceReason == const $CopyWithPlaceholder()
          ? _value.appearanceReason
          // ignore: cast_nullable_to_non_nullable
          : appearanceReason as String,
      assetId: assetId == const $CopyWithPlaceholder()
          ? _value.assetId
          // ignore: cast_nullable_to_non_nullable
          : assetId as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      riskSummary: riskSummary == const $CopyWithPlaceholder()
          ? _value.riskSummary
          // ignore: cast_nullable_to_non_nullable
          : riskSummary as String,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
    );
  }
}

extension $RitualAssetIdeaCopyWith on RitualAssetIdea {
  /// Returns a callable class that can be used as follows: `instanceOfRitualAssetIdea.copyWith(...)` or like so:`instanceOfRitualAssetIdea.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RitualAssetIdeaCWProxy get copyWith => _$RitualAssetIdeaCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RitualAssetIdea _$RitualAssetIdeaFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RitualAssetIdea',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'appearance_reason',
            'asset_id',
            'name',
            'risk_summary',
            'symbol',
          ],
        );
        final val = RitualAssetIdea(
          appearanceReason: $checkedConvert(
            'appearance_reason',
            (v) => v as String,
          ),
          assetId: $checkedConvert('asset_id', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String),
          riskSummary: $checkedConvert('risk_summary', (v) => v as String),
          symbol: $checkedConvert('symbol', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'appearanceReason': 'appearance_reason',
        'assetId': 'asset_id',
        'riskSummary': 'risk_summary',
      },
    );

Map<String, dynamic> _$RitualAssetIdeaToJson(RitualAssetIdea instance) =>
    <String, dynamic>{
      'appearance_reason': instance.appearanceReason,
      'asset_id': instance.assetId,
      'name': instance.name,
      'risk_summary': instance.riskSummary,
      'symbol': instance.symbol,
    };
