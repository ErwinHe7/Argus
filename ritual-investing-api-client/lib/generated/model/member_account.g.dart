// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'member_account.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemberAccountCWProxy {
  MemberAccount astrologyProfile(AstrologyProfile? astrologyProfile);

  MemberAccount deletionEpoch(int? deletionEpoch);

  MemberAccount investorProfile(InvestorProfile? investorProfile);

  MemberAccount onboarding(OnboardingState? onboarding);

  MemberAccount preferences(MemberPreferences? preferences);

  MemberAccount profile(MemberProfile? profile);

  MemberAccount status(MemberAccountStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberAccount call({
    AstrologyProfile? astrologyProfile,
    int? deletionEpoch,
    InvestorProfile? investorProfile,
    OnboardingState? onboarding,
    MemberPreferences? preferences,
    MemberProfile? profile,
    MemberAccountStatusEnum status,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemberAccount.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemberAccount.copyWith.fieldName(...)`
class _$MemberAccountCWProxyImpl implements _$MemberAccountCWProxy {
  const _$MemberAccountCWProxyImpl(this._value);

  final MemberAccount _value;

  @override
  MemberAccount astrologyProfile(AstrologyProfile? astrologyProfile) =>
      this(astrologyProfile: astrologyProfile);

  @override
  MemberAccount deletionEpoch(int? deletionEpoch) =>
      this(deletionEpoch: deletionEpoch);

  @override
  MemberAccount investorProfile(InvestorProfile? investorProfile) =>
      this(investorProfile: investorProfile);

  @override
  MemberAccount onboarding(OnboardingState? onboarding) =>
      this(onboarding: onboarding);

  @override
  MemberAccount preferences(MemberPreferences? preferences) =>
      this(preferences: preferences);

  @override
  MemberAccount profile(MemberProfile? profile) => this(profile: profile);

  @override
  MemberAccount status(MemberAccountStatusEnum status) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemberAccount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemberAccount(...).copyWith(id: 12, name: "My name")
  /// ````
  MemberAccount call({
    Object? astrologyProfile = const $CopyWithPlaceholder(),
    Object? deletionEpoch = const $CopyWithPlaceholder(),
    Object? investorProfile = const $CopyWithPlaceholder(),
    Object? onboarding = const $CopyWithPlaceholder(),
    Object? preferences = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
  }) {
    return MemberAccount(
      astrologyProfile: astrologyProfile == const $CopyWithPlaceholder()
          ? _value.astrologyProfile
          // ignore: cast_nullable_to_non_nullable
          : astrologyProfile as AstrologyProfile?,
      deletionEpoch: deletionEpoch == const $CopyWithPlaceholder()
          ? _value.deletionEpoch
          // ignore: cast_nullable_to_non_nullable
          : deletionEpoch as int?,
      investorProfile: investorProfile == const $CopyWithPlaceholder()
          ? _value.investorProfile
          // ignore: cast_nullable_to_non_nullable
          : investorProfile as InvestorProfile?,
      onboarding: onboarding == const $CopyWithPlaceholder()
          ? _value.onboarding
          // ignore: cast_nullable_to_non_nullable
          : onboarding as OnboardingState?,
      preferences: preferences == const $CopyWithPlaceholder()
          ? _value.preferences
          // ignore: cast_nullable_to_non_nullable
          : preferences as MemberPreferences?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as MemberProfile?,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as MemberAccountStatusEnum,
    );
  }
}

extension $MemberAccountCopyWith on MemberAccount {
  /// Returns a callable class that can be used as follows: `instanceOfMemberAccount.copyWith(...)` or like so:`instanceOfMemberAccount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemberAccountCWProxy get copyWith => _$MemberAccountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemberAccount _$MemberAccountFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'MemberAccount',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'astrology_profile',
            'deletion_epoch',
            'investor_profile',
            'onboarding',
            'preferences',
            'profile',
            'status',
          ],
        );
        final val = MemberAccount(
          astrologyProfile: $checkedConvert(
            'astrology_profile',
            (v) => v == null
                ? null
                : AstrologyProfile.fromJson(v as Map<String, dynamic>),
          ),
          deletionEpoch: $checkedConvert(
            'deletion_epoch',
            (v) => (v as num?)?.toInt(),
          ),
          investorProfile: $checkedConvert(
            'investor_profile',
            (v) => v == null
                ? null
                : InvestorProfile.fromJson(v as Map<String, dynamic>),
          ),
          onboarding: $checkedConvert(
            'onboarding',
            (v) => v == null
                ? null
                : OnboardingState.fromJson(v as Map<String, dynamic>),
          ),
          preferences: $checkedConvert(
            'preferences',
            (v) => v == null
                ? null
                : MemberPreferences.fromJson(v as Map<String, dynamic>),
          ),
          profile: $checkedConvert(
            'profile',
            (v) => v == null
                ? null
                : MemberProfile.fromJson(v as Map<String, dynamic>),
          ),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$MemberAccountStatusEnumEnumMap,
              v,
              unknownValue: MemberAccountStatusEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'astrologyProfile': 'astrology_profile',
        'deletionEpoch': 'deletion_epoch',
        'investorProfile': 'investor_profile',
      },
    );

Map<String, dynamic> _$MemberAccountToJson(MemberAccount instance) =>
    <String, dynamic>{
      'astrology_profile': instance.astrologyProfile?.toJson(),
      'deletion_epoch': instance.deletionEpoch,
      'investor_profile': instance.investorProfile?.toJson(),
      'onboarding': instance.onboarding?.toJson(),
      'preferences': instance.preferences?.toJson(),
      'profile': instance.profile?.toJson(),
      'status': _$MemberAccountStatusEnumEnumMap[instance.status]!,
    };

const _$MemberAccountStatusEnumEnumMap = {
  MemberAccountStatusEnum.active: 'active',
  MemberAccountStatusEnum.suspended: 'suspended',
  MemberAccountStatusEnum.deletionPending: 'deletion_pending',
  MemberAccountStatusEnum.purging: 'purging',
  MemberAccountStatusEnum.purged: 'purged',
  MemberAccountStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
