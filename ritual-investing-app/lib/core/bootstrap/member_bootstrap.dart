import 'package:flutter/foundation.dart';

enum MemberThemePreference { system, light, dark }

enum MemberEntitlementStatus { active, unavailable }

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
  const MemberOnboardingGate.complete() : isComplete = true, nextStep = null;

  const MemberOnboardingGate.incomplete({required this.nextStep})
    : isComplete = false;

  factory MemberOnboardingGate.fromServer({
    required String cohort,
    required String currentStep,
    required DateTime? completedAt,
  }) {
    if (completedAt != null ||
        currentStep == 'complete' ||
        cohort == 'legacy_complete_v1') {
      return const MemberOnboardingGate.complete();
    }
    return MemberOnboardingGate.incomplete(nextStep: currentStep);
  }

  final bool isComplete;
  final String? nextStep;

  @override
  bool operator ==(Object other) =>
      other is MemberOnboardingGate &&
      other.isComplete == isComplete &&
      other.nextStep == nextStep;

  @override
  int get hashCode => Object.hash(isComplete, nextStep);
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
  });

  final String accountId;
  final int resetGeneration;
  final MemberOnboardingGate onboarding;
  final MemberEntitlement entitlement;
  final String defaultPortfolioId;
  final DateTime serverTime;
  final String contractVersion;
  final MemberThemePreference themePreference;

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
      other.themePreference == themePreference;

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
  );
}
