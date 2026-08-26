// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_asset_teaser.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PublicAssetTeaserCWProxy {
  PublicAssetTeaser appearanceReason(String appearanceReason);

  PublicAssetTeaser name(String name);

  PublicAssetTeaser symbol(String symbol);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicAssetTeaser(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicAssetTeaser(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicAssetTeaser call({String appearanceReason, String name, String symbol});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPublicAssetTeaser.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPublicAssetTeaser.copyWith.fieldName(...)`
class _$PublicAssetTeaserCWProxyImpl implements _$PublicAssetTeaserCWProxy {
  const _$PublicAssetTeaserCWProxyImpl(this._value);

  final PublicAssetTeaser _value;

  @override
  PublicAssetTeaser appearanceReason(String appearanceReason) =>
      this(appearanceReason: appearanceReason);

  @override
  PublicAssetTeaser name(String name) => this(name: name);

  @override
  PublicAssetTeaser symbol(String symbol) => this(symbol: symbol);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PublicAssetTeaser(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PublicAssetTeaser(...).copyWith(id: 12, name: "My name")
  /// ````
  PublicAssetTeaser call({
    Object? appearanceReason = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? symbol = const $CopyWithPlaceholder(),
  }) {
    return PublicAssetTeaser(
      appearanceReason: appearanceReason == const $CopyWithPlaceholder()
          ? _value.appearanceReason
          // ignore: cast_nullable_to_non_nullable
          : appearanceReason as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      symbol: symbol == const $CopyWithPlaceholder()
          ? _value.symbol
          // ignore: cast_nullable_to_non_nullable
          : symbol as String,
    );
  }
}

extension $PublicAssetTeaserCopyWith on PublicAssetTeaser {
  /// Returns a callable class that can be used as follows: `instanceOfPublicAssetTeaser.copyWith(...)` or like so:`instanceOfPublicAssetTeaser.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PublicAssetTeaserCWProxy get copyWith =>
      _$PublicAssetTeaserCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicAssetTeaser _$PublicAssetTeaserFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PublicAssetTeaser', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['appearance_reason', 'name', 'symbol']);
  final val = PublicAssetTeaser(
    appearanceReason: $checkedConvert('appearance_reason', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    symbol: $checkedConvert('symbol', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'appearanceReason': 'appearance_reason'});

Map<String, dynamic> _$PublicAssetTeaserToJson(PublicAssetTeaser instance) =>
    <String, dynamic>{
      'appearance_reason': instance.appearanceReason,
      'name': instance.name,
      'symbol': instance.symbol,
    };
