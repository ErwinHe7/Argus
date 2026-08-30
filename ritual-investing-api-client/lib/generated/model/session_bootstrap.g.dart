// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapCWProxy {
  SessionBootstrap astrologyProfile(Map<String, Object?>? astrologyProfile);

  SessionBootstrap branchCapabilities(
    MemberBranchCapabilities branchCapabilities,
  );

  SessionBootstrap investorProfile(InvestorProfile? investorProfile);

  SessionBootstrap member(SessionMember member);

  SessionBootstrap onboarding(OnboardingState? onboarding);

  SessionBootstrap preferences(MemberPreferences? preferences);

  SessionBootstrap profile(MemberProfile? profile);

  SessionBootstrap serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrap(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrap(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrap call({
    Map<String, Object?>? astrologyProfile,
    MemberBranchCapabilities branchCapabilities,
    InvestorProfile? investorProfile,
    SessionMember member,
    OnboardingState? onboarding,
    MemberPreferences? preferences,
    MemberProfile? profile,
    DateTime serverTime,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrap.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrap.copyWith.fieldName(...)`
class _$SessionBootstrapCWProxyImpl implements _$SessionBootstrapCWProxy {
  const _$SessionBootstrapCWProxyImpl(this._value);

  final SessionBootstrap _value;

  @override
  SessionBootstrap astrologyProfile(Map<String, Object?>? astrologyProfile) =>
      this(astrologyProfile: astrologyProfile);

  @override
  SessionBootstrap branchCapabilities(
    MemberBranchCapabilities branchCapabilities,
  ) => this(branchCapabilities: branchCapabilities);

  @override
  SessionBootstrap investorProfile(InvestorProfile? investorProfile) =>
      this(investorProfile: investorProfile);

  @override
  SessionBootstrap member(SessionMember member) => this(member: member);

  @override
  SessionBootstrap onboarding(OnboardingState? onboarding) =>
      this(onboarding: onboarding);

  @override
  SessionBootstrap preferences(MemberPreferences? preferences) =>
      this(preferences: preferences);

  @override
  SessionBootstrap profile(MemberProfile? profile) => this(profile: profile);

  @override
  SessionBootstrap serverTime(DateTime serverTime) =>
      this(serverTime: serverTime);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrap(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrap(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrap call({
    Object? astrologyProfile = const $CopyWithPlaceholder(),
    Object? branchCapabilities = const $CopyWithPlaceholder(),
    Object? investorProfile = const $CopyWithPlaceholder(),
    Object? member = const $CopyWithPlaceholder(),
    Object? onboarding = const $CopyWithPlaceholder(),
    Object? preferences = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrap(
      astrologyProfile: astrologyProfile == const $CopyWithPlaceholder()
          ? _value.astrologyProfile
          // ignore: cast_nullable_to_non_nullable
          : astrologyProfile as Map<String, Object?>?,
      branchCapabilities: branchCapabilities == const $CopyWithPlaceholder()
          ? _value.branchCapabilities
          // ignore: cast_nullable_to_non_nullable
          : branchCapabilities as MemberBranchCapabilities,
      investorProfile: investorProfile == const $CopyWithPlaceholder()
          ? _value.investorProfile
          // ignore: cast_nullable_to_non_nullable
          : investorProfile as InvestorProfile?,
      member: member == const $CopyWithPlaceholder()
          ? _value.member
          // ignore: cast_nullable_to_non_nullable
          : member as SessionMember,
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
      serverTime: serverTime == const $CopyWithPlaceholder()
          ? _value.serverTime
          // ignore: cast_nullable_to_non_nullable
          : serverTime as DateTime,
    );
  }
}

extension $SessionBootstrapCopyWith on SessionBootstrap {
  /// Returns a callable class that can be used as follows: `instanceOfSessionBootstrap.copyWith(...)` or like so:`instanceOfSessionBootstrap.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionBootstrapCWProxy get copyWith => _$SessionBootstrapCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionBootstrap _$SessionBootstrapFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SessionBootstrap',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'astrology_profile',
            'branch_capabilities',
            'investor_profile',
            'member',
            'onboarding',
            'preferences',
            'profile',
            'server_time',
          ],
        );
        final val = SessionBootstrap(
          astrologyProfile: $checkedConvert(
            'astrology_profile',
            (v) => v as Map<String, dynamic>?,
          ),
          branchCapabilities: $checkedConvert(
            'branch_capabilities',
            (v) => MemberBranchCapabilities.fromJson(v as Map<String, dynamic>),
          ),
          investorProfile: $checkedConvert(
            'investor_profile',
            (v) => v == null
                ? null
                : InvestorProfile.fromJson(v as Map<String, dynamic>),
          ),
          member: $checkedConvert(
            'member',
            (v) => SessionMember.fromJson(v as Map<String, dynamic>),
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
          serverTime: $checkedConvert(
            'server_time',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'astrologyProfile': 'astrology_profile',
        'branchCapabilities': 'branch_capabilities',
        'investorProfile': 'investor_profile',
        'serverTime': 'server_time',
      },
    );

Map<String, dynamic> _$SessionBootstrapToJson(SessionBootstrap instance) =>
    <String, dynamic>{
      'astrology_profile': instance.astrologyProfile,
      'branch_capabilities': instance.branchCapabilities.toJson(),
      'investor_profile': instance.investorProfile?.toJson(),
      'member': instance.member.toJson(),
      'onboarding': instance.onboarding?.toJson(),
      'preferences': instance.preferences?.toJson(),
      'profile': instance.profile?.toJson(),
      'server_time': instance.serverTime.toIso8601String(),
    };
