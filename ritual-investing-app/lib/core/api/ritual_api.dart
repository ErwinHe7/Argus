import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../bootstrap/member_bootstrap.dart';
import 'api_failure_mapper.dart';

export '../../features/coven/data/generated_coven_api_service.dart';
export '../../features/discover/data/generated_discover_api_service.dart';
export '../../features/future_mirror/data/generated_future_mirror_api_service.dart';
export '../../features/intentions/data/generated_intention_api_service.dart';
export '../../features/orders/data/generated_simulated_investing_api_service.dart';
export '../../features/portfolio/data/generated_portfolio_api_service.dart';
export '../../features/profile/data/generated_profile_api_service.dart';
export '../../features/ritual/data/generated_ritual_api_service.dart';
export 'api_failure_mapper.dart';

abstract interface class SessionBootstrapService {
  Future<MemberBootstrap> bootstrap();
}

class GeneratedSessionBootstrapService implements SessionBootstrapService {
  GeneratedSessionBootstrapService(RitualInvestingApiClient client)
    : _api = client.getSessionApi();

  final SessionApi _api;

  @override
  Future<MemberBootstrap> bootstrap() async {
    try {
      final response = await _api.bootstrapSession();
      final data = response.data!.data;
      if (data.contractVersion !=
          SessionBootstrapContractVersionEnum.n1period0Period0) {
        throw StateError('Unsupported API contract version.');
      }
      return mapSessionBootstrap(data);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }
}

MemberBootstrap mapSessionBootstrap(SessionBootstrap data) => MemberBootstrap(
  accountId: data.account.id,
  resetGeneration: data.resetGeneration,
  onboarding: MemberOnboardingGate.fromServer(
    cohort: data.onboarding.cohort.value,
    currentStep: data.onboarding.currentStep,
    completedAt: data.onboarding.completedAt,
    version: data.onboarding.version,
  ),
  entitlement: MemberEntitlement(
    planCode: data.entitlement.planCode,
    status: switch (data.entitlement.status) {
      SessionBootstrapEntitlementStatusEnum.active =>
        MemberEntitlementStatus.active,
      SessionBootstrapEntitlementStatusEnum.unknownDefaultOpenApi =>
        MemberEntitlementStatus.unavailable,
    },
  ),
  defaultPortfolioId: data.defaultPortfolio.id,
  serverTime: data.serverTime.toUtc(),
  contractVersion: data.contractVersion.value,
  themePreference: switch (data.preferences.themeMode) {
    SessionBootstrapPreferencesThemeModeEnum.light =>
      MemberThemePreference.light,
    SessionBootstrapPreferencesThemeModeEnum.dark => MemberThemePreference.dark,
    SessionBootstrapPreferencesThemeModeEnum.system ||
    SessionBootstrapPreferencesThemeModeEnum.unknownDefaultOpenApi =>
      MemberThemePreference.system,
  },
  personalization: MemberPersonalization(
    contributionRhythm: switch (data.investorProfile?.contributionRhythm) {
      SessionBootstrapInvestorProfileContributionRhythmEnum.weekly =>
        MemberContributionRhythm.weekly,
      SessionBootstrapInvestorProfileContributionRhythmEnum.biweekly =>
        MemberContributionRhythm.biweekly,
      SessionBootstrapInvestorProfileContributionRhythmEnum.monthly =>
        MemberContributionRhythm.monthly,
      SessionBootstrapInvestorProfileContributionRhythmEnum.irregular =>
        MemberContributionRhythm.irregular,
      SessionBootstrapInvestorProfileContributionRhythmEnum.notSure =>
        MemberContributionRhythm.notSure,
      SessionBootstrapInvestorProfileContributionRhythmEnum
          .unknownDefaultOpenApi ||
      null => MemberContributionRhythm.unavailable,
    },
    explanationDepth: switch (data.investorProfile?.experience) {
      SessionBootstrapInvestorProfileExperienceEnum.new_ =>
        MemberExplanationDepth.beginner,
      SessionBootstrapInvestorProfileExperienceEnum.someExperience =>
        MemberExplanationDepth.guided,
      SessionBootstrapInvestorProfileExperienceEnum.experienced =>
        MemberExplanationDepth.advanced,
      SessionBootstrapInvestorProfileExperienceEnum.unknownDefaultOpenApi ||
      null => MemberExplanationDepth.unavailable,
    },
    ritualVoice: switch (data.preferences.ritualLanguage) {
      SessionBootstrapPreferencesRitualLanguageEnum.practical =>
        MemberRitualVoice.practical,
      SessionBootstrapPreferencesRitualLanguageEnum.mystical =>
        MemberRitualVoice.mystical,
      SessionBootstrapPreferencesRitualLanguageEnum.balanced ||
      SessionBootstrapPreferencesRitualLanguageEnum.preferNotToSay =>
        MemberRitualVoice.balanced,
      SessionBootstrapPreferencesRitualLanguageEnum.unknownDefaultOpenApi ||
      null => MemberRitualVoice.unavailable,
    },
    riskFraming: switch (data.investorProfile?.riskComfort) {
      SessionBootstrapInvestorProfileRiskComfortEnum.low =>
        MemberRiskFraming.low,
      SessionBootstrapInvestorProfileRiskComfortEnum.moderate =>
        MemberRiskFraming.moderate,
      SessionBootstrapInvestorProfileRiskComfortEnum.high =>
        MemberRiskFraming.high,
      SessionBootstrapInvestorProfileRiskComfortEnum.unknownDefaultOpenApi ||
      null => MemberRiskFraming.unavailable,
    },
    ritualMode: switch (data.preferences.ritualMode) {
      SessionBootstrapPreferencesRitualModeEnum.tarot => MemberRitualMode.tarot,
      SessionBootstrapPreferencesRitualModeEnum.astrology =>
        MemberRitualMode.astrology,
      SessionBootstrapPreferencesRitualModeEnum.unknownDefaultOpenApi =>
        MemberRitualMode.unavailable,
    },
  ),
);
