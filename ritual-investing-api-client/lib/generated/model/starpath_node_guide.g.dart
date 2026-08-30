// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'starpath_node_guide.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StarpathNodeGuideCWProxy {
  StarpathNodeGuide accessibleLabel(String accessibleLabel);

  StarpathNodeGuide tarotKey(String tarotKey);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathNodeGuide(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathNodeGuide(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathNodeGuide call({String accessibleLabel, String tarotKey});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStarpathNodeGuide.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStarpathNodeGuide.copyWith.fieldName(...)`
class _$StarpathNodeGuideCWProxyImpl implements _$StarpathNodeGuideCWProxy {
  const _$StarpathNodeGuideCWProxyImpl(this._value);

  final StarpathNodeGuide _value;

  @override
  StarpathNodeGuide accessibleLabel(String accessibleLabel) =>
      this(accessibleLabel: accessibleLabel);

  @override
  StarpathNodeGuide tarotKey(String tarotKey) => this(tarotKey: tarotKey);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StarpathNodeGuide(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StarpathNodeGuide(...).copyWith(id: 12, name: "My name")
  /// ````
  StarpathNodeGuide call({
    Object? accessibleLabel = const $CopyWithPlaceholder(),
    Object? tarotKey = const $CopyWithPlaceholder(),
  }) {
    return StarpathNodeGuide(
      accessibleLabel: accessibleLabel == const $CopyWithPlaceholder()
          ? _value.accessibleLabel
          // ignore: cast_nullable_to_non_nullable
          : accessibleLabel as String,
      tarotKey: tarotKey == const $CopyWithPlaceholder()
          ? _value.tarotKey
          // ignore: cast_nullable_to_non_nullable
          : tarotKey as String,
    );
  }
}

extension $StarpathNodeGuideCopyWith on StarpathNodeGuide {
  /// Returns a callable class that can be used as follows: `instanceOfStarpathNodeGuide.copyWith(...)` or like so:`instanceOfStarpathNodeGuide.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StarpathNodeGuideCWProxy get copyWith =>
      _$StarpathNodeGuideCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StarpathNodeGuide _$StarpathNodeGuideFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'StarpathNodeGuide',
      json,
      ($checkedConvert) {
        $checkKeys(json, requiredKeys: const ['accessible_label', 'tarot_key']);
        final val = StarpathNodeGuide(
          accessibleLabel: $checkedConvert(
            'accessible_label',
            (v) => v as String,
          ),
          tarotKey: $checkedConvert('tarot_key', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'accessibleLabel': 'accessible_label',
        'tarotKey': 'tarot_key',
      },
    );

Map<String, dynamic> _$StarpathNodeGuideToJson(StarpathNodeGuide instance) =>
    <String, dynamic>{
      'accessible_label': instance.accessibleLabel,
      'tarot_key': instance.tarotKey,
    };
