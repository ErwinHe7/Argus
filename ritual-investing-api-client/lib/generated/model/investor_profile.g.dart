// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'investor_profile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InvestorProfileCWProxy {
  InvestorProfile deletionEpoch(int? deletionEpoch);

  InvestorProfile goalType(InvestorProfileGoalTypeEnum goalType);

  InvestorProfile riskComfort(InvestorProfileRiskComfortEnum riskComfort);

  InvestorProfile timeHorizon(InvestorProfileTimeHorizonEnum timeHorizon);

  InvestorProfile userId(String userId);

  InvestorProfile version(int version);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InvestorProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InvestorProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  InvestorProfile call({
    int? deletionEpoch,
    InvestorProfileGoalTypeEnum goalType,
    InvestorProfileRiskComfortEnum riskComfort,
    InvestorProfileTimeHorizonEnum timeHorizon,
    String userId,
    int version,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfInvestorProfile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfInvestorProfile.copyWith.fieldName(...)`
class _$InvestorProfileCWProxyImpl implements _$InvestorProfileCWProxy {
  const _$InvestorProfileCWProxyImpl(this._value);

  final InvestorProfile _value;

  @override
  InvestorProfile deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  InvestorProfile goalType(InvestorProfileGoalTypeEnum goalType) =>
      this(goalType: goalType);

  @override
  InvestorProfile riskComfort(InvestorProfileRiskComfortEnum riskComfort) =>
      this(riskComfort: riskComfort);

  @override
  InvestorProfile timeHorizon(InvestorProfileTimeHorizonEnum timeHorizon) =>
      this(timeHorizon: timeHorizon);

  @override
  InvestorProfile userId(String userId) => this(userId: userId);

  @override
  InvestorProfile version(int version) => this(version: version);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InvestorProfile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InvestorProfile(...).copyWith(id: 12, name: "My name")
  /// ````
  InvestorProfile call({
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? goalType = const $CopyWithPlaceholder(),
    Object? riskComfort = const $CopyWithPlaceholder(),
    Object? timeHorizon = const $CopyWithPlaceholder(),
    Object? userId = const $CopyWithPlaceholder(),
    Object? version = const $CopyWithPlaceholder(),
  }) {
    return InvestorProfile(
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
      goalType: goalType == const $CopyWithPlaceholder()
          ? _value.goalType
          // ignore: cast_nullable_to_non_nullable
          : goalType as InvestorProfileGoalTypeEnum,
      riskComfort: riskComfort == const $CopyWithPlaceholder()
          ? _value.riskComfort
          // ignore: cast_nullable_to_non_nullable
          : riskComfort as InvestorProfileRiskComfortEnum,
      timeHorizon: timeHorizon == const $CopyWithPlaceholder()
          ? _value.timeHorizon
          // ignore: cast_nullable_to_non_nullable
          : timeHorizon as InvestorProfileTimeHorizonEnum,
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as String,
      version: version == const $CopyWithPlaceholder()
          ? _value.version
          // ignore: cast_nullable_to_non_nullable
          : version as int,
    );
  }
}

extension $InvestorProfileCopyWith on InvestorProfile {
  /// Returns a callable class that can be used as follows: `instanceOfInvestorProfile.copyWith(...)` or like so:`instanceOfInvestorProfile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$InvestorProfileCWProxy get copyWith => _$InvestorProfileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvestorProfile _$InvestorProfileFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'InvestorProfile',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'deletion_epoch',
        'goal_type',
        'risk_comfort',
        'time_horizon',
        'user_id',
        'version',
      ],
    );
    final val = InvestorProfile(
      deletionEpoch: $checkedConvert(
        'deletion_epoch',
        (v) => (v as num?)?.toInt(),
      ),
      goalType: $checkedConvert(
        'goal_type',
        (v) => $enumDecode(
          _$InvestorProfileGoalTypeEnumEnumMap,
          v,
          unknownValue: InvestorProfileGoalTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      riskComfort: $checkedConvert(
        'risk_comfort',
        (v) => $enumDecode(
          _$InvestorProfileRiskComfortEnumEnumMap,
          v,
          unknownValue: InvestorProfileRiskComfortEnum.unknownDefaultOpenApi,
        ),
      ),
      timeHorizon: $checkedConvert(
        'time_horizon',
        (v) => $enumDecode(
          _$InvestorProfileTimeHorizonEnumEnumMap,
          v,
          unknownValue: InvestorProfileTimeHorizonEnum.unknownDefaultOpenApi,
        ),
      ),
      userId: $checkedConvert('user_id', (v) => v as String),
      version: $checkedConvert('version', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'deletionEpoch': 'deletion_epoch',
    'goalType': 'goal_type',
    'riskComfort': 'risk_comfort',
    'timeHorizon': 'time_horizon',
    'userId': 'user_id',
  },
);

Map<String, dynamic> _$InvestorProfileToJson(InvestorProfile instance) =>
    <String, dynamic>{
      'deletion_epoch': instance.deletionEpoch,
      'goal_type': _$InvestorProfileGoalTypeEnumEnumMap[instance.goalType]!,
      'risk_comfort':
          _$InvestorProfileRiskComfortEnumEnumMap[instance.riskComfort]!,
      'time_horizon':
          _$InvestorProfileTimeHorizonEnumEnumMap[instance.timeHorizon]!,
      'user_id': instance.userId,
      'version': instance.version,
    };

const _$InvestorProfileGoalTypeEnumEnumMap = {
  InvestorProfileGoalTypeEnum.calmFund: 'calm_fund',
  InvestorProfileGoalTypeEnum.longTermGrowth: 'long_term_growth',
  InvestorProfileGoalTypeEnum.income: 'income',
  InvestorProfileGoalTypeEnum.exploration: 'exploration',
  InvestorProfileGoalTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$InvestorProfileRiskComfortEnumEnumMap = {
  InvestorProfileRiskComfortEnum.low: 'low',
  InvestorProfileRiskComfortEnum.moderate: 'moderate',
  InvestorProfileRiskComfortEnum.high: 'high',
  InvestorProfileRiskComfortEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$InvestorProfileTimeHorizonEnumEnumMap = {
  InvestorProfileTimeHorizonEnum.short: 'short',
  InvestorProfileTimeHorizonEnum.medium: 'medium',
  InvestorProfileTimeHorizonEnum.long: 'long',
  InvestorProfileTimeHorizonEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
