import 'package:flutter/foundation.dart';

import '../../features/brokerage_connection/domain/model.dart';

enum MemberThemePreference { system, light, dark }

enum MemberEntitlementStatus { active, unavailable }

enum MemberExplanationDepth { beginner, guided, advanced, unavailable }

enum MemberRitualVoice { practical, balanced, mystical, unavailable }

enum MemberRiskFraming { low, moderate, high, unavailable }

enum MemberRitualMode { tarot, astrology, unavailable }

enum MemberContributionRhythm {
  weekly,
  biweekly,
  monthly,
  irregular,
  notSure,
  unavailable,
}

@immutable
class MemberPersonalization {
  const MemberPersonalization({
    this.explanationDepth = MemberExplanationDepth.unavailable,
    this.ritualVoice = MemberRitualVoice.unavailable,
    this.riskFraming = MemberRiskFraming.unavailable,
    this.ritualMode = MemberRitualMode.unavailable,
    this.contributionRhythm = MemberContributionRhythm.unavailable,
  });

  final MemberExplanationDepth explanationDepth;
  final MemberRitualVoice ritualVoice;
  final MemberRiskFraming riskFraming;
  final MemberRitualMode ritualMode;
  final MemberContributionRhythm contributionRhythm;

  @override
  bool operator ==(Object other) =>
      other is MemberPersonalization &&
      other.explanationDepth == explanationDepth &&
      other.ritualVoice == ritualVoice &&
      other.riskFraming == riskFraming &&
      other.ritualMode == ritualMode &&
      other.contributionRhythm == contributionRhythm;

  @override
  int get hashCode => Object.hash(
    explanationDepth,
    ritualVoice,
    riskFraming,
    ritualMode,
    contributionRhythm,
  );
}

@immutable
class MemberEntitlement {
  const MemberEntitlement({required this.planCode, required this.status});

  final String planCode;
  final MemberEntitlementStatus status;

  @override
  bool operator ==(Object other) =>
      other is MemberEntitlement &&
      other.planCode == planCode &&
      other.status == status;

  @override
  int get hashCode => Object.hash(planCode, status);
}

@immutable
class MemberOnboardingGate {
  const MemberOnboardingGate.complete({this.version = 0})
    : isComplete = true,
      nextStep = null;

  const MemberOnboardingGate.incomplete({
    required this.nextStep,
    this.version = 0,
  }) : isComplete = false;

  factory MemberOnboardingGate.fromServer({
    required String cohort,
    required String currentStep,
    required DateTime? completedAt,
    int version = 0,
  }) {
    if (completedAt != null ||
        currentStep == 'complete' ||
        cohort == 'legacy_complete_v1') {
      return MemberOnboardingGate.complete(version: version);
    }
    return MemberOnboardingGate.incomplete(
      nextStep: currentStep,
      version: version,
    );
  }

  final bool isComplete;
  final String? nextStep;
  final int version;

  @override
  bool operator ==(Object other) =>
      other is MemberOnboardingGate &&
      other.isComplete == isComplete &&
      other.nextStep == nextStep &&
      other.version == version;

  @override
  int get hashCode => Object.hash(isComplete, nextStep, version);
}

@immutable
class MemberBootstrap {
  const MemberBootstrap({
    required this.accountId,
    required this.onboarding,
    required this.serverTime,
    required this.contractVersion,
    required this.themePreference,
    this.brokerage = const BrokerageConnectionSnapshot.disconnected(),
    this.authorityEpoch = 0,
    this.resetGeneration = 0,
    this.entitlement = const MemberEntitlement(
      planCode: 'standalone-demo',
      status: MemberEntitlementStatus.active,
    ),
    this.defaultPortfolioId = 'standalone-demo-portfolio',
    this.personalization = const MemberPersonalization(),
  });

  final String accountId;
  final int authorityEpoch;
  final BrokerageConnectionSnapshot brokerage;

  /// Standalone Demo compatibility only. Production scope uses [authorityEpoch].
  @Deprecated('Standalone Demo compatibility only')
  final int resetGeneration;
  final MemberOnboardingGate onboarding;

  /// Standalone Demo compatibility only; not a production access gate.
  @Deprecated('Standalone Demo compatibility only')
  final MemberEntitlement entitlement;

  /// Standalone Demo compatibility only; Webull selection is in [brokerage].
  @Deprecated('Standalone Demo compatibility only')
  final String defaultPortfolioId;
  final DateTime serverTime;
  final String contractVersion;
  final MemberThemePreference themePreference;
  final MemberPersonalization personalization;

  bool get canEnterMemberShell => onboarding.isComplete;

  @override
  bool operator ==(Object other) =>
      other is MemberBootstrap &&
      other.accountId == accountId &&
      other.authorityEpoch == authorityEpoch &&
      other.brokerage == brokerage &&
      other.resetGeneration == resetGeneration &&
      other.onboarding == onboarding &&
      other.entitlement == entitlement &&
      other.defaultPortfolioId == defaultPortfolioId &&
      other.serverTime == serverTime &&
      other.contractVersion == contractVersion &&
      other.themePreference == themePreference &&
      other.personalization == personalization;

  @override
  int get hashCode => Object.hash(
    accountId,
    authorityEpoch,
    brokerage,
    resetGeneration,
    onboarding,
    entitlement,
    defaultPortfolioId,
    serverTime,
    contractVersion,
    themePreference,
    personalization,
  );
}
