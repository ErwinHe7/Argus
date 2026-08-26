// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap_onboarding.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapOnboardingCWProxy {
  SessionBootstrapOnboarding cohort(
    SessionBootstrapOnboardingCohortEnum cohort,
  );

  SessionBootstrapOnboarding completedAt(DateTime? completedAt);

  SessionBootstrapOnboarding completedSteps(List<String> completedSteps);

  SessionBootstrapOnboarding currentStep(String currentStep);

  SessionBootstrapOnboarding schemaVersion(int schemaVersion);

  SessionBootstrapOnboarding version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrapOnboarding(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrapOnboarding(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrapOnboarding call({
    SessionBootstrapOnboardingCohortEnum cohort,
    DateTime? completedAt,
    List<String> completedSteps,
    String currentStep,
    int schemaVersion,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrapOnboarding.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrapOnboarding.copyWith.fieldName(...)`
class _$SessionBootstrapOnboardingCWProxyImpl
    implements _$SessionBootstrapOnboardingCWProxy {
  const _$SessionBootstrapOnboardingCWProxyImpl(this._value);

  final SessionBootstrapOnboarding _value;

  @override
  SessionBootstrapOnboarding cohort(
    SessionBootstrapOnboardingCohortEnum cohort,
  ) => this(cohort: cohort);

  @override
  SessionBootstrapOnboarding completedAt(DateTime? completedAt) =>
      this(completedAt: completedAt);

  @override
  SessionBootstrapOnboarding completedSteps(List<String> completedSteps) =>
      this(completedSteps: completedSteps);

  @override
  SessionBootstrapOnboarding currentStep(String currentStep) =>
      this(currentStep: currentStep);

  @override
  SessionBootstrapOnboarding schemaVersion(int schemaVersion) =>
      this(schemaVersion: schemaVersion);

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
    Object? cohort = const $CopyWithPlaceholder(),
    Object? completedAt = const $CopyWithPlaceholder(),
    Object? completedSteps = const $CopyWithPlaceholder(),
    Object? currentStep = const $CopyWithPlaceholder(),
    Object? schemaVersion = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrapOnboarding(
      cohort: cohort == const $CopyWithPlaceholder()
          ? _value.cohort
          // ignore: cast_nullable_to_non_nullable
          : cohort as SessionBootstrapOnboardingCohortEnum,
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
          : currentStep as String,
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
      requiredKeys: const [
        'cohort',
        'completed_at',
        'completed_steps',
        'current_step',
        'schema_version',
        'version',
      ],
    );
    final val = SessionBootstrapOnboarding(
      cohort: $checkedConvert(
        'cohort',
        (v) => $enumDecode(
          _$SessionBootstrapOnboardingCohortEnumEnumMap,
          v,
          unknownValue:
              SessionBootstrapOnboardingCohortEnum.unknownDefaultOpenApi,
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
      currentStep: $checkedConvert('current_step', (v) => v as String),
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

Map<String, dynamic> _$SessionBootstrapOnboardingToJson(
  SessionBootstrapOnboarding instance,
) => <String, dynamic>{
  'cohort': _$SessionBootstrapOnboardingCohortEnumEnumMap[instance.cohort]!,
  'completed_at': instance.completedAt?.toIso8601String(),
  'completed_steps': instance.completedSteps,
  'current_step': instance.currentStep,
  'schema_version': instance.schemaVersion,
  'version': instance.version,
};

const _$SessionBootstrapOnboardingCohortEnumEnumMap = {
  SessionBootstrapOnboardingCohortEnum.legacyCompleteV1: 'legacy_complete_v1',
  SessionBootstrapOnboardingCohortEnum.legacyIncompleteV1:
      'legacy_incomplete_v1',
  SessionBootstrapOnboardingCohortEnum.memberV2: 'member_v2',
  SessionBootstrapOnboardingCohortEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
