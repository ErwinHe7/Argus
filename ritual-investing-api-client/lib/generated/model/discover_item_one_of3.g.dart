// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discover_item_one_of3.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DiscoverItemOneOf3CWProxy {
  DiscoverItemOneOf3 circleTemplate(CircleTemplateSummary circleTemplate);

  DiscoverItemOneOf3 kind(DiscoverItemOneOf3KindEnum kind);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItemOneOf3(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItemOneOf3(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItemOneOf3 call({
    CircleTemplateSummary circleTemplate,
    DiscoverItemOneOf3KindEnum kind,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDiscoverItemOneOf3.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDiscoverItemOneOf3.copyWith.fieldName(...)`
class _$DiscoverItemOneOf3CWProxyImpl implements _$DiscoverItemOneOf3CWProxy {
  const _$DiscoverItemOneOf3CWProxyImpl(this._value);

  final DiscoverItemOneOf3 _value;

  @override
  DiscoverItemOneOf3 circleTemplate(CircleTemplateSummary circleTemplate) =>
      this(circleTemplate: circleTemplate);

  @override
  DiscoverItemOneOf3 kind(DiscoverItemOneOf3KindEnum kind) => this(kind: kind);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DiscoverItemOneOf3(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DiscoverItemOneOf3(...).copyWith(id: 12, name: "My name")
  /// ````
  DiscoverItemOneOf3 call({
    Object? circleTemplate = const $CopyWithPlaceholder(),
    Object? kind = const $CopyWithPlaceholder(),
  }) {
    return DiscoverItemOneOf3(
      circleTemplate: circleTemplate == const $CopyWithPlaceholder()
          ? _value.circleTemplate
          // ignore: cast_nullable_to_non_nullable
          : circleTemplate as CircleTemplateSummary,
      kind: kind == const $CopyWithPlaceholder()
          ? _value.kind
          // ignore: cast_nullable_to_non_nullable
          : kind as DiscoverItemOneOf3KindEnum,
    );
  }
}

extension $DiscoverItemOneOf3CopyWith on DiscoverItemOneOf3 {
  /// Returns a callable class that can be used as follows: `instanceOfDiscoverItemOneOf3.copyWith(...)` or like so:`instanceOfDiscoverItemOneOf3.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DiscoverItemOneOf3CWProxy get copyWith =>
      _$DiscoverItemOneOf3CWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DiscoverItemOneOf3 _$DiscoverItemOneOf3FromJson(Map<String, dynamic> json) =>
    $checkedCreate('DiscoverItemOneOf3', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['circle_template', 'kind']);
      final val = DiscoverItemOneOf3(
        circleTemplate: $checkedConvert(
          'circle_template',
          (v) => CircleTemplateSummary.fromJson(v as Map<String, dynamic>),
        ),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(
            _$DiscoverItemOneOf3KindEnumEnumMap,
            v,
            unknownValue: DiscoverItemOneOf3KindEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    }, fieldKeyMap: const {'circleTemplate': 'circle_template'});

Map<String, dynamic> _$DiscoverItemOneOf3ToJson(DiscoverItemOneOf3 instance) =>
    <String, dynamic>{
      'circle_template': instance.circleTemplate.toJson(),
      'kind': _$DiscoverItemOneOf3KindEnumEnumMap[instance.kind]!,
    };

const _$DiscoverItemOneOf3KindEnumEnumMap = {
  DiscoverItemOneOf3KindEnum.circleTemplate: 'circle_template',
  DiscoverItemOneOf3KindEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
