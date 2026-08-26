// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simulation_demo_disclosure.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SimulationDemoDisclosureCWProxy {
  SimulationDemoDisclosure isDemo(bool isDemo);

  SimulationDemoDisclosure limitations(List<String> limitations);

  SimulationDemoDisclosure observedAt(DateTime observedAt);

  SimulationDemoDisclosure sourceLabel(String sourceLabel);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulationDemoDisclosure(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulationDemoDisclosure(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulationDemoDisclosure call({
    bool isDemo,
    List<String> limitations,
    DateTime observedAt,
    String sourceLabel,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSimulationDemoDisclosure.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSimulationDemoDisclosure.copyWith.fieldName(...)`
class _$SimulationDemoDisclosureCWProxyImpl
    implements _$SimulationDemoDisclosureCWProxy {
  const _$SimulationDemoDisclosureCWProxyImpl(this._value);

  final SimulationDemoDisclosure _value;

  @override
  SimulationDemoDisclosure isDemo(bool isDemo) => this(isDemo: isDemo);

  @override
  SimulationDemoDisclosure limitations(List<String> limitations) =>
      this(limitations: limitations);

  @override
  SimulationDemoDisclosure observedAt(DateTime observedAt) =>
      this(observedAt: observedAt);

  @override
  SimulationDemoDisclosure sourceLabel(String sourceLabel) =>
      this(sourceLabel: sourceLabel);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SimulationDemoDisclosure(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SimulationDemoDisclosure(...).copyWith(id: 12, name: "My name")
  /// ````
  SimulationDemoDisclosure call({
    Object? isDemo = const $CopyWithPlaceholder(),
    Object? limitations = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? sourceLabel = const $CopyWithPlaceholder(),
  }) {
    return SimulationDemoDisclosure(
      isDemo: isDemo == const $CopyWithPlaceholder()
          ? _value.isDemo
          // ignore: cast_nullable_to_non_nullable
          : isDemo as bool,
      limitations: limitations == const $CopyWithPlaceholder()
          ? _value.limitations
          // ignore: cast_nullable_to_non_nullable
          : limitations as List<String>,
      observedAt: observedAt == const $CopyWithPlaceholder()
          ? _value.observedAt
          // ignore: cast_nullable_to_non_nullable
          : observedAt as DateTime,
      sourceLabel: sourceLabel == const $CopyWithPlaceholder()
          ? _value.sourceLabel
          // ignore: cast_nullable_to_non_nullable
          : sourceLabel as String,
    );
  }
}

extension $SimulationDemoDisclosureCopyWith on SimulationDemoDisclosure {
  /// Returns a callable class that can be used as follows: `instanceOfSimulationDemoDisclosure.copyWith(...)` or like so:`instanceOfSimulationDemoDisclosure.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SimulationDemoDisclosureCWProxy get copyWith =>
      _$SimulationDemoDisclosureCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimulationDemoDisclosure _$SimulationDemoDisclosureFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'SimulationDemoDisclosure',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'is_demo',
        'limitations',
        'observed_at',
        'source_label',
      ],
    );
    final val = SimulationDemoDisclosure(
      isDemo: $checkedConvert('is_demo', (v) => v as bool),
      limitations: $checkedConvert(
        'limitations',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      observedAt: $checkedConvert(
        'observed_at',
        (v) => DateTime.parse(v as String),
      ),
      sourceLabel: $checkedConvert('source_label', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'isDemo': 'is_demo',
    'observedAt': 'observed_at',
    'sourceLabel': 'source_label',
  },
);

Map<String, dynamic> _$SimulationDemoDisclosureToJson(
  SimulationDemoDisclosure instance,
) => <String, dynamic>{
  'is_demo': instance.isDemo,
  'limitations': instance.limitations,
  'observed_at': instance.observedAt.toIso8601String(),
  'source_label': instance.sourceLabel,
};
