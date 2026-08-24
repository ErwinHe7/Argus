// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_item_one_of.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiscoverItemOneOfCWProxy {
  DiscoverItemOneOf asset(AssetSummary asset);

  DiscoverItemOneOf kind(DiscoverItemOneOfKindEnum kind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItemOneOf(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItemOneOf(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItemOneOf call({AssetSummary asset, DiscoverItemOneOfKindEnum kind});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDiscoverItemOneOf.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDiscoverItemOneOf.copyWith.fieldName(...)`
class _$DiscoverItemOneOfCWProxyImpl implements _$DiscoverItemOneOfCWProxy {
  const _$DiscoverItemOneOfCWProxyImpl(this._value);

  final DiscoverItemOneOf _value;

  @override
  DiscoverItemOneOf asset(AssetSummary asset) => this(asset: asset);

  @override
  DiscoverItemOneOf kind(DiscoverItemOneOfKindEnum kind) => this(kind: kind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItemOneOf(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItemOneOf(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItemOneOf call({
    Object? asset = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
  }) {
    return DiscoverItemOneOf(
      asset: asset == const $CopyWithPlaceholder()
          ? _value.asset
          // ignore: cast_nullable_to_non_nullable
          : asset as AssetSummary,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as DiscoverItemOneOfKindEnum,
    );
  }
}

extension $DiscoverItemOneOfCopyWith on DiscoverItemOneOf {
  /// Returns a callable class that can be used as follows: `instanceOfDiscoverItemOneOf.copyWith(...)` or like so:`instanceOfDiscoverItemOneOf.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiscoverItemOneOfCWProxy get copyWith =>
      _$DiscoverItemOneOfCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiscoverItemOneOf _$DiscoverItemOneOfFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiscoverItemOneOf', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['asset', 'kind']);
      final val = DiscoverItemOneOf(
        asset: $checkedConvert(
          'asset',
          (v) => AssetSummary.fromJson(v as Map<String, dynamic>),
        ),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$DiscoverItemOneOfKindEnumEnumMap,
            v,
            unknownValue: DiscoverItemOneOfKindEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DiscoverItemOneOfToJson(DiscoverItemOneOf instance) =>
    <String, dynamic>{
      'asset': instance.asset.toJson(),
      'kind': _$DiscoverItemOneOfKindEnumEnumMap[instance.kind]!,
    };

const _$DiscoverItemOneOfKindEnumEnumMap = {
  DiscoverItemOneOfKindEnum.asset: 'asset',
  DiscoverItemOneOfKindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
