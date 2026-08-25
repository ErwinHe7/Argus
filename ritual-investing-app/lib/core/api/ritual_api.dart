import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../features/coven/data/repository.dart';
import '../../features/coven/domain/model.dart';
import '../../features/discover/data/repository.dart';
import '../../features/discover/domain/model.dart';
import '../../features/onboarding/domain/onboarding_draft.dart' as onboarding;
import '../../features/profile/data/repository.dart';
import '../../features/profile/domain/model.dart';
import '../../features/portfolio/data/repository.dart';
import '../../features/portfolio/domain/model.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/ritual/domain/daily_ritual.dart';
import '../bootstrap/member_bootstrap.dart';
import 'date_only_request_interceptor.dart';
import 'view_state.dart';

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
      _throwApiFailure(error);
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
);

class GeneratedRitualApiService implements DailyRitualService {
  GeneratedRitualApiService(RitualInvestingApiClient client)
    : _api = RitualsApi(client.dio);
  final RitualsApi _api;
  @override
  Future<DailyRitual> fetchDaily() async {
    try {
      final data = (await _api.getDailyRitual()).data!.data;
      return DailyRitual(
        assignmentId: data.assignmentId,
        date: data.date,
        mode: switch (data.mode) {
          DailyRitualDetailModeEnum.tarot => DailyRitualMode.tarot,
          DailyRitualDetailModeEnum.astrology => DailyRitualMode.astrology,
          DailyRitualDetailModeEnum.unknownDefaultOpenApi =>
            DailyRitualMode.unknown,
        },
        revision: RitualRevision(
          id: data.revision.id,
          number: data.revision.number,
        ),
        title: data.title,
        art: RitualArt(key: data.art.key.value, alt: data.art.alt),
        interpretation: data.interpretation,
        guidance: data.guidance,
        marketLabel: data.marketLabel,
        ideas: data.ideas
            .map(
              (idea) => RitualIdea(
                assetId: idea.assetId,
                symbol: idea.symbol,
                name: idea.name,
                appearanceReason: idea.appearanceReason,
                riskSummary: idea.riskSummary,
              ),
            )
            .toList(growable: false),
        evidence: data.evidence
            .map(
              (evidence) => RitualEvidence(
                claimId: evidence.claimId,
                factorLabel: evidence.factorLabel,
                observedAt: evidence.observedAt,
                summary: evidence.summary,
                uncertainty: evidence.uncertainty,
              ),
            )
            .toList(growable: false),
        rowan: RitualCounsel(
          scriptRevisionId: data.rowan.scriptRevisionId,
          surface: data.rowan.surface.value,
          body: data.rowan.body,
          riskFooter: data.rowan.riskFooter,
        ),
        version: data.version,
        state: switch (data.state) {
          DailyRitualDetailStateEnum.assigned => DailyRitualState.assigned,
          DailyRitualDetailStateEnum.revealed => DailyRitualState.revealed,
          DailyRitualDetailStateEnum.completed => DailyRitualState.completed,
          DailyRitualDetailStateEnum.unknownDefaultOpenApi =>
            DailyRitualState.unknown,
        },
        revealedAt: data.revealedAt,
        completedAt: data.completedAt,
        demo: RitualDisclosure(
          isDemo: data.demo.isDemo,
          observedAt: data.demo.observedAt,
          sourceLabel: data.demo.sourceLabel,
          limitations: data.demo.limitations,
        ),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

class GeneratedDiscoverApiService implements DiscoverService {
  GeneratedDiscoverApiService(RitualInvestingApiClient client)
    : _api = DiscoverApi(client.dio);
  final DiscoverApi _api;
  @override
  Future<DiscoverModel> fetch() async {
    try {
      final grimoiresRequest = _api.listGrimoires(limit: 3);
      final circlesRequest = _api.listCircleTemplates(limit: 2);
      final responses = await Future.wait<Object>([
        grimoiresRequest,
        circlesRequest,
      ]);
      final grimoires =
          (responses[0] as Response<GrimoireCollectionResponse>).data!;
      final circles =
          (responses[1] as Response<CircleTemplateCollectionResponse>).data!;
      return DiscoverModel(
        grimoires: grimoires.data
            .map(
              (item) =>
                  DiscoverCard(title: item.title, subtitle: item.description),
            )
            .toList(),
        circles: circles.data
            .map(
              (item) =>
                  DiscoverCard(title: item.title, subtitle: item.description),
            )
            .toList(),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

class GeneratedCovenApiService implements CovenService {
  GeneratedCovenApiService(RitualInvestingApiClient client)
    : _api = FoundersCovenApi(client.dio);
  final FoundersCovenApi _api;
  @override
  Future<CovenModel> fetch() async {
    try {
      final values = (await _api.listCoven(limit: 4)).data!.data;
      return CovenModel(
        entries: values
            .map(
              (item) => CovenEntry(
                name: item.company,
                symbol: item.symbol,
                category: switch (item.category) {
                  CovenSummaryCategoryEnum.founder => 'Woman founder',
                  CovenSummaryCategoryEnum.owner => 'Women-owned',
                  CovenSummaryCategoryEnum.chiefExecutive =>
                    'Woman chief executive',
                  CovenSummaryCategoryEnum.unknownDefaultOpenApi =>
                    'Verified qualification',
                },
                focus: item.focus,
                effectiveDate: item.effectiveDate,
                verifiedAsOf: item.verifiedAsOf,
              ),
            )
            .toList(),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

class GeneratedProfileApiService implements ProfileService {
  GeneratedProfileApiService(RitualInvestingApiClient client)
    : _api = AccountApi(client.dio) {
    ensureDateOnlyRequestSerialization(client.dio);
  }

  final AccountApi _api;

  @override
  Future<ProfileModel> fetch() async {
    try {
      final accountRequest = _api.getMe();
      final preferencesRequest = _api.getPreferences();
      final investorRequest = _optionalResource(
        () async => (await _api.getInvestorProfile()).data!.data,
      );
      final astrologyRequest = _optionalResource(
        () async => (await _api.getAstrologyProfile()).data!.data,
      );
      final responses = await Future.wait<Object?>([
        accountRequest,
        preferencesRequest,
        investorRequest,
        astrologyRequest,
      ]);
      final account =
          (responses[0] as Response<MemberAccountResponse>).data!.data;
      final preferences =
          (responses[1] as Response<MemberPreferencesResponse>).data!.data;
      final investor = responses[2] as InvestorProfile?;
      final astrology = responses[3] as AstrologyProfile?;
      if (account.account.status.value != 'active') {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      return ProfileModel(
        displayName: account.profile.displayName,
        profileVersion: account.profile.version,
        preferences: _mapPreferences(preferences),
        investor: investor == null ? null : _mapInvestor(investor),
        astrology: astrology == null ? null : _mapAstrology(astrology),
        astrologyDecision: astrology == null
            ? ProfileConsentDecision.unknown
            : ProfileConsentDecision.accepted,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<void> patchPreferences(ProfilePreferencesUpdate update) async {
    try {
      await _api.patchPreferences(
        ifMatch: update.expectedVersion.toString(),
        patchPreferencesRequest: PatchPreferencesRequest(
          ritualFamiliarity: _requestFamiliarity(update.ritualFamiliarity),
          ritualInterests: update.ritualInterests
              ?.map(_requestInterest)
              .toList(growable: false),
          ritualLanguage: _requestLanguage(update.ritualLanguage),
          ritualMode: _requestRitualMode(update.ritualMode),
          themeMode: _requestTheme(update.theme),
        ),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<void> putInvestor(ProfileInvestorUpdate update) async {
    try {
      await _api.putInvestorProfile(
        ifMatch: update.expectedVersion?.toString(),
        putInvestorProfileRequest: PutInvestorProfileRequest(
          contributionRhythm: _requestContribution(update.contributionRhythm),
          goalType: _requestGoal(update.goal),
          investingExperience: _requestExperience(update.experience),
          riskComfort: _requestRisk(update.risk),
          timeHorizon: _requestHorizon(update.horizon),
        ),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<ProfileConsentReceipt> putAstrology(
    ProfileAstrologyUpdate update,
  ) async {
    try {
      final receipt = await _writeAstrologyConsent(
        CreateConsentRequestDecisionEnum.accepted,
      );
      await _api.putAstrologyProfile(
        ifMatch: update.expectedVersion?.toString(),
        putAstrologyProfileRequest: PutAstrologyProfileRequest(
          birthDate: update.birthDate.toUtc(),
        ),
      );
      return receipt;
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<ProfileConsentReceipt> deleteAstrology({
    required int expectedVersion,
  }) async {
    try {
      await _api.deleteAstrologyProfile(ifMatch: expectedVersion.toString());
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) _throwApiFailure(error);
    }
    try {
      return await _writeAstrologyConsent(
        CreateConsentRequestDecisionEnum.withdrawn,
      );
    } on DioException catch (error) {
      throw AstrologyDeletionPartialFailure(_failurePhase(error));
    } on LoadFailure catch (failure) {
      throw AstrologyDeletionPartialFailure(failure.phase);
    } on Object {
      throw const AstrologyDeletionPartialFailure(LoadPhase.terminalFailure);
    }
  }

  Future<ProfileConsentReceipt> _writeAstrologyConsent(
    CreateConsentRequestDecisionEnum decision,
  ) async {
    final receipt = (await _api.createConsent(
      createConsentRequest: CreateConsentRequest(
        decision: decision,
        policyCode: CreateConsentRequestPolicyCodeEnum.astrology,
        policyVersion: '2026-08',
      ),
    )).data!.data;
    if (receipt.policyCode.value != 'astrology') {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    return ProfileConsentReceipt(
      id: receipt.id,
      decision: _consentDecision(receipt.decision.value),
      policyVersion: receipt.policyVersion,
      recordedAt: receipt.recordedAt.toUtc(),
    );
  }
}

LoadPhase _failurePhase(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return LoadPhase.retryableFailure;
  }
  return ApiFailureMapper.map(error).phase;
}

Future<T?> _optionalResource<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (error) {
    if (error.response?.statusCode == 404) return null;
    rethrow;
  }
}

SavedRitualPreferences _mapPreferences(MemberPreferences value) =>
    SavedRitualPreferences(
      locale: value.locale,
      timezone: value.timezone,
      ritualFamiliarity: value.ritualFamiliarity == null
          ? null
          : _ritualFamiliarity(value.ritualFamiliarity!.value),
      ritualLanguage: value.ritualLanguage == null
          ? null
          : _ritualLanguage(value.ritualLanguage!.value),
      ritualInterests:
          value.ritualInterests
              ?.map((interest) => _ritualInterest(interest.value))
              .toSet() ??
          const {},
      ritualMode: switch (value.ritualMode.value) {
        'tarot' => ProfileRitualMode.tarot,
        'astrology' => ProfileRitualMode.astrology,
        _ => throw const LoadFailure(LoadPhase.terminalFailure),
      },
      theme: switch (value.themeMode.value) {
        'system' => ProfileTheme.system,
        'light' => ProfileTheme.light,
        'dark' => ProfileTheme.dark,
        _ => throw const LoadFailure(LoadPhase.terminalFailure),
      },
      version: value.version,
    );

SavedInvestorProfile _mapInvestor(InvestorProfile value) =>
    SavedInvestorProfile(
      experience: value.investingExperience == null
          ? null
          : _investingExperience(value.investingExperience!.value),
      goal: _investmentGoal(value.goalType.value),
      horizon: _investmentHorizon(value.timeHorizon.value),
      risk: _riskComfort(value.riskComfort.value),
      contributionRhythm: value.contributionRhythm == null
          ? null
          : _contributionRhythm(value.contributionRhythm!.value),
      isDemo: value.isDemo,
      version: value.version,
    );

SavedAstrologyProfile _mapAstrology(AstrologyProfile value) {
  if (value.algorithmVersion.value == 'unknown_default_open_api' ||
      value.derivedProfileCode.value == 'unknown_default_open_api' ||
      value.birthDate.hour != 0 ||
      value.birthDate.minute != 0 ||
      value.birthDate.second != 0 ||
      value.birthDate.millisecond != 0 ||
      value.birthDate.microsecond != 0) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  final birthDate = ProfileDate(
    value.birthDate.year,
    value.birthDate.month,
    value.birthDate.day,
  );
  birthDate.toUtc();
  return SavedAstrologyProfile(
    birthDate: birthDate,
    serverDerivedProfile: value.derivedProfileCode.value,
    algorithmVersion: value.algorithmVersion.value,
    version: value.version,
  );
}

onboarding.InvestingExperience _investingExperience(String value) =>
    switch (value) {
      'new' => onboarding.InvestingExperience.newToInvesting,
      'some_experience' => onboarding.InvestingExperience.someExperience,
      'experienced' => onboarding.InvestingExperience.experienced,
      _ => throw const LoadFailure(LoadPhase.terminalFailure),
    };

onboarding.InvestmentGoal _investmentGoal(String value) => switch (value) {
  'calm_fund' => onboarding.InvestmentGoal.calmFund,
  'long_term_growth' => onboarding.InvestmentGoal.longTermGrowth,
  'income' => onboarding.InvestmentGoal.income,
  'exploration' => onboarding.InvestmentGoal.exploration,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

onboarding.InvestmentHorizon _investmentHorizon(String value) =>
    switch (value) {
      'short' => onboarding.InvestmentHorizon.short,
      'medium' => onboarding.InvestmentHorizon.medium,
      'long' => onboarding.InvestmentHorizon.long,
      _ => throw const LoadFailure(LoadPhase.terminalFailure),
    };

onboarding.RiskComfort _riskComfort(String value) => switch (value) {
  'low' => onboarding.RiskComfort.low,
  'moderate' => onboarding.RiskComfort.moderate,
  'high' => onboarding.RiskComfort.high,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

onboarding.ContributionRhythm _contributionRhythm(String value) =>
    switch (value) {
      'weekly' => onboarding.ContributionRhythm.weekly,
      'biweekly' => onboarding.ContributionRhythm.biweekly,
      'monthly' => onboarding.ContributionRhythm.monthly,
      'irregular' => onboarding.ContributionRhythm.irregular,
      'not_sure' => onboarding.ContributionRhythm.notSure,
      _ => throw const LoadFailure(LoadPhase.terminalFailure),
    };

onboarding.RitualFamiliarity _ritualFamiliarity(String value) =>
    switch (value) {
      'new' => onboarding.RitualFamiliarity.newToRitual,
      'curious' => onboarding.RitualFamiliarity.curious,
      'familiar' => onboarding.RitualFamiliarity.familiar,
      'practiced' => onboarding.RitualFamiliarity.practiced,
      'prefer_not_to_say' => onboarding.RitualFamiliarity.preferNotToSay,
      _ => throw const LoadFailure(LoadPhase.terminalFailure),
    };

onboarding.RitualLanguage _ritualLanguage(String value) => switch (value) {
  'practical' => onboarding.RitualLanguage.practical,
  'balanced' => onboarding.RitualLanguage.balanced,
  'mystical' => onboarding.RitualLanguage.mystical,
  'prefer_not_to_say' => onboarding.RitualLanguage.preferNotToSay,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

onboarding.RitualInterest _ritualInterest(String value) => switch (value) {
  'practical_research' => onboarding.RitualInterest.practicalResearch,
  'tarot' => onboarding.RitualInterest.tarot,
  'astrology' => onboarding.RitualInterest.astrology,
  'moon_cycles' => onboarding.RitualInterest.moonCycles,
  'reflection' => onboarding.RitualInterest.reflection,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

ProfileConsentDecision _consentDecision(String value) => switch (value) {
  'accepted' => ProfileConsentDecision.accepted,
  'declined' => ProfileConsentDecision.declined,
  'withdrawn' => ProfileConsentDecision.withdrawn,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

PatchPreferencesRequestRitualFamiliarityEnum? _requestFamiliarity(
  onboarding.RitualFamiliarity? value,
) => switch (value) {
  onboarding.RitualFamiliarity.newToRitual =>
    PatchPreferencesRequestRitualFamiliarityEnum.new_,
  onboarding.RitualFamiliarity.curious =>
    PatchPreferencesRequestRitualFamiliarityEnum.curious,
  onboarding.RitualFamiliarity.familiar =>
    PatchPreferencesRequestRitualFamiliarityEnum.familiar,
  onboarding.RitualFamiliarity.practiced =>
    PatchPreferencesRequestRitualFamiliarityEnum.practiced,
  onboarding.RitualFamiliarity.preferNotToSay =>
    PatchPreferencesRequestRitualFamiliarityEnum.preferNotToSay,
  null => null,
};

RitualInterest _requestInterest(onboarding.RitualInterest value) =>
    switch (value) {
      onboarding.RitualInterest.practicalResearch =>
        RitualInterest.practicalResearch,
      onboarding.RitualInterest.tarot => RitualInterest.tarot,
      onboarding.RitualInterest.astrology => RitualInterest.astrology,
      onboarding.RitualInterest.moonCycles => RitualInterest.moonCycles,
      onboarding.RitualInterest.reflection => RitualInterest.reflection,
    };

PatchPreferencesRequestRitualLanguageEnum? _requestLanguage(
  onboarding.RitualLanguage? value,
) => switch (value) {
  onboarding.RitualLanguage.practical =>
    PatchPreferencesRequestRitualLanguageEnum.practical,
  onboarding.RitualLanguage.balanced =>
    PatchPreferencesRequestRitualLanguageEnum.balanced,
  onboarding.RitualLanguage.mystical =>
    PatchPreferencesRequestRitualLanguageEnum.mystical,
  onboarding.RitualLanguage.preferNotToSay =>
    PatchPreferencesRequestRitualLanguageEnum.preferNotToSay,
  null => null,
};

PatchPreferencesRequestRitualModeEnum? _requestRitualMode(
  ProfileRitualMode? value,
) => switch (value) {
  ProfileRitualMode.tarot => PatchPreferencesRequestRitualModeEnum.tarot,
  ProfileRitualMode.astrology =>
    PatchPreferencesRequestRitualModeEnum.astrology,
  null => null,
};

PatchPreferencesRequestThemeModeEnum? _requestTheme(ProfileTheme? value) =>
    switch (value) {
      ProfileTheme.system => PatchPreferencesRequestThemeModeEnum.system,
      ProfileTheme.light => PatchPreferencesRequestThemeModeEnum.light,
      ProfileTheme.dark => PatchPreferencesRequestThemeModeEnum.dark,
      null => null,
    };

PutInvestorProfileRequestContributionRhythmEnum? _requestContribution(
  onboarding.ContributionRhythm? value,
) => switch (value) {
  onboarding.ContributionRhythm.weekly =>
    PutInvestorProfileRequestContributionRhythmEnum.weekly,
  onboarding.ContributionRhythm.biweekly =>
    PutInvestorProfileRequestContributionRhythmEnum.biweekly,
  onboarding.ContributionRhythm.monthly =>
    PutInvestorProfileRequestContributionRhythmEnum.monthly,
  onboarding.ContributionRhythm.irregular =>
    PutInvestorProfileRequestContributionRhythmEnum.irregular,
  onboarding.ContributionRhythm.notSure =>
    PutInvestorProfileRequestContributionRhythmEnum.notSure,
  null => null,
};

PutInvestorProfileRequestGoalTypeEnum _requestGoal(
  onboarding.InvestmentGoal value,
) => switch (value) {
  onboarding.InvestmentGoal.calmFund =>
    PutInvestorProfileRequestGoalTypeEnum.calmFund,
  onboarding.InvestmentGoal.longTermGrowth =>
    PutInvestorProfileRequestGoalTypeEnum.longTermGrowth,
  onboarding.InvestmentGoal.income =>
    PutInvestorProfileRequestGoalTypeEnum.income,
  onboarding.InvestmentGoal.exploration =>
    PutInvestorProfileRequestGoalTypeEnum.exploration,
};

PutInvestorProfileRequestInvestingExperienceEnum? _requestExperience(
  onboarding.InvestingExperience? value,
) => switch (value) {
  onboarding.InvestingExperience.newToInvesting =>
    PutInvestorProfileRequestInvestingExperienceEnum.new_,
  onboarding.InvestingExperience.someExperience =>
    PutInvestorProfileRequestInvestingExperienceEnum.someExperience,
  onboarding.InvestingExperience.experienced =>
    PutInvestorProfileRequestInvestingExperienceEnum.experienced,
  null => null,
};

PutInvestorProfileRequestRiskComfortEnum _requestRisk(
  onboarding.RiskComfort value,
) => switch (value) {
  onboarding.RiskComfort.low => PutInvestorProfileRequestRiskComfortEnum.low,
  onboarding.RiskComfort.moderate =>
    PutInvestorProfileRequestRiskComfortEnum.moderate,
  onboarding.RiskComfort.high => PutInvestorProfileRequestRiskComfortEnum.high,
};

PutInvestorProfileRequestTimeHorizonEnum _requestHorizon(
  onboarding.InvestmentHorizon value,
) => switch (value) {
  onboarding.InvestmentHorizon.short =>
    PutInvestorProfileRequestTimeHorizonEnum.short,
  onboarding.InvestmentHorizon.medium =>
    PutInvestorProfileRequestTimeHorizonEnum.medium,
  onboarding.InvestmentHorizon.long =>
    PutInvestorProfileRequestTimeHorizonEnum.long,
};

class GeneratedPortfolioApiService implements PortfolioService {
  GeneratedPortfolioApiService(RitualInvestingApiClient client)
    : _portfolios = PortfoliosApi(client.dio),
      _simulation = SimulationApi(client.dio);

  final PortfoliosApi _portfolios;
  final SimulationApi _simulation;

  @override
  Future<PortfolioCollection> fetch() async {
    try {
      final values = (await _portfolios.listPortfolios()).data!.data;
      return PortfolioCollection(
        items: values
            .map(
              (item) => PortfolioSummary(
                id: item.id,
                name: item.name,
                cashMinor: item.cash.minorUnits,
                valuationMinor: item.latestValuation.minorUnits,
                version: item.version,
                ledgerWatermark: item.ledgerWatermark,
              ),
            )
            .toList(growable: false),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<ContributionReceipt> contribute({
    required String portfolioId,
    required String sourceId,
    required int minorUnits,
    required String idempotencyKey,
  }) async {
    try {
      final result = (await _simulation.createDemoContribution(
        portfolioId: portfolioId,
        idempotencyKey: idempotencyKey,
        createDemoContributionRequest: CreateDemoContributionRequest(
          amount: PositiveInputMoney(
            currency: PositiveInputMoneyCurrencyEnum.USD,
            minorUnits: minorUnits,
          ),
          sourceId: sourceId,
        ),
      )).data!.data;
      return ContributionReceipt(
        commandId: result.commandId,
        portfolioVersion: result.portfolioVersion,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

Never _throwApiFailure(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    throw const OfflineException();
  }
  throw ApiFailureMapper.map(error);
}

class ApiFailureMapper {
  const ApiFailureMapper._();

  static LoadFailure map(DioException error) {
    final code = _errorCode(error.response?.data);
    if (code != null) {
      return LoadFailure(switch (code) {
        'forbidden' || 'insufficient_scope' => LoadPhase.forbidden,
        'not_found' || 'resource_not_found' => LoadPhase.empty,
        'conflict' ||
        'version_conflict' ||
        'idempotency_conflict' => LoadPhase.conflict,
        'rate_limited' || 'throttled' => LoadPhase.throttled,
        'temporarily_unavailable' ||
        'service_unavailable' => LoadPhase.retryableFailure,
        _ => LoadPhase.terminalFailure,
      });
    }
    return LoadFailure(switch (error.response?.statusCode) {
      403 => LoadPhase.forbidden,
      404 => LoadPhase.empty,
      409 => LoadPhase.conflict,
      429 => LoadPhase.throttled,
      final status when status != null && status >= 500 =>
        LoadPhase.retryableFailure,
      _ => LoadPhase.terminalFailure,
    });
  }

  static String? _errorCode(Object? data) {
    if (data is! Map) return null;
    final envelope = data['error'];
    if (envelope is! Map) return null;
    final code = envelope['code'];
    return code is String ? code : null;
  }
}
