// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_onboarding_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PatchOnboardingRequestCWProxy {
  PatchOnboardingRequest completedSteps(List<String> completedSteps);

  PatchOnboardingRequest currentStep(
    PatchOnboardingRequestCurrentStepEnum currentStep,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchOnboardingRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchOnboardingRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchOnboardingRequest call({
    List<String> completedSteps,
    PatchOnboardingRequestCurrentStepEnum currentStep,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPatchOnboardingRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPatchOnboardingRequest.copyWith.fieldName(...)`
class _$PatchOnboardingRequestCWProxyImpl
    implements _$PatchOnboardingRequestCWProxy {
  const _$PatchOnboardingRequestCWProxyImpl(this._value);

  final PatchOnboardingRequest _value;

  @override
  PatchOnboardingRequest completedSteps(List<String> completedSteps) =>
      this(completedSteps: completedSteps);

  @override
  PatchOnboardingRequest currentStep(
    PatchOnboardingRequestCurrentStepEnum currentStep,
  ) => this(currentStep: currentStep);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PatchOnboardingRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PatchOnboardingRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PatchOnboardingRequest call({
    Object? completedSteps = const $CopyWithPlaceholder(),
    Object? currentStep = const $CopyWithPlaceholder(),
  }) {
    return PatchOnboardingRequest(
      completedSteps: completedSteps == const $CopyWithPlaceholder()
          ? _value.completedSteps
          // ignore: cast_nullable_to_non_nullable
          : completedSteps as List<String>,
      currentStep: currentStep == const $CopyWithPlaceholder()
          ? _value.currentStep
          // ignore: cast_nullable_to_non_nullable
          : currentStep as PatchOnboardingRequestCurrentStepEnum,
    );
  }
}

extension $PatchOnboardingRequestCopyWith on PatchOnboardingRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPatchOnboardingRequest.copyWith(...)` or like so:`instanceOfPatchOnboardingRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PatchOnboardingRequestCWProxy get copyWith =>
      _$PatchOnboardingRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchOnboardingRequest _$PatchOnboardingRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PatchOnboardingRequest',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['completed_steps', 'current_step']);
    final val = PatchOnboardingRequest(
      completedSteps: $checkedConvert(
        'completed_steps',
        (v) => (v as List<dynamic>).map((e) => e as String).toList(),
      ),
      currentStep: $checkedConvert(
        'current_step',
        (v) => $enumDecode(
          _$PatchOnboardingRequestCurrentStepEnumEnumMap,
          v,
          unknownValue:
              PatchOnboardingRequestCurrentStepEnum.unknownDefaultOpenApi,
        ),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'completedSteps': 'completed_steps',
    'currentStep': 'current_step',
  },
);

Map<String, dynamic> _$PatchOnboardingRequestToJson(
  PatchOnboardingRequest instance,
) => <String, dynamic>{
  'completed_steps': instance.completedSteps,
  'current_step':
      _$PatchOnboardingRequestCurrentStepEnumEnumMap[instance.currentStep]!,
};

const _$PatchOnboardingRequestCurrentStepEnumEnumMap = {
  PatchOnboardingRequestCurrentStepEnum.ritual: 'ritual',
  PatchOnboardingRequestCurrentStepEnum.profile: 'profile',
  PatchOnboardingRequestCurrentStepEnum.complete: 'complete',
  PatchOnboardingRequestCurrentStepEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
