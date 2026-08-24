// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_item_one_of2.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiscoverItemOneOf2CWProxy {
  DiscoverItemOneOf2 grimoire(GrimoireSummary grimoire);

  DiscoverItemOneOf2 kind(DiscoverItemOneOf2KindEnum kind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItemOneOf2(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItemOneOf2(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItemOneOf2 call({
    GrimoireSummary grimoire,
    DiscoverItemOneOf2KindEnum kind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDiscoverItemOneOf2.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDiscoverItemOneOf2.copyWith.fieldName(...)`
class _$DiscoverItemOneOf2CWProxyImpl implements _$DiscoverItemOneOf2CWProxy {
  const _$DiscoverItemOneOf2CWProxyImpl(this._value);

  final DiscoverItemOneOf2 _value;

  @override
  DiscoverItemOneOf2 grimoire(GrimoireSummary grimoire) =>
      this(grimoire: grimoire);

  @override
  DiscoverItemOneOf2 kind(DiscoverItemOneOf2KindEnum kind) => this(kind: kind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItemOneOf2(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItemOneOf2(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItemOneOf2 call({
    Object? grimoire = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
  }) {
    return DiscoverItemOneOf2(
      grimoire: grimoire == const $CopyWithPlaceholder()
          ? _value.grimoire
          // ignore: cast_nullable_to_non_nullable
          : grimoire as GrimoireSummary,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as DiscoverItemOneOf2KindEnum,
    );
  }
}

extension $DiscoverItemOneOf2CopyWith on DiscoverItemOneOf2 {
  /// Returns a callable class that can be used as follows: `instanceOfDiscoverItemOneOf2.copyWith(...)` or like so:`instanceOfDiscoverItemOneOf2.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiscoverItemOneOf2CWProxy get copyWith =>
      _$DiscoverItemOneOf2CWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiscoverItemOneOf2 _$DiscoverItemOneOf2FromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiscoverItemOneOf2', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['grimoire', 'kind']);
      final val = DiscoverItemOneOf2(
        grimoire: $checkedConvert(
          'grimoire',
          (v) => GrimoireSummary.fromJson(v as Map<String, dynamic>),
        ),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$DiscoverItemOneOf2KindEnumEnumMap,
            v,
            unknownValue: DiscoverItemOneOf2KindEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DiscoverItemOneOf2ToJson(DiscoverItemOneOf2 instance) =>
    <String, dynamic>{
      'grimoire': instance.grimoire.toJson(),
      'kind': _$DiscoverItemOneOf2KindEnumEnumMap[instance.kind]!,
    };

const _$DiscoverItemOneOf2KindEnumEnumMap = {
  DiscoverItemOneOf2KindEnum.grimoire: 'grimoire',
  DiscoverItemOneOf2KindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
