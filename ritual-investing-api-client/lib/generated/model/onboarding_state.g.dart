// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_state.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OnboardingStateCWProxy {
  OnboardingState cohort(OnboardingStateCohortEnum cohort);

  OnboardingState completedAt(DateTime? completedAt);

  OnboardingState completedSteps(List<String> completedSteps);

  OnboardingState currentStep(OnboardingStateCurrentStepEnum currentStep);

  OnboardingState schemaVersion(int schemaVersion);

  OnboardingState version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OnboardingState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OnboardingState(...).copyWith(id: 12, name: "My name")
  /// ````
  OnboardingState call({
    OnboardingStateCohortEnum cohort,
    DateTime? completedAt,
    List<String> completedSteps,
    OnboardingStateCurrentStepEnum currentStep,
    int schemaVersion,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOnboardingState.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOnboardingState.copyWith.fieldName(...)`
class _$OnboardingStateCWProxyImpl implements _$OnboardingStateCWProxy {
  const _$OnboardingStateCWProxyImpl(this._value);

  final OnboardingState _value;

  @override
  OnboardingState cohort(OnboardingStateCohortEnum cohort) =>
      this(cohort: cohort);

  @override
  OnboardingState completedAt(DateTime? completedAt) =>
      this(completedAt: completedAt);

  @override
  OnboardingState completedSteps(List<String> completedSteps) =>
      this(completedSteps: completedSteps);

  @override
  OnboardingState currentStep(OnboardingStateCurrentStepEnum currentStep) =>
      this(currentStep: currentStep);

  @override
  OnboardingState schemaVersion(int schemaVersion) =>
      this(schemaVersion: schemaVersion);

  @override
  OnboardingState version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OnboardingState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OnboardingState(...).copyWith(id: 12, name: "My name")
  /// ````
  OnboardingState call({
    Object? cohort = const $CopyWithPlaceholder(),
    Object? completedAt = const $CopyWithPlaceholder(),
    Object? completedSteps = const $CopyWithPlaceholder(),
    Object? currentStep = const $CopyWithPlaceholder(),
    Object? schemaVersion = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return OnboardingState(
      cohort: cohort == const $CopyWithPlaceholder()
          ? _value.cohort
          // ignore: cast_nullable_to_non_nullable
          : cohort as OnboardingStateCohortEnum,
      completedAt: completedAt == const $CopyWithPlaceholder()
          ? _value.completedAt
          // ignore: cast_nullable_to_non_nullable
          : completedAt as DateTime?,
      completedSteps: completedSteps == const $CopyWithPlaceholder()
          ? _value.completedSteps
          // ignore: cast_nullable_to_non_nullable
          : completedSteps as List<String>,
      currentStep: currentStep == const $CopyWithPlaceholder()
          ? _value.currentStep
          // ignore: cast_nullable_to_non_nullable
          : currentStep as OnboardingStateCurrentStepEnum,
      schemaVersion: schemaVersion == const $CopyWithPlaceholder()
          ? _value.schemaVersion
          // ignore: cast_nullable_to_non_nullable
          : schemaVersion as int,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $OnboardingStateCopyWith on OnboardingState {
  /// Returns a callable class that can be used as follows: `instanceOfOnboardingState.copyWith(...)` or like so:`instanceOfOnboardingState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OnboardingStateCWProxy get copyWith => _$OnboardingStateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OnboardingState _$OnboardingStateFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OnboardingState',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'cohort',
            'completed_at',
            'completed_steps',
            'current_step',
            'schema_version',
            'version',
          ],
        );
        final val = OnboardingState(
          cohort: $checkedConvert(
            'cohort',
            (v) => $enumDecode(
              _$OnboardingStateCohortEnumEnumMap,
              v,
              unknownValue: OnboardingStateCohortEnum.unknownDefaultOpenApi,
            ),
          ),
          completedAt: $checkedConvert(
            'completed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          completedSteps: $checkedConvert(
            'completed_steps',
            (v) => (v as List<dynamic>).map((e) => e as String).toList(),
          ),
          currentStep: $checkedConvert(
            'current_step',
            (v) => $enumDecode(
              _$OnboardingStateCurrentStepEnumEnumMap,
              v,
              unknownValue:
                  OnboardingStateCurrentStepEnum.unknownDefaultOpenApi,
            ),
          ),
          schemaVersion: $checkedConvert(
            'schema_version',
            (v) => (v as num).toInt(),
          ),
          version: $checkedConvert('version', (v) => (v as num).toInt()),
        );
        return val;
      },
      fieldKeyMap: const {
        'completedAt': 'completed_at',
        'completedSteps': 'completed_steps',
        'currentStep': 'current_step',
        'schemaVersion': 'schema_version',
      },
    );

Map<String, dynamic> _$OnboardingStateToJson(OnboardingState instance) =>
    <String, dynamic>{
      'cohort': _$OnboardingStateCohortEnumEnumMap[instance.cohort]!,
      'completed_at': instance.completedAt?.toIso8601String(),
      'completed_steps': instance.completedSteps,
      'current_step':
          _$OnboardingStateCurrentStepEnumEnumMap[instance.currentStep]!,
      'schema_version': instance.schemaVersion,
      'version': instance.version,
    };

const _$OnboardingStateCohortEnumEnumMap = {
  OnboardingStateCohortEnum.legacyCompleteV1: 'legacy_complete_v1',
  OnboardingStateCohortEnum.legacyIncompleteV1: 'legacy_incomplete_v1',
  OnboardingStateCohortEnum.memberV2: 'member_v2',
  OnboardingStateCohortEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$OnboardingStateCurrentStepEnumEnumMap = {
  OnboardingStateCurrentStepEnum.welcome: 'welcome',
  OnboardingStateCurrentStepEnum.ritual: 'ritual',
  OnboardingStateCurrentStepEnum.profile: 'profile',
  OnboardingStateCurrentStepEnum.complete: 'complete',
  OnboardingStateCurrentStepEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
