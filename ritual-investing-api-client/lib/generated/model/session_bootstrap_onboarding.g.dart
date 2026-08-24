// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_onboarding.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapOnboardingCWProxy {
  SessionBootstrapOnboarding completedSteps(List<String> completedSteps);

  SessionBootstrapOnboarding currentStep(String currentStep);

  SessionBootstrapOnboarding version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapOnboarding(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapOnboarding(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapOnboarding call({
    List<String> completedSteps,
    String currentStep,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapOnboarding.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapOnboarding.copyWith.fieldName(...)`
class _$SessionBootstrapOnboardingCWProxyImpl
    implements _$SessionBootstrapOnboardingCWProxy {
  const _$SessionBootstrapOnboardingCWProxyImpl(this._value);

  final SessionBootstrapOnboarding _value;

  @override
  SessionBootstrapOnboarding completedSteps(List<String> completedSteps) =>
      this(completedSteps: completedSteps);

  @override
  SessionBootstrapOnboarding currentStep(String currentStep) =>
      this(currentStep: currentStep);

  @override
  SessionBootstrapOnboarding version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapOnboarding(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapOnboarding(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapOnboarding call({
    Object? completedSteps = const $CopyWithPlaceholder(),
    Object? currentStep = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapOnboarding(
      completedSteps: completedSteps == const $CopyWithPlaceholder()
          ? _value.completedSteps
          // ignore: cast_nullable_to_non_nullable
          : completedSteps as List<String>,
      currentStep: currentStep == const $CopyWithPlaceholder()
          ? _value.currentStep
          // ignore: cast_nullable_to_non_nullable
          : currentStep as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $SessionBootstrapOnboardingCopyWith on SessionBootstrapOnboarding {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrapOnboarding.copyWith(...)` or like so:`instanceOfSessionBootstrapOnboarding.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapOnboardingCWProxy get copyWith =>
      _$SessionBootstrapOnboardingCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrapOnboarding _$SessionBootstrapOnboardingFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'SessionBootstrapOnboarding',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['completed_steps', 'current_step', 'version'],
    );
    final val = SessionBootstrapOnboarding(
      completedSteps: $checkedConvert(
        'completed_steps',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      currentStep: $checkedConvert('current_step', (v) => v as String),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'completedSteps': 'completed_steps',
    'currentStep': 'current_step',
  },
);

Map<String, dynamic> _$SessionBootstrapOnboardingToJson(
  SessionBootstrapOnboarding instance,
) => <String, dynamic>{
  'completed_steps': instance.completedSteps,
  'current_step': instance.currentStep,
  'version': instance.version,
};
