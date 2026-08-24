// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_item.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiscoverItemCWProxy {
  DiscoverItem asset(AssetSummary asset);

  DiscoverItem kind(DiscoverItemKindEnum kind);

  DiscoverItem coven(CovenSummary coven);

  DiscoverItem grimoire(GrimoireSummary grimoire);

  DiscoverItem circleTemplate(CircleTemplateSummary circleTemplate);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItem(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItem call({
    AssetSummary asset,
    DiscoverItemKindEnum kind,
    CovenSummary coven,
    GrimoireSummary grimoire,
    CircleTemplateSummary circleTemplate,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDiscoverItem.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDiscoverItem.copyWith.fieldName(...)`
class _$DiscoverItemCWProxyImpl implements _$DiscoverItemCWProxy {
  const _$DiscoverItemCWProxyImpl(this._value);

  final DiscoverItem _value;

  @override
  DiscoverItem asset(AssetSummary asset) => this(asset: asset);

  @override
  DiscoverItem kind(DiscoverItemKindEnum kind) => this(kind: kind);

  @override
  DiscoverItem coven(CovenSummary coven) => this(coven: coven);

  @override
  DiscoverItem grimoire(GrimoireSummary grimoire) => this(grimoire: grimoire);

  @override
  DiscoverItem circleTemplate(CircleTemplateSummary circleTemplate) =>
      this(circleTemplate: circleTemplate);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItem(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItem call({
    Object? asset = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? coven = const $CopyWithPlaceholder(),
    Object? grimoire = const $CopyWithPlaceholder(),
    Object? circleTemplate = const $CopyWithPlaceholder(),
  }) {
    return DiscoverItem(
      asset: asset == const $CopyWithPlaceholder()
          ? _value.asset
          // ignore: cast_nullable_to_non_nullable
          : asset as AssetSummary,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as DiscoverItemKindEnum,
      coven: coven == const $CopyWithPlaceholder()
          ? _value.coven
          // ignore: cast_nullable_to_non_nullable
          : coven as CovenSummary,
      grimoire: grimoire == const $CopyWithPlaceholder()
          ? _value.grimoire
          // ignore: cast_nullable_to_non_nullable
          : grimoire as GrimoireSummary,
      circleTemplate: circleTemplate == const $CopyWithPlaceholder()
          ? _value.circleTemplate
          // ignore: cast_nullable_to_non_nullable
          : circleTemplate as CircleTemplateSummary,
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

DiscoverItem _$DiscoverItemFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiscoverItem', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'asset',
          'kind',
          'coven',
          'grimoire',
          'circle_template',
        ],
      );
      final val = DiscoverItem(
        asset: $checkedConvert(
          'asset',
          (v) => AssetSummary.fromJson(v as Map<String, dynamic>),
        ),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$DiscoverItemKindEnumEnumMap,
            v,
            unknownValue: DiscoverItemKindEnum.unknownDefaultOpenApi,
          ),
        ),
        coven: $checkedConvert(
          'coven',
          (v) => CovenSummary.fromJson(v as Map<String, dynamic>),
        ),
        grimoire: $checkedConvert(
          'grimoire',
          (v) => GrimoireSummary.fromJson(v as Map<String, dynamic>),
        ),
        circleTemplate: $checkedConvert(
          'circle_template',
          (v) => CircleTemplateSummary.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    }, fieldKeyMap: const {'circleTemplate': 'circle_template'});

Map<String, dynamic> _$DiscoverItemToJson(DiscoverItem instance) =>
    <String, dynamic>{
      'asset': instance.asset.toJson(),
      'kind': _$DiscoverItemKindEnumEnumMap[instance.kind]!,
      'coven': instance.coven.toJson(),
      'grimoire': instance.grimoire.toJson(),
      'circle_template': instance.circleTemplate.toJson(),
    };

const _$DiscoverItemKindEnumEnumMap = {
  DiscoverItemKindEnum.circleTemplate: 'circle_template',
  DiscoverItemKindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
