//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_preferences.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_profile.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_entitlement.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_onboarding.dart';
import 'package:ritual_investing_api_client/generated/model/session_bootstrap_default_portfolio.dart';
import 'package:ritual_investing_api_client/generated/model/member_account_view_account.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_bootstrap.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionBootstrap {
  /// Returns a new [SessionBootstrap] instance.
  SessionBootstrap({
    required this.account,

    required this.contractVersion,

    required this.defaultPortfolio,

    required this.entitlement,

    required this.onboarding,

    required this.preferences,

    required this.profile,

    required this.serverTime,
  });

  @JsonKey(name: r'account', required: true, includeIfNull: false)
  final MemberAccountViewAccount account;

  @JsonKey(
    name: r'contract_version',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SessionBootstrapContractVersionEnum.unknownDefaultOpenApi,
  )
  final SessionBootstrapContractVersionEnum contractVersion;

  @JsonKey(name: r'default_portfolio', required: true, includeIfNull: false)
  final SessionBootstrapDefaultPortfolio defaultPortfolio;

  @JsonKey(name: r'entitlement', required: true, includeIfNull: false)
  final SessionBootstrapEntitlement entitlement;

  @JsonKey(name: r'onboarding', required: true, includeIfNull: false)
  final SessionBootstrapOnboarding onboarding;

  @JsonKey(name: r'preferences', required: true, includeIfNull: false)
  final SessionBootstrapPreferences preferences;

  @JsonKey(name: r'profile', required: true, includeIfNull: false)
  final SessionBootstrapProfile profile;

  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrap &&
          other.account == account &&
          other.contractVersion == contractVersion &&
          other.defaultPortfolio == defaultPortfolio &&
          other.entitlement == entitlement &&
          other.onboarding == onboarding &&
          other.preferences == preferences &&
          other.profile == profile &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      account.hashCode +
      contractVersion.hashCode +
      defaultPortfolio.hashCode +
      entitlement.hashCode +
      onboarding.hashCode +
      preferences.hashCode +
      profile.hashCode +
      serverTime.hashCode;

  factory SessionBootstrap.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum SessionBootstrapContractVersionEnum {
  @JsonValue(r'1.0.0')
  n1period0Period0(r'1.0.0'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SessionBootstrapContractVersionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
