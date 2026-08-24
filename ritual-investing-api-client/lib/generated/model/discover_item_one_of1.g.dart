// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_item_one_of1.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiscoverItemOneOf1CWProxy {
  DiscoverItemOneOf1 coven(CovenSummary coven);

  DiscoverItemOneOf1 kind(DiscoverItemOneOf1KindEnum kind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItemOneOf1(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItemOneOf1(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItemOneOf1 call({
    CovenSummary coven,
    DiscoverItemOneOf1KindEnum kind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDiscoverItemOneOf1.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDiscoverItemOneOf1.copyWith.fieldName(...)`
class _$DiscoverItemOneOf1CWProxyImpl implements _$DiscoverItemOneOf1CWProxy {
  const _$DiscoverItemOneOf1CWProxyImpl(this._value);

  final DiscoverItemOneOf1 _value;

  @override
  DiscoverItemOneOf1 coven(CovenSummary coven) => this(coven: coven);

  @override
  DiscoverItemOneOf1 kind(DiscoverItemOneOf1KindEnum kind) => this(kind: kind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItemOneOf1(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItemOneOf1(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItemOneOf1 call({
    Object? coven = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
  }) {
    return DiscoverItemOneOf1(
      coven: coven == const $CopyWithPlaceholder()
          ? _value.coven
          // ignore: cast_nullable_to_non_nullable
          : coven as CovenSummary,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as DiscoverItemOneOf1KindEnum,
    );
  }
}

extension $DiscoverItemOneOf1CopyWith on DiscoverItemOneOf1 {
  /// Returns a callable class that can be used as follows: `instanceOfDiscoverItemOneOf1.copyWith(...)` or like so:`instanceOfDiscoverItemOneOf1.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiscoverItemOneOf1CWProxy get copyWith =>
      _$DiscoverItemOneOf1CWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiscoverItemOneOf1 _$DiscoverItemOneOf1FromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiscoverItemOneOf1', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['coven', 'kind']);
      final val = DiscoverItemOneOf1(
        coven: $checkedConvert(
          'coven',
          (v) => CovenSummary.fromJson(v as Map<String, dynamic>),
        ),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$DiscoverItemOneOf1KindEnumEnumMap,
            v,
            unknownValue: DiscoverItemOneOf1KindEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$DiscoverItemOneOf1ToJson(DiscoverItemOneOf1 instance) =>
    <String, dynamic>{
      'coven': instance.coven.toJson(),
      'kind': _$DiscoverItemOneOf1KindEnumEnumMap[instance.kind]!,
    };

const _$DiscoverItemOneOf1KindEnumEnumMap = {
  DiscoverItemOneOf1KindEnum.coven: 'coven',
  DiscoverItemOneOf1KindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
