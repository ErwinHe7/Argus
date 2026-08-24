// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_bootstrap.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionBootstrapCWProxy {
  SessionBootstrap account(MemberAccountViewAccount account);

  SessionBootstrap contractVersion(
    SessionBootstrapContractVersionEnum contractVersion,
  );

  SessionBootstrap defaultPortfolio(
    SessionBootstrapDefaultPortfolio defaultPortfolio,
  );

  SessionBootstrap entitlement(SessionBootstrapEntitlement entitlement);

  SessionBootstrap onboarding(SessionBootstrapOnboarding onboarding);

  SessionBootstrap preferences(SessionBootstrapPreferences preferences);

  SessionBootstrap profile(SessionBootstrapProfile profile);

  SessionBootstrap serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionBootstrap(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionBootstrap(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionBootstrap call({
    MemberAccountViewAccount account,
    SessionBootstrapContractVersionEnum contractVersion,
    SessionBootstrapDefaultPortfolio defaultPortfolio,
    SessionBootstrapEntitlement entitlement,
    SessionBootstrapOnboarding onboarding,
    SessionBootstrapPreferences preferences,
    SessionBootstrapProfile profile,
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
  SessionBootstrap onboarding(SessionBootstrapOnboarding onboarding) =>
      this(onboarding: onboarding);

  @override
  SessionBootstrap preferences(SessionBootstrapPreferences preferences) =>
      this(preferences: preferences);

  @override
  SessionBootstrap profile(SessionBootstrapProfile profile) =>
      this(profile: profile);

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
    Object? contractVersion = const $CopyWithPlaceholder(),
    Object? defaultPortfolio = const $CopyWithPlaceholder(),
    Object? entitlement = const $CopyWithPlaceholder(),
    Object? onboarding = const $CopyWithPlaceholder(),
    Object? preferences = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return SessionBootstrap(
      account: account == const $CopyWithPlaceholder()
          ? _value.account
          // ignore: cast_nullable_to_non_nullable
          : account as MemberAccountViewAccount,
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
            'contract_version',
            'default_portfolio',
            'entitlement',
            'onboarding',
            'preferences',
            'profile',
            'server_time',
          ],
        );
        final val = SessionBootstrap(
          account: $checkedConvert(
            'account',
            (v) => MemberAccountViewAccount.fromJson(v as Map<String, dynamic>),
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
          serverTime: $checkedConvert(
            'server_time',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'contractVersion': 'contract_version',
        'defaultPortfolio': 'default_portfolio',
        'serverTime': 'server_time',
      },
    );

Map<String, dynamic> _$SessionBootstrapToJson(
  SessionBootstrap instance,
) => <String, dynamic>{
  'account': instance.account.toJson(),
  'contract_version':
      _$SessionBootstrapContractVersionEnumEnumMap[instance.contractVersion]!,
  'default_portfolio': instance.defaultPortfolio.toJson(),
  'entitlement': instance.entitlement.toJson(),
  'onboarding': instance.onboarding.toJson(),
  'preferences': instance.preferences.toJson(),
  'profile': instance.profile.toJson(),
  'server_time': instance.serverTime.toIso8601String(),
};

const _$SessionBootstrapContractVersionEnumEnumMap = {
  SessionBootstrapContractVersionEnum.n1period0Period0: '1.0.0',
  SessionBootstrapContractVersionEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
