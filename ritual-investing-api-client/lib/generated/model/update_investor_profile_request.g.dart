// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_investor_profile_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UpdateInvestorProfileRequestCWProxy {
  UpdateInvestorProfileRequest goalType(
    UpdateInvestorProfileRequestGoalTypeEnum goalType,
  );

  UpdateInvestorProfileRequest riskComfort(
    UpdateInvestorProfileRequestRiskComfortEnum riskComfort,
  );

  UpdateInvestorProfileRequest timeHorizon(
    UpdateInvestorProfileRequestTimeHorizonEnum timeHorizon,
  );

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdateInvestorProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdateInvestorProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdateInvestorProfileRequest call({
    UpdateInvestorProfileRequestGoalTypeEnum goalType,
    UpdateInvestorProfileRequestRiskComfortEnum riskComfort,
    UpdateInvestorProfileRequestTimeHorizonEnum timeHorizon,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUpdateInvestorProfileRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUpdateInvestorProfileRequest.copyWith.fieldName(...)`
class _$UpdateInvestorProfileRequestCWProxyImpl
    implements _$UpdateInvestorProfileRequestCWProxy {
  const _$UpdateInvestorProfileRequestCWProxyImpl(this._value);

  final UpdateInvestorProfileRequest _value;

  @override
  UpdateInvestorProfileRequest goalType(
    UpdateInvestorProfileRequestGoalTypeEnum goalType,
  ) => this(goalType: goalType);

  @override
  UpdateInvestorProfileRequest riskComfort(
    UpdateInvestorProfileRequestRiskComfortEnum riskComfort,
  ) => this(riskComfort: riskComfort);

  @override
  UpdateInvestorProfileRequest timeHorizon(
    UpdateInvestorProfileRequestTimeHorizonEnum timeHorizon,
  ) => this(timeHorizon: timeHorizon);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UpdateInvestorProfileRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UpdateInvestorProfileRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  UpdateInvestorProfileRequest call({
    Object? goalType = const $CopyWithPlaceholder(),
    Object? riskComfort = const $CopyWithPlaceholder(),
    Object? timeHorizon = const $CopyWithPlaceholder(),
  }) {
    return UpdateInvestorProfileRequest(
      goalType: goalType == const $CopyWithPlaceholder()
          ? _value.goalType
          // ignore: cast_nullable_to_non_nullable
          : goalType as UpdateInvestorProfileRequestGoalTypeEnum,
      riskComfort: riskComfort == const $CopyWithPlaceholder()
          ? _value.riskComfort
          // ignore: cast_nullable_to_non_nullable
          : riskComfort as UpdateInvestorProfileRequestRiskComfortEnum,
      timeHorizon: timeHorizon == const $CopyWithPlaceholder()
          ? _value.timeHorizon
          // ignore: cast_nullable_to_non_nullable
          : timeHorizon as UpdateInvestorProfileRequestTimeHorizonEnum,
    );
  }
}

extension $UpdateInvestorProfileRequestCopyWith
    on UpdateInvestorProfileRequest {
  /// Returns a callable class that can be used as follows: `instanceOfUpdateInvestorProfileRequest.copyWith(...)` or like so:`instanceOfUpdateInvestorProfileRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UpdateInvestorProfileRequestCWProxy get copyWith =>
      _$UpdateInvestorProfileRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateInvestorProfileRequest _$UpdateInvestorProfileRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('UpdateInvestorProfileRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['goalType', 'riskComfort', 'timeHorizon'],
  );
  final val = UpdateInvestorProfileRequest(
    goalType: $checkedConvert(
      'goalType',
      (v) => $enumDecode(
        _$UpdateInvestorProfileRequestGoalTypeEnumEnumMap,
        v,
        unknownValue:
            UpdateInvestorProfileRequestGoalTypeEnum.unknownDefaultOpenApi,
      ),
    ),
    riskComfort: $checkedConvert(
      'riskComfort',
      (v) => $enumDecode(
        _$UpdateInvestorProfileRequestRiskComfortEnumEnumMap,
        v,
        unknownValue:
            UpdateInvestorProfileRequestRiskComfortEnum.unknownDefaultOpenApi,
      ),
    ),
    timeHorizon: $checkedConvert(
      'timeHorizon',
      (v) => $enumDecode(
        _$UpdateInvestorProfileRequestTimeHorizonEnumEnumMap,
        v,
        unknownValue:
            UpdateInvestorProfileRequestTimeHorizonEnum.unknownDefaultOpenApi,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$UpdateInvestorProfileRequestToJson(
  UpdateInvestorProfileRequest instance,
) => <String, dynamic>{
  'goalType':
      _$UpdateInvestorProfileRequestGoalTypeEnumEnumMap[instance.goalType]!,
  'riskComfort':
      _$UpdateInvestorProfileRequestRiskComfortEnumEnumMap[instance
          .riskComfort]!,
  'timeHorizon':
      _$UpdateInvestorProfileRequestTimeHorizonEnumEnumMap[instance
          .timeHorizon]!,
};

const _$UpdateInvestorProfileRequestGoalTypeEnumEnumMap = {
  UpdateInvestorProfileRequestGoalTypeEnum.calmFund: 'calm_fund',
  UpdateInvestorProfileRequestGoalTypeEnum.longTermGrowth: 'long_term_growth',
  UpdateInvestorProfileRequestGoalTypeEnum.income: 'income',
  UpdateInvestorProfileRequestGoalTypeEnum.exploration: 'exploration',
  UpdateInvestorProfileRequestGoalTypeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$UpdateInvestorProfileRequestRiskComfortEnumEnumMap = {
  UpdateInvestorProfileRequestRiskComfortEnum.low: 'low',
  UpdateInvestorProfileRequestRiskComfortEnum.moderate: 'moderate',
  UpdateInvestorProfileRequestRiskComfortEnum.high: 'high',
  UpdateInvestorProfileRequestRiskComfortEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$UpdateInvestorProfileRequestTimeHorizonEnumEnumMap = {
  UpdateInvestorProfileRequestTimeHorizonEnum.short: 'short',
  UpdateInvestorProfileRequestTimeHorizonEnum.medium: 'medium',
  UpdateInvestorProfileRequestTimeHorizonEnum.long: 'long',
  UpdateInvestorProfileRequestTimeHorizonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
