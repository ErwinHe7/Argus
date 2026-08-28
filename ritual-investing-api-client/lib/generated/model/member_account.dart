//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:ritual_investing_api_client/generated/model/investor_profile.dart';
import 'package:ritual_investing_api_client/generated/model/onboarding_state.dart';
import 'package:ritual_investing_api_client/generated/model/member_preferences.dart';
import 'package:ritual_investing_api_client/generated/model/member_profile.dart';
import 'package:ritual_investing_api_client/generated/model/astrology_profile.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'member_account.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemberAccount {
  /// Returns a new [MemberAccount] instance.
  MemberAccount({
    required this.astrologyProfile,

    required this.deletionEpoch,

    required this.investorProfile,

    required this.onboarding,

    required this.preferences,

    required this.profile,

    required this.status,
  });

  @JsonKey(name: r'astrology_profile', required: true, includeIfNull: true)
  final AstrologyProfile? astrologyProfile;

  // minimum: 0
  @JsonKey(name: r'deletion_epoch', required: true, includeIfNull: true)
  final int? deletionEpoch;

  @JsonKey(name: r'investor_profile', required: true, includeIfNull: true)
  final InvestorProfile? investorProfile;

  @JsonKey(name: r'onboarding', required: true, includeIfNull: true)
  final OnboardingState? onboarding;

  @JsonKey(name: r'preferences', required: true, includeIfNull: true)
  final MemberPreferences? preferences;

  @JsonKey(name: r'profile', required: true, includeIfNull: true)
  final MemberProfile? profile;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: MemberAccountStatusEnum.unknownDefaultOpenApi,
  )
  final MemberAccountStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemberAccount &&
          other.astrologyProfile == astrologyProfile &&
          other.deletionEpoch == deletionEpoch &&
          other.investorProfile == investorProfile &&
          other.onboarding == onboarding &&
          other.preferences == preferences &&
          other.profile == profile &&
          other.status == status;

  @override
  int get hashCode =>
      (astrologyProfile == null ? 0 : astrologyProfile.hashCode) +
      (deletionEpoch == null ? 0 : deletionEpoch.hashCode) +
      (investorProfile == null ? 0 : investorProfile.hashCode) +
      (onboarding == null ? 0 : onboarding.hashCode) +
      (preferences == null ? 0 : preferences.hashCode) +
      (profile == null ? 0 : profile.hashCode) +
      status.hashCode;

  factory MemberAccount.fromJson(Map<String, dynamic> json) =>
      _$MemberAccountFromJson(json);

  Map<String, dynamic> toJson() => _$MemberAccountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MemberAccountStatusEnum {
  @JsonValue(r'active')
  active(r'active'),
  @JsonValue(r'suspended')
  suspended(r'suspended'),
  @JsonValue(r'deletion_pending')
  deletionPending(r'deletion_pending'),
  @JsonValue(r'purging')
  purging(r'purging'),
  @JsonValue(r'purged')
  purged(r'purged'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MemberAccountStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
