// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_result.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SearchResultCWProxy {
  SearchResult asset(AssetSummary asset);

  SearchResult kind(SearchResultKindEnum kind);

  SearchResult coven(CovenSummary coven);

  SearchResult grimoire(GrimoireSummary grimoire);

  SearchResult circleTemplate(CircleTemplateSummary circleTemplate);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SearchResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SearchResult(...).copyWith(id: 12, name: "My name")
  /// ````
  SearchResult call({
    AssetSummary asset,
    SearchResultKindEnum kind,
    CovenSummary coven,
    GrimoireSummary grimoire,
    CircleTemplateSummary circleTemplate,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSearchResult.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSearchResult.copyWith.fieldName(...)`
class _$SearchResultCWProxyImpl implements _$SearchResultCWProxy {
  const _$SearchResultCWProxyImpl(this._value);

  final SearchResult _value;

  @override
  SearchResult asset(AssetSummary asset) => this(asset: asset);

  @override
  SearchResult kind(SearchResultKindEnum kind) => this(kind: kind);

  @override
  SearchResult coven(CovenSummary coven) => this(coven: coven);

  @override
  SearchResult grimoire(GrimoireSummary grimoire) => this(grimoire: grimoire);

  @override
  SearchResult circleTemplate(CircleTemplateSummary circleTemplate) =>
      this(circleTemplate: circleTemplate);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SearchResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SearchResult(...).copyWith(id: 12, name: "My name")
  /// ````
  SearchResult call({
    Object? asset = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
    Object? coven = const $CopyWithPlaceholder(),
    Object? grimoire = const $CopyWithPlaceholder(),
    Object? circleTemplate = const $CopyWithPlaceholder(),
  }) {
    return SearchResult(
      asset: asset == const $CopyWithPlaceholder()
          ? _value.asset
          // ignore: cast_nullable_to_non_nullable
          : asset as AssetSummary,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as SearchResultKindEnum,
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

extension $SearchResultCopyWith on SearchResult {
  /// Returns a callable class that can be used as follows: `instanceOfSearchResult.copyWith(...)` or like so:`instanceOfSearchResult.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SearchResultCWProxy get copyWith => _$SearchResultCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchResult _$SearchResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SearchResult', json, ($checkedConvert) {
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
      final val = SearchResult(
        asset: $checkedConvert(
          'asset',
          (v) => AssetSummary.fromJson(v as Map<String, dynamic>),
        ),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$SearchResultKindEnumEnumMap,
            v,
            unknownValue: SearchResultKindEnum.unknownDefaultOpenApi,
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

Map<String, dynamic> _$SearchResultToJson(SearchResult instance) =>
    <String, dynamic>{
      'asset': instance.asset.toJson(),
      'kind': _$SearchResultKindEnumEnumMap[instance.kind]!,
      'coven': instance.coven.toJson(),
      'grimoire': instance.grimoire.toJson(),
      'circle_template': instance.circleTemplate.toJson(),
    };

const _$SearchResultKindEnumEnumMap = {
  SearchResultKindEnum.circleTemplate: 'circle_template',
  SearchResultKindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
