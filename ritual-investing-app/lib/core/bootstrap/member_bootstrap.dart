import 'package:flutter/foundation.dart';

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
  int get hashCode =>
      Object.hash(
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
    required this.resetGeneration,
    required this.onboarding,
    required this.entitlement,
    required this.defaultPortfolioId,
    required this.serverTime,
    required this.contractVersion,
    required this.themePreference,
    this.personalization = const MemberPersonalization(),
  });

  final String accountId;
  final int resetGeneration;
  final MemberOnboardingGate onboarding;
  final MemberEntitlement entitlement;
  final String defaultPortfolioId;
  final DateTime serverTime;
  final String contractVersion;
  final MemberThemePreference themePreference;
  final MemberPersonalization personalization;

  bool get canEnterMemberShell =>
      onboarding.isComplete &&
      entitlement.status == MemberEntitlementStatus.active;

  @override
  bool operator ==(Object other) =>
      other is MemberBootstrap &&
      other.accountId == accountId &&
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
