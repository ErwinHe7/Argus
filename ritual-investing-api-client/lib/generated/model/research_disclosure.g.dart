// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'research_disclosure.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ResearchDisclosureCWProxy {
  ResearchDisclosure isDemo(bool isDemo);

  ResearchDisclosure limitations(List<String> limitations);

  ResearchDisclosure observedAt(DateTime observedAt);

  ResearchDisclosure sourceLabel(String sourceLabel);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ResearchDisclosure(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ResearchDisclosure(...).copyWith(id: 12, name: "My name")
  /// ````
  ResearchDisclosure call({
    bool isDemo,
    List<String> limitations,
    DateTime observedAt,
    String sourceLabel,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfResearchDisclosure.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfResearchDisclosure.copyWith.fieldName(...)`
class _$ResearchDisclosureCWProxyImpl implements _$ResearchDisclosureCWProxy {
  const _$ResearchDisclosureCWProxyImpl(this._value);

  final ResearchDisclosure _value;

  @override
  ResearchDisclosure isDemo(bool isDemo) => this(isDemo: isDemo);

  @override
  ResearchDisclosure limitations(List<String> limitations) =>
      this(limitations: limitations);

  @override
  ResearchDisclosure observedAt(DateTime observedAt) =>
      this(observedAt: observedAt);

  @override
  ResearchDisclosure sourceLabel(String sourceLabel) =>
      this(sourceLabel: sourceLabel);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ResearchDisclosure(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ResearchDisclosure(...).copyWith(id: 12, name: "My name")
  /// ````
  ResearchDisclosure call({
    Object? isDemo = const $CopyWithPlaceholder(),
    Object? limitations = const $CopyWithPlaceholder(),
    Object? observedAt = const $CopyWithPlaceholder(),
    Object? sourceLabel = const $CopyWithPlaceholder(),
  }) {
    return ResearchDisclosure(
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

extension $ResearchDisclosureCopyWith on ResearchDisclosure {
  /// Returns a callable class that can be used as follows: `instanceOfResearchDisclosure.copyWith(...)` or like so:`instanceOfResearchDisclosure.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ResearchDisclosureCWProxy get copyWith =>
      _$ResearchDisclosureCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResearchDisclosure _$ResearchDisclosureFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ResearchDisclosure',
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
        final val = ResearchDisclosure(
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

Map<String, dynamic> _$ResearchDisclosureToJson(ResearchDisclosure instance) =>
    <String, dynamic>{
      'is_demo': instance.isDemo,
      'limitations': instance.limitations,
      'observed_at': instance.observedAt.toIso8601String(),
      'source_label': instance.sourceLabel,
    };
