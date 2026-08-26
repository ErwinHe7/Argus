// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapCWProxy {
  SessionBootstrap account(MemberAccountViewAccount account);

  SessionBootstrap astrologyProfile(
    SessionBootstrapAstrologyProfile? astrologyProfile,
  );

  SessionBootstrap contractVersion(
    SessionBootstrapContractVersionEnum contractVersion,
  );

  SessionBootstrap defaultPortfolio(
    SessionBootstrapDefaultPortfolio defaultPortfolio,
  );

  SessionBootstrap entitlement(SessionBootstrapEntitlement entitlement);

  SessionBootstrap investorProfile(
    SessionBootstrapInvestorProfile? investorProfile,
  );

  SessionBootstrap onboarding(SessionBootstrapOnboarding onboarding);

  SessionBootstrap preferences(SessionBootstrapPreferences preferences);

  SessionBootstrap profile(SessionBootstrapProfile profile);

  SessionBootstrap resetGeneration(int resetGeneration);

  SessionBootstrap serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrap(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrap(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrap call({
    MemberAccountViewAccount account,
    SessionBootstrapAstrologyProfile? astrologyProfile,
    SessionBootstrapContractVersionEnum contractVersion,
    SessionBootstrapDefaultPortfolio defaultPortfolio,
    SessionBootstrapEntitlement entitlement,
    SessionBootstrapInvestorProfile? investorProfile,
    SessionBootstrapOnboarding onboarding,
    SessionBootstrapPreferences preferences,
    SessionBootstrapProfile profile,
    int resetGeneration,
    DateTime serverTime,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionBootstrap.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionBootstrap.copyWith.fieldName(...)`
class _$SessionBootstrapCWProxyImpl implements _$SessionBootstrapCWProxy {
  const _$SessionBootstrapCWProxyImpl(this._value);

  final SessionBootstrap _value;

  @override
  SessionBootstrap account(MemberAccountViewAccount account) =>
      this(account: account);

  @override
  SessionBootstrap astrologyProfile(
    SessionBootstrapAstrologyProfile? astrologyProfile,
  ) => this(astrologyProfile: astrologyProfile);

  @override
  SessionBootstrap contractVersion(
    SessionBootstrapContractVersionEnum contractVersion,
  ) => this(contractVersion: contractVersion);

  @override
  SessionBootstrap defaultPortfolio(
    SessionBootstrapDefaultPortfolio defaultPortfolio,
  ) => this(defaultPortfolio: defaultPortfolio);

  @override
  SessionBootstrap entitlement(SessionBootstrapEntitlement entitlement) =>
      this(entitlement: entitlement);

  @override
  SessionBootstrap investorProfile(
    SessionBootstrapInvestorProfile? investorProfile,
  ) => this(investorProfile: investorProfile);

  @override
  SessionBootstrap onboarding(SessionBootstrapOnboarding onboarding) =>
      this(onboarding: onboarding);

  @override
  SessionBootstrap preferences(SessionBootstrapPreferences preferences) =>
      this(preferences: preferences);

  @override
  SessionBootstrap profile(SessionBootstrapProfile profile) =>
      this(profile: profile);

  @override
  SessionBootstrap resetGeneration(int resetGeneration) =>
      this(resetGeneration: resetGeneration);

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
    Object? account = const $CopyWithPlaceholder(),
    Object? astrologyProfile = const $CopyWithPlaceholder(),
    Object? contractVersion = const $CopyWithPlaceholder(),
    Object? defaultPortfolio = const $CopyWithPlaceholder(),
    Object? entitlement = const $CopyWithPlaceholder(),
    Object? investorProfile = const $CopyWithPlaceholder(),
    Object? onboarding = const $CopyWithPlaceholder(),
    Object? preferences = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
    Object? resetGeneration = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrap(
      account: account == const $CopyWithPlaceholder()
          ? _value.account
          // ignore: cast_nullable_to_non_nullable
          : account as MemberAccountViewAccount,
      astrologyProfile: astrologyProfile == const $CopyWithPlaceholder()
          ? _value.astrologyProfile
          // ignore: cast_nullable_to_non_nullable
          : astrologyProfile as SessionBootstrapAstrologyProfile?,
      contractVersion: contractVersion == const $CopyWithPlaceholder()
          ? _value.contractVersion
          // ignore: cast_nullable_to_non_nullable
          : contractVersion as SessionBootstrapContractVersionEnum,
      defaultPortfolio: defaultPortfolio == const $CopyWithPlaceholder()
          ? _value.defaultPortfolio
          // ignore: cast_nullable_to_non_nullable
          : defaultPortfolio as SessionBootstrapDefaultPortfolio,
      entitlement: entitlement == const $CopyWithPlaceholder()
          ? _value.entitlement
          // ignore: cast_nullable_to_non_nullable
          : entitlement as SessionBootstrapEntitlement,
      investorProfile: investorProfile == const $CopyWithPlaceholder()
          ? _value.investorProfile
          // ignore: cast_nullable_to_non_nullable
          : investorProfile as SessionBootstrapInvestorProfile?,
      onboarding: onboarding == const $CopyWithPlaceholder()
          ? _value.onboarding
          // ignore: cast_nullable_to_non_nullable
          : onboarding as SessionBootstrapOnboarding,
      preferences: preferences == const $CopyWithPlaceholder()
          ? _value.preferences
          // ignore: cast_nullable_to_non_nullable
          : preferences as SessionBootstrapPreferences,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as SessionBootstrapProfile,
      resetGeneration: resetGeneration == const $CopyWithPlaceholder()
          ? _value.resetGeneration
          // ignore: cast_nullable_to_non_nullable
          : resetGeneration as int,
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
            'account',
            'astrology_profile',
            'contract_version',
            'default_portfolio',
            'entitlement',
            'investor_profile',
            'onboarding',
            'preferences',
            'profile',
            'reset_generation',
            'server_time',
          ],
        );
        final val = SessionBootstrap(
          account: $checkedConvert(
            'account',
            (v) => MemberAccountViewAccount.fromJson(v as Map<String, dynamic>),
          ),
          astrologyProfile: $checkedConvert(
            'astrology_profile',
            (v) => v == null
                ? null
                : SessionBootstrapAstrologyProfile.fromJson(
                    v as Map<String, dynamic>,
                  ),
          ),
          contractVersion: $checkedConvert(
            'contract_version',
            (v) => $enumDecode(
              _$SessionBootstrapContractVersionEnumEnumMap,
              v,
              unknownValue:
                  SessionBootstrapContractVersionEnum.unknownDefaultOpenApi,
            ),
          ),
          defaultPortfolio: $checkedConvert(
            'default_portfolio',
            (v) => SessionBootstrapDefaultPortfolio.fromJson(
              v as Map<String, dynamic>,
            ),
          ),
          entitlement: $checkedConvert(
            'entitlement',
            (v) =>
                SessionBootstrapEntitlement.fromJson(v as Map<String, dynamic>),
          ),
          investorProfile: $checkedConvert(
            'investor_profile',
            (v) => v == null
                ? null
                : SessionBootstrapInvestorProfile.fromJson(
                    v as Map<String, dynamic>,
                  ),
          ),
          onboarding: $checkedConvert(
            'onboarding',
            (v) =>
                SessionBootstrapOnboarding.fromJson(v as Map<String, dynamic>),
          ),
          preferences: $checkedConvert(
            'preferences',
            (v) =>
                SessionBootstrapPreferences.fromJson(v as Map<String, dynamic>),
          ),
          profile: $checkedConvert(
            'profile',
            (v) => SessionBootstrapProfile.fromJson(v as Map<String, dynamic>),
          ),
          resetGeneration: $checkedConvert(
            'reset_generation',
            (v) => (v as num).toInt(),
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
        'contractVersion': 'contract_version',
        'defaultPortfolio': 'default_portfolio',
        'investorProfile': 'investor_profile',
        'resetGeneration': 'reset_generation',
        'serverTime': 'server_time',
      },
    );

Map<String, dynamic> _$SessionBootstrapToJson(
  SessionBootstrap instance,
) => <String, dynamic>{
  'account': instance.account.toJson(),
  'astrology_profile': instance.astrologyProfile?.toJson(),
  'contract_version':
      _$SessionBootstrapContractVersionEnumEnumMap[instance.contractVersion]!,
  'default_portfolio': instance.defaultPortfolio.toJson(),
  'entitlement': instance.entitlement.toJson(),
  'investor_profile': instance.investorProfile?.toJson(),
  'onboarding': instance.onboarding.toJson(),
  'preferences': instance.preferences.toJson(),
  'profile': instance.profile.toJson(),
  'reset_generation': instance.resetGeneration,
  'server_time': instance.serverTime.toIso8601String(),
};

const _$SessionBootstrapContractVersionEnumEnumMap = {
  SessionBootstrapContractVersionEnum.n1period0Period0: '1.0.0',
  SessionBootstrapContractVersionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
