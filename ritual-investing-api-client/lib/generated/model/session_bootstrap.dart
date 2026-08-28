//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/investor_profile.dart';
import 'package:ritual_investing_api_client/generated/model/onboarding_state.dart';
import 'package:ritual_investing_api_client/generated/model/member_preferences.dart';
import 'package:ritual_investing_api_client/generated/model/session_member.dart';
import 'package:ritual_investing_api_client/generated/model/member_profile.dart';
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
    required this.astrologyProfile,

    required this.investorProfile,

    required this.member,

    required this.onboarding,

    required this.preferences,

    required this.profile,

    required this.serverTime,
  });

  @JsonKey(name: r'astrology_profile', required: true, includeIfNull: true)
  final Map<String, Object?>? astrologyProfile;

  @JsonKey(name: r'investor_profile', required: true, includeIfNull: true)
  final InvestorProfile? investorProfile;

  @JsonKey(name: r'member', required: true, includeIfNull: false)
  final SessionMember member;

  @JsonKey(name: r'onboarding', required: true, includeIfNull: true)
  final OnboardingState? onboarding;

  @JsonKey(name: r'preferences', required: true, includeIfNull: true)
  final MemberPreferences? preferences;

  @JsonKey(name: r'profile', required: true, includeIfNull: true)
  final MemberProfile? profile;

  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionBootstrap &&
          other.astrologyProfile == astrologyProfile &&
          other.investorProfile == investorProfile &&
          other.member == member &&
          other.onboarding == onboarding &&
          other.preferences == preferences &&
          other.profile == profile &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      (astrologyProfile == null ? 0 : astrologyProfile.hashCode) +
      (investorProfile == null ? 0 : investorProfile.hashCode) +
      member.hashCode +
      (onboarding == null ? 0 : onboarding.hashCode) +
      (preferences == null ? 0 : preferences.hashCode) +
      (profile == null ? 0 : profile.hashCode) +
      serverTime.hashCode;

  factory SessionBootstrap.fromJson(Map<String, dynamic> json) =>
      _$SessionBootstrapFromJson(json);

  Map<String, dynamic> toJson() => _$SessionBootstrapToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
