// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_item.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiscoverItemCWProxy {
  DiscoverItem asset(AssetSummary? asset);

  DiscoverItem circleTemplate(CircleTemplateSummary? circleTemplate);

  DiscoverItem coven(CovenSummary? coven);

  DiscoverItem grimoire(GrimoireSummary? grimoire);

  DiscoverItem kind(DiscoverItemKindEnum kind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItem(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItem call({
    AssetSummary? asset,
    CircleTemplateSummary? circleTemplate,
    CovenSummary? coven,
    GrimoireSummary? grimoire,
    DiscoverItemKindEnum kind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDiscoverItem.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDiscoverItem.copyWith.fieldName(...)`
class _$DiscoverItemCWProxyImpl implements _$DiscoverItemCWProxy {
  const _$DiscoverItemCWProxyImpl(this._value);

  final DiscoverItem _value;

  @override
  DiscoverItem asset(AssetSummary? asset) => this(asset: asset);

  @override
  DiscoverItem circleTemplate(CircleTemplateSummary? circleTemplate) =>
      this(circleTemplate: circleTemplate);

  @override
  DiscoverItem coven(CovenSummary? coven) => this(coven: coven);

  @override
  DiscoverItem grimoire(GrimoireSummary? grimoire) => this(grimoire: grimoire);

  @override
  DiscoverItem kind(DiscoverItemKindEnum kind) => this(kind: kind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItem(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItem call({
    Object? asset = const $CopyWithPlaceholder(),
    Object? circleTemplate = const $CopyWithPlaceholder(),
    Object? coven = const $CopyWithPlaceholder(),
    Object? grimoire = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
  }) {
    return DiscoverItem(
      asset: asset == const $CopyWithPlaceholder()
          ? _value.asset
          // ignore: cast_nullable_to_non_nullable
          : asset as AssetSummary?,
      circleTemplate: circleTemplate == const $CopyWithPlaceholder()
          ? _value.circleTemplate
          // ignore: cast_nullable_to_non_nullable
          : circleTemplate as CircleTemplateSummary?,
      coven: coven == const $CopyWithPlaceholder()
          ? _value.coven
          // ignore: cast_nullable_to_non_nullable
          : coven as CovenSummary?,
      grimoire: grimoire == const $CopyWithPlaceholder()
          ? _value.grimoire
          // ignore: cast_nullable_to_non_nullable
          : grimoire as GrimoireSummary?,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as DiscoverItemKindEnum,
    );
  }
}

extension $DiscoverItemCopyWith on DiscoverItem {
  /// Returns a callable class that can be used as follows: `instanceOfDiscoverItem.copyWith(...)` or like so:`instanceOfDiscoverItem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiscoverItemCWProxy get copyWith => _$DiscoverItemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiscoverItem _$DiscoverItemFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DiscoverItem', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['kind']);
  final val = DiscoverItem(
    asset: $checkedConvert(
      'asset',
      (v) =>
          v == null ? null : AssetSummary.fromJson(v as Map<String, dynamic>),
    ),
    circleTemplate: $checkedConvert(
      'circle_template',
      (v) => v == null
          ? null
          : CircleTemplateSummary.fromJson(v as Map<String, dynamic>),
    ),
    coven: $checkedConvert(
      'coven',
      (v) =>
          v == null ? null : CovenSummary.fromJson(v as Map<String, dynamic>),
    ),
    grimoire: $checkedConvert(
      'grimoire',
      (v) => v == null
          ? null
          : GrimoireSummary.fromJson(v as Map<String, dynamic>),
    ),
    kind: $checkedConvert(
      'kind',
      (v) => $enumDecode(
        _$DiscoverItemKindEnumEnumMap,
        v,
        unknownValue: DiscoverItemKindEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
}, fieldKeyMap: const {'circleTemplate': 'circle_template'});

Map<String, dynamic> _$DiscoverItemToJson(DiscoverItem instance) =>
    <String, dynamic>{
      'asset': ?instance.asset?.toJson(),
      'circle_template': ?instance.circleTemplate?.toJson(),
      'coven': ?instance.coven?.toJson(),
      'grimoire': ?instance.grimoire?.toJson(),
      'kind': _$DiscoverItemKindEnumEnumMap[instance.kind]!,
    };

const _$DiscoverItemKindEnumEnumMap = {
  DiscoverItemKindEnum.asset: 'asset',
  DiscoverItemKindEnum.coven: 'coven',
  DiscoverItemKindEnum.grimoire: 'grimoire',
  DiscoverItemKindEnum.circleTemplate: 'circle_template',
  DiscoverItemKindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
