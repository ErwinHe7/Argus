import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../features/coven/data/repository.dart';
import '../../features/coven/domain/model.dart' as coven_domain;
import '../../features/discover/data/repository.dart';
import '../../features/discover/domain/model.dart';
import '../../features/funding/data/repository.dart';
import '../../features/funding/domain/model.dart';
import '../../features/onboarding/domain/onboarding_draft.dart' as onboarding;
import '../../features/orders/data/repository.dart';
import '../../features/orders/domain/model.dart' as order_domain;
import '../../features/profile/data/repository.dart';
import '../../features/profile/domain/model.dart';
import '../../features/portfolio/data/repository.dart';
import '../../features/portfolio/domain/model.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/ritual/domain/daily_ritual.dart';
import '../../features/recurring/data/repository.dart';
import '../../features/recurring/domain/model.dart' as recurring_domain;
import '../../features/rebalancing/data/repository.dart';
import '../../features/rebalancing/domain/model.dart' as rebalance_domain;
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

class GeneratedRitualApiService implements DailyRitualService {
  GeneratedRitualApiService(RitualInvestingApiClient client)
    : _api = RitualsApi(client.dio);
  final RitualsApi _api;
  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async {
    try {
      final modeValue = switch (mode) {
        null => null,
        DailyRitualMode.tarot => 'tarot',
        DailyRitualMode.astrology => 'astrology',
        DailyRitualMode.unknown => throw const LoadFailure(
          LoadPhase.terminalFailure,
        ),
      };
      final data = (await _api.getDailyRitual(mode: modeValue)).data!.data;
      return _mapDailyRitual(data);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async {
    try {
      return _mapDailyRitual(
        (await _api.getRitualAssignment(assignmentId: assignmentId)).data!.data,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async {
    try {
      final values = (await _api.getRitualEvidence(assignmentId: assignmentId))
          .data!
          .data;
      return values
          .map(
            (value) => RitualEvidenceDetail(
              claimId: value.claimId,
              factorLabel: value.factorLabel,
              observedAt: value.observedAt,
              summary: value.summary,
              uncertainty: value.uncertainty,
              source: RitualEvidenceSource(
                publisher: value.source_.publisher,
                title: value.source_.title,
                url: Uri.parse(value.source_.url),
                publishedAt: value.source_.publishedAt,
              ),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      _throwApiFailure(error);
    } on FormatException {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async {
    try {
      final response = (await _api.listRitualHistory(cursor: cursor)).data!;
      return RitualHistoryPage(
        items: response.data
            .map((value) {
              final mode = switch (value.mode) {
                RitualHistoryItemModeEnum.tarot => DailyRitualMode.tarot,
                RitualHistoryItemModeEnum.astrology =>
                  DailyRitualMode.astrology,
                RitualHistoryItemModeEnum.unknownDefaultOpenApi =>
                  throw const LoadFailure(LoadPhase.terminalFailure),
              };
              final state = switch (value.state) {
                RitualHistoryItemStateEnum.assigned =>
                  DailyRitualState.assigned,
                RitualHistoryItemStateEnum.revealed =>
                  DailyRitualState.revealed,
                RitualHistoryItemStateEnum.completed =>
                  DailyRitualState.completed,
                RitualHistoryItemStateEnum.unknownDefaultOpenApi =>
                  throw const LoadFailure(LoadPhase.terminalFailure),
              };
              return RitualHistoryEntry(
                assignmentId: value.assignmentId,
                date: value.date,
                mode: mode,
                title: value.title,
                state: state,
                demo: _mapRitualDisclosure(value.demo),
              );
            })
            .toList(growable: false),
        nextCursor: response.meta.nextCursor,
        hasMore: response.meta.hasMore,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) => _transition(
    () => _api.revealRitual(assignmentId: assignmentId, ifMatch: '"v$version"'),
  );

  @override
  Future<DailyRitual> complete(String assignmentId, int version) => _transition(
    () =>
        _api.completeRitual(assignmentId: assignmentId, ifMatch: '"v$version"'),
  );

  Future<DailyRitual> _transition(
    Future<Response<GetRitualAssignment200Response>> Function() request,
  ) async {
    try {
      return _mapDailyRitual((await request()).data!.data);
    } on DioException catch (error) {
      if (_isAmbiguousTransport(error)) throw const RitualAmbiguousMutation();
      _throwApiFailure(error);
    }
  }

  DailyRitual _mapDailyRitual(DailyRitualDetail data) {
    final mode = switch (data.mode) {
      DailyRitualDetailModeEnum.tarot => DailyRitualMode.tarot,
      DailyRitualDetailModeEnum.astrology => DailyRitualMode.astrology,
      DailyRitualDetailModeEnum.unknownDefaultOpenApi =>
        throw const LoadFailure(LoadPhase.terminalFailure),
    };
    final state = switch (data.state) {
      DailyRitualDetailStateEnum.assigned => DailyRitualState.assigned,
      DailyRitualDetailStateEnum.revealed => DailyRitualState.revealed,
      DailyRitualDetailStateEnum.completed => DailyRitualState.completed,
      DailyRitualDetailStateEnum.unknownDefaultOpenApi =>
        throw const LoadFailure(LoadPhase.terminalFailure),
    };
    if (data.rowan.surface == RowanCounselSurfaceEnum.unknownDefaultOpenApi ||
        data.art.key == ArtReferenceKeyEnum.unknownDefaultOpenApi) {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    return DailyRitual(
      assignmentId: data.assignmentId,
      date: data.date,
      mode: mode,
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
      state: state,
      revealedAt: data.revealedAt,
      completedAt: data.completedAt,
      demo: _mapRitualDisclosure(data.demo),
    );
  }
}

RitualDisclosure _mapRitualDisclosure(DemoDisclosure value) => RitualDisclosure(
  isDemo: value.isDemo,
  observedAt: value.observedAt,
  sourceLabel: value.sourceLabel,
  limitations: value.limitations,
);

bool _isAmbiguousTransport(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;

class GeneratedDiscoverApiService implements DiscoverService {
  GeneratedDiscoverApiService(RitualInvestingApiClient client)
    : _api = DiscoverApi(client.dio);
  final DiscoverApi _api;
  @override
  Future<DiscoverModel> fetch() async {
    try {
      final discoverRequest = _api.listDiscover(limit: 20);
      final creatorsRequest = _api.listSeededCreators(limit: 8);
      final responses = await Future.wait<Object>([
        discoverRequest,
        creatorsRequest,
      ]);
      final discover = (responses[0] as Response<DiscoverResponse>).data!;
      final creators =
          (responses[1] as Response<CreatorCollectionResponse>).data!;
      return DiscoverModel(
        items: discover.data.map(_mapDiscoverItem).toList(growable: false),
        creators: creators.data.map(_mapSeededCreator).toList(growable: false),
        nextCursor: discover.meta.nextCursor,
        hasMore: discover.meta.hasMore,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }
}

DiscoverItemView _mapDiscoverItem(DiscoverItem item) => switch (item.kind) {
  DiscoverItemKindEnum.asset => () {
    final value = item.asset;
    if (value == null ||
        value.assetType == AssetSummaryAssetTypeEnum.unknownDefaultOpenApi ||
        value.currency == AssetSummaryCurrencyEnum.unknownDefaultOpenApi) {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    return DiscoverItemView(
      id: value.id,
      revisionId: value.revisionId,
      slug: value.slug,
      kind: DiscoverItemKind.asset,
      title: value.name,
      subtitle: value.appearanceReason,
      symbol: value.symbol,
      appearanceReason: value.appearanceReason,
      demo: _mapResearchDemo(value.demo),
    );
  }(),
  DiscoverItemKindEnum.grimoire => () {
    final value = item.grimoire;
    if (value == null) throw const LoadFailure(LoadPhase.terminalFailure);
    return DiscoverItemView(
      id: value.id,
      revisionId: value.revisionId,
      slug: value.slug,
      kind: DiscoverItemKind.grimoire,
      title: value.title,
      subtitle: value.description,
      theme: value.theme,
      demo: _mapResearchDemo(value.demo),
    );
  }(),
  DiscoverItemKindEnum.circleTemplate => () {
    final value = item.circleTemplate;
    if (value == null) throw const LoadFailure(LoadPhase.terminalFailure);
    return DiscoverItemView(
      id: value.id,
      revisionId: value.revisionId,
      slug: value.slug,
      kind: DiscoverItemKind.circleTemplate,
      title: value.title,
      subtitle: value.description,
      theme: value.theme,
      creator: _mapSeededCreator(value.creator),
      demo: _mapResearchDemo(value.demo),
    );
  }(),
  DiscoverItemKindEnum.coven => () {
    final value = item.coven;
    if (value == null) throw const LoadFailure(LoadPhase.terminalFailure);
    return DiscoverItemView(
      id: value.id,
      revisionId: value.revisionId,
      slug: value.slug,
      kind: DiscoverItemKind.coven,
      title: value.company,
      subtitle: '${_covenCategory(value.category)} · ${value.teaser}',
      symbol: value.symbol,
      demo: _mapResearchDemo(value.demo),
    );
  }(),
  DiscoverItemKindEnum.unknownDefaultOpenApi => throw const LoadFailure(
    LoadPhase.terminalFailure,
  ),
};

SeededCreatorView _mapSeededCreator(SeededCreator value) {
  if (!value.isFictional) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return SeededCreatorView(
    id: value.id,
    slug: value.slug,
    displayName: value.displayName,
    bio: value.bio,
    isFictional: true,
    demo: _mapResearchDemo(value.demo),
  );
}

ResearchDemoDisclosure _mapResearchDemo(DemoDisclosure value) =>
    ResearchDemoDisclosure(
      isDemo: value.isDemo,
      observedAt: value.observedAt,
      sourceLabel: value.sourceLabel,
      limitations: value.limitations,
    );

String _covenCategory(CovenSummaryCategoryEnum category) => switch (category) {
  CovenSummaryCategoryEnum.founder => 'Woman founder',
  CovenSummaryCategoryEnum.owner => 'Women-owned',
  CovenSummaryCategoryEnum.chiefExecutive => 'Woman chief executive',
  CovenSummaryCategoryEnum.unknownDefaultOpenApi => throw const LoadFailure(
    LoadPhase.terminalFailure,
  ),
};

class GeneratedCovenApiService implements CovenService {
  GeneratedCovenApiService(RitualInvestingApiClient client)
    : _api = FoundersCovenApi(client.dio),
      _saves = SavesApi(client.dio);
  final FoundersCovenApi _api;
  final SavesApi _saves;
  @override
  Future<coven_domain.CovenModel> fetch() async {
    try {
      final values = (await _api.listCoven(limit: 4)).data!.data;
      return coven_domain.CovenModel(
        entries: values
            .map(
              (item) => coven_domain.CovenEntry(
                id: item.id,
                revisionId: item.revisionId,
                slug: item.slug,
                name: item.company,
                symbol: item.symbol,
                category: _covenQualificationCategory(item.category),
                focus: item.focus,
                teaser: item.teaser,
                effectiveDate: item.effectiveDate,
                verifiedAsOf: item.verifiedAsOf,
                demo: _mapCovenDemo(item.demo),
              ),
            )
            .toList(growable: false),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<coven_domain.CovenDetail> fetchDetail(String entryId) async {
    try {
      final value = (await _api.getCovenEntry(entryId: entryId)).data!.data;
      return coven_domain.CovenDetail(
        id: value.id,
        revisionId: value.revisionId,
        slug: value.slug,
        company: value.company,
        symbol: value.symbol,
        focus: value.focus,
        summary: value.summary,
        inclusionRationale: value.inclusionRationale,
        limitations: value.limitations,
        qualifications: value.qualifications
            .map(
              (qualification) => coven_domain.CovenQualification(
                category: _covenQualificationCategory(qualification.category),
                personName: qualification.personName,
                effectiveDate: qualification.effectiveDate,
                verifiedAsOf: qualification.verifiedAsOf,
                validTo: qualification.validTo,
                evidence: qualification.evidence
                    .map(_mapCovenEvidenceSummary)
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        evidence: const [],
        saved: value.saved,
        demo: _mapCovenDemo(value.demo),
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
  Future<List<coven_domain.CovenEvidenceDetail>> fetchEvidence(
    String entryId,
  ) async {
    try {
      final values = (await _api.getCovenEvidence(entryId: entryId)).data!.data;
      return values
          .map(
            (value) => coven_domain.CovenEvidenceDetail(
              claimId: value.claimId,
              factorLabel: value.factorLabel,
              observedAt: value.observedAt,
              summary: value.summary,
              uncertainty: value.uncertainty,
              publisher: value.source_.publisher,
              sourceTitle: value.source_.title,
              sourceUrl: Uri.parse(value.source_.url),
              publishedAt: value.source_.publishedAt,
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      _throwApiFailure(error);
    } on FormatException {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<void> save(String entryId) async {
    try {
      await _saves.saveCoven(id: entryId, saveAssetRequest: SaveAssetRequest());
    } on DioException catch (error) {
      if (_isAmbiguousTransport(error)) throw const CovenAmbiguousMutation();
      _throwApiFailure(error);
    }
  }

  @override
  Future<void> unsave(String entryId) async {
    try {
      await _saves.unsaveCoven(id: entryId);
    } on DioException catch (error) {
      if (_isAmbiguousTransport(error)) throw const CovenAmbiguousMutation();
      _throwApiFailure(error);
    }
  }
}

coven_domain.CovenQualificationCategory _covenQualificationCategory(
  Object category,
) => switch (category) {
  CovenSummaryCategoryEnum.founder || CovenQualificationCategoryEnum.founder =>
    coven_domain.CovenQualificationCategory.founder,
  CovenSummaryCategoryEnum.owner || CovenQualificationCategoryEnum.owner =>
    coven_domain.CovenQualificationCategory.owner,
  CovenSummaryCategoryEnum.chiefExecutive ||
  CovenQualificationCategoryEnum.chiefExecutive =>
    coven_domain.CovenQualificationCategory.chiefExecutive,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

coven_domain.CovenEvidenceSummary _mapCovenEvidenceSummary(
  EvidenceSummary value,
) => coven_domain.CovenEvidenceSummary(
  claimId: value.claimId,
  factorLabel: value.factorLabel,
  observedAt: value.observedAt,
  summary: value.summary,
  uncertainty: value.uncertainty,
);

coven_domain.CovenDemoDisclosure _mapCovenDemo(DemoDisclosure value) =>
    coven_domain.CovenDemoDisclosure(
      isDemo: value.isDemo,
      observedAt: value.observedAt,
      sourceLabel: value.sourceLabel,
      limitations: value.limitations,
    );

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

class GeneratedPortfolioApiService implements PortfolioService, FundingService {
  GeneratedPortfolioApiService(RitualInvestingApiClient client)
    : _portfolios = PortfoliosApi(client.dio),
      _simulation = SimulationApi(client.dio);

  final PortfoliosApi _portfolios;
  final SimulationApi _simulation;

  @override
  Future<PortfolioCollection> fetchList() async {
    try {
      final values = (await _portfolios.listPortfolios()).data!.data;
      return PortfolioCollection(
        items: values.map(_portfolio).toList(growable: false),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<PortfolioSummary> fetchDetail(String portfolioId) async {
    try {
      return _portfolio(
        (await _portfolios.getPortfolio(portfolioId: portfolioId)).data!.data,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<List<PortfolioHolding>> fetchHoldings(String portfolioId) async {
    try {
      final values = (await _portfolios.listPortfolioHoldings(
        portfolioId: portfolioId,
      )).data!.data;
      return values.map(_holding).toList(growable: false);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<List<PortfolioActivityEntry>> fetchActivity(String portfolioId) async {
    try {
      final values = (await _portfolios.listPortfolioActivity(
        portfolioId: portfolioId,
      )).data!.data;
      return values.map(_activity).toList(growable: false);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<List<PortfolioSnapshotView>> fetchSnapshots(String portfolioId) async {
    try {
      final values = (await _portfolios.listPortfolioSnapshots(
        portfolioId: portfolioId,
      )).data!.data;
      return values.map(_snapshot).toList(growable: false);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _portfolios.createPortfolio(
        idempotencyKey: idempotencyKey,
        createPortfolioRequest: CreatePortfolioRequest(
          currency: CreatePortfolioRequestCurrencyEnum.USD,
          name: name,
        ),
      );
      return _portfolio(response.data!.data);
    } on DioException catch (error) {
      if (_isTransportFailure(error)) throw const PortfolioAmbiguousMutation();
      _throwApiFailure(error);
    }
  }

  @override
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  }) async {
    try {
      final response = await _portfolios.patchPortfolio(
        portfolioId: portfolioId,
        ifMatch: '"v$expectedVersion"',
        patchPortfolioRequest: PatchPortfolioRequest(name: name),
      );
      return _portfolio(response.data!.data);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
  }) async {
    try {
      await _portfolios.archivePortfolio(
        portfolioId: portfolioId,
        ifMatch: '"v$expectedVersion"',
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<List<FundingSource>> fetchSources() async {
    try {
      final values = (await _portfolios.listDemoFundingSources()).data!.data;
      return values.map(_fundingSource).toList(growable: false);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  }) async {
    try {
      final result = (await _portfolios.createDemoFundingSource(
        idempotencyKey: idempotencyKey,
        createDemoFundingSourceRequest: CreateDemoFundingSourceRequest(
          fixtureKey: switch (fixture) {
            FundingFixture.moonReserve =>
              CreateDemoFundingSourceRequestFixtureKeyEnum.moonReserve,
            FundingFixture.constellationSavings =>
              CreateDemoFundingSourceRequestFixtureKeyEnum.constellationSavings,
          },
        ),
      )).data!.data;
      return _fundingSource(result);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  @override
  Future<void> deleteSource(String sourceId) async {
    try {
      await _portfolios.deleteDemoFundingSource(sourceId: sourceId);
    } on DioException catch (error) {
      if (_apiErrorCode(error.response?.data) == 'funding_source_in_use') {
        throw const FundingFailure.fundingSourceInUse();
      }
      _throwApiFailure(error);
    }
  }

  @override
  Future<ContributionReceipt> contribute(ContributionCommand command) async {
    try {
      if (command.currency != PortfolioCurrency.usd) {
        _terminalContract();
      }
      final result = (await _simulation.createDemoContribution(
        portfolioId: command.portfolioId,
        idempotencyKey: command.idempotencyKey,
        createDemoContributionRequest: CreateDemoContributionRequest(
          amount: PositiveInputMoney(
            currency: PositiveInputMoneyCurrencyEnum.USD,
            minorUnits: command.minorUnits,
          ),
          effectiveAt: command.effectiveAt?.toUtc(),
          sourceId: command.sourceId,
        ),
      )).data!.data;
      if (result.status != SimulationResultStatusEnum.committed) {
        _terminalContract();
      }
      return ContributionReceipt(
        commandId: result.commandId,
        portfolioVersion: result.portfolioVersion,
        ledgerTransactionIds: List.unmodifiable(result.ledgerTransactionIds),
        demo: _fundingDemo(result.demo),
      );
    } on DioException catch (error) {
      if (_isTransportFailure(error)) {
        throw const AmbiguousContributionFailure();
      }
      _throwApiFailure(error);
    }
  }

  PortfolioSummary _portfolio(PortfolioView value) {
    _requirePortfolioCurrency(value.currency);
    _requireMoneyCurrency(value.cash.currency);
    _requireMoneyCurrency(value.latestValuation.currency);
    final status = switch (value.status) {
      PortfolioViewStatusEnum.active => PortfolioStatus.active,
      PortfolioViewStatusEnum.archived => PortfolioStatus.archived,
      PortfolioViewStatusEnum.unknownDefaultOpenApi => _terminalContract(),
    };
    final targetAllocation = value.targetAllocation
        .map((target) {
          if (target.targetBps < 0 || target.targetBps > 10000) {
            _terminalContract();
          }
          return PortfolioTargetAllocation(
            assetId: target.assetId,
            targetBps: target.targetBps,
          );
        })
        .toList(growable: false);
    return PortfolioSummary(
      id: value.id,
      name: value.name,
      cashMinor: value.cash.minorUnits,
      valuationMinor: value.latestValuation.minorUnits,
      currency: PortfolioCurrency.usd,
      status: status,
      isDefault: value.isDefault,
      version: value.version,
      ledgerWatermark: value.ledgerWatermark,
      asOfTransactionId: value.asOfTransactionId,
      demo: _portfolioDemo(value.demo),
      targetAllocation: List.unmodifiable(targetAllocation),
    );
  }

  PortfolioHolding _holding(ListPortfolioHoldings200ResponseDataInner value) {
    _requireMoneyCurrency(value.marketValue.currency);
    return PortfolioHolding(
      assetId: value.assetId,
      symbol: value.symbol,
      quantityValue: value.quantity.value,
      quantityScale: value.quantity.scale,
      marketValueMinor: value.marketValue.minorUnits,
      currency: PortfolioCurrency.usd,
      ledgerWatermark: value.ledgerWatermark,
      asOfTransactionId: value.asOfTransactionId,
    );
  }

  PortfolioActivityEntry _activity(PortfolioActivity value) {
    if (value.cash.currency != SignedMoneyCurrencyEnum.USD) {
      _terminalContract();
    }
    final type = switch (value.type) {
      PortfolioActivityTypeEnum.contribution =>
        PortfolioActivityType.contribution,
      PortfolioActivityTypeEnum.order => PortfolioActivityType.order,
      PortfolioActivityTypeEnum.rebalance => PortfolioActivityType.rebalance,
      PortfolioActivityTypeEnum.recurring => PortfolioActivityType.recurring,
      PortfolioActivityTypeEnum.unknownDefaultOpenApi => _terminalContract(),
    };
    return PortfolioActivityEntry(
      id: value.id,
      type: type,
      descriptionCode: value.descriptionCode,
      effectiveAt: value.effectiveAt.toUtc(),
      cashMinor: value.cash.minorUnits,
      currency: PortfolioCurrency.usd,
      ledgerWatermark: value.ledgerWatermark,
      demo: _portfolioDemo(value.demo),
    );
  }

  PortfolioSnapshotView _snapshot(PortfolioSnapshot value) {
    _requireMoneyCurrency(value.cash.currency);
    _requireMoneyCurrency(value.marketValue.currency);
    return PortfolioSnapshotView(
      id: value.id,
      asOfTransactionId: value.asOfTransactionId,
      ledgerWatermark: value.ledgerWatermark,
      asOf: value.asOf.toUtc(),
      cashMinor: value.cash.minorUnits,
      marketValueMinor: value.marketValue.minorUnits,
      currency: PortfolioCurrency.usd,
      demo: _portfolioDemo(value.demo),
    );
  }

  FundingSource _fundingSource(DemoFundingSource value) {
    final fixture = switch (value.fixtureKey) {
      DemoFundingSourceFixtureKeyEnum.moonReserve => FundingFixture.moonReserve,
      DemoFundingSourceFixtureKeyEnum.constellationSavings =>
        FundingFixture.constellationSavings,
      DemoFundingSourceFixtureKeyEnum.unknownDefaultOpenApi =>
        _terminalContract(),
    };
    final expected = switch (fixture) {
      FundingFixture.moonReserve => ('Moon Reserve (fictional)', '1108'),
      FundingFixture.constellationSavings => (
        'Constellation Savings (fictional)',
        '2042',
      ),
    };
    if (value.displayLabel != expected.$1 ||
        value.fictionalLast4 != expected.$2) {
      _terminalContract();
    }
    final status = switch (value.status) {
      DemoFundingSourceStatusEnum.active => FundingSourceStatus.active,
      DemoFundingSourceStatusEnum.inactive => FundingSourceStatus.inactive,
      DemoFundingSourceStatusEnum.unknownDefaultOpenApi => _terminalContract(),
    };
    return FundingSource(
      id: value.id,
      fixture: fixture,
      displayLabel: value.displayLabel,
      fictionalLast4: value.fictionalLast4,
      status: status,
      demo: _fundingDemo(value.demo),
    );
  }

  PortfolioDemoDisclosure _portfolioDemo(SimulationDemoDisclosure value) {
    _requireDemo(value);
    return PortfolioDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  FundingDemoDisclosure _fundingDemo(SimulationDemoDisclosure value) {
    _requireDemo(value);
    return FundingDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  void _requireDemo(SimulationDemoDisclosure value) {
    if (!value.isDemo ||
        value.sourceLabel.trim().isEmpty ||
        value.limitations.isEmpty) {
      _terminalContract();
    }
  }

  void _requirePortfolioCurrency(PortfolioViewCurrencyEnum currency) {
    if (currency != PortfolioViewCurrencyEnum.USD) _terminalContract();
  }

  void _requireMoneyCurrency(MoneyCurrencyEnum currency) {
    if (currency != MoneyCurrencyEnum.USD) _terminalContract();
  }
}

class GeneratedOrderApiService implements OrderService {
  GeneratedOrderApiService(RitualInvestingApiClient client)
    : _mapping = _GeneratedSimulatedInvestingMappings(client);
  final _GeneratedSimulatedInvestingMappings _mapping;
  @override
  Future<order_domain.OrderPreview> preview(order_domain.OrderDraft draft) =>
      _mapping.previewOrder(draft);
  @override
  Future<order_domain.OrderReceipt> commit(order_domain.OrderCommit command) =>
      _mapping.commitOrder(command);
  @override
  Future<List<order_domain.OrderView>> list(String portfolioId) =>
      _mapping.listOrders(portfolioId);
  @override
  Future<order_domain.OrderView> get(String orderId) =>
      _mapping.getOrder(orderId);
}

class GeneratedRecurringPlanApiService implements RecurringPlanService {
  GeneratedRecurringPlanApiService(RitualInvestingApiClient client)
    : _mapping = _GeneratedSimulatedInvestingMappings(client);
  final _GeneratedSimulatedInvestingMappings _mapping;
  @override
  Future<List<recurring_domain.RecurringPlan>> list(String portfolioId) =>
      _mapping.listRecurringPlans(portfolioId);
  @override
  Future<recurring_domain.RecurringPlan> get(String planId) =>
      _mapping.getRecurringPlan(planId);
  @override
  Future<recurring_domain.RecurringPlan> create(
    recurring_domain.RecurringPlanCreate command,
  ) => _mapping.createRecurringPlan(command);
  @override
  Future<recurring_domain.RecurringPlan> edit(
    recurring_domain.RecurringPlanEdit command,
  ) => _mapping.editRecurringPlan(command);
  @override
  Future<recurring_domain.RecurringPlan> pause(String planId, int version) =>
      _mapping.pauseRecurringPlan(planId, version);
  @override
  Future<recurring_domain.RecurringPlan> resume(String planId, int version) =>
      _mapping.resumeRecurringPlan(planId, version);
  @override
  Future<void> cancel(String planId, int version) =>
      _mapping.cancelRecurringPlan(planId, version);
}

class GeneratedRebalanceApiService implements RebalanceService {
  GeneratedRebalanceApiService(RitualInvestingApiClient client)
    : _mapping = _GeneratedSimulatedInvestingMappings(client);
  final _GeneratedSimulatedInvestingMappings _mapping;
  @override
  Future<rebalance_domain.RebalancePreview> preview(
    String portfolioId,
    List<rebalance_domain.RebalanceAllocation> allocations,
  ) => _mapping.previewRebalance(portfolioId, allocations);
  @override
  Future<rebalance_domain.RebalanceReceipt> commit(
    rebalance_domain.RebalanceCommit command,
  ) => _mapping.commitRebalance(command);
}

class _GeneratedSimulatedInvestingMappings {
  _GeneratedSimulatedInvestingMappings(RitualInvestingApiClient client)
    : _orders = OrdersApi(client.dio),
      _recurring = RecurringPlansApi(client.dio),
      _rebalancing = RebalancingApi(client.dio);

  final OrdersApi _orders;
  final RecurringPlansApi _recurring;
  final RebalancingApi _rebalancing;

  Future<order_domain.OrderPreview> previewOrder(
    order_domain.OrderDraft draft,
  ) async {
    try {
      final value = (await _orders.createOrderPreview(
        portfolioId: draft.portfolioId,
        createOrderPreviewRequest: CreateOrderPreviewRequest(
          assetId: draft.assetId,
          side: switch (draft.side) {
            order_domain.OrderSide.buy => CreateOrderPreviewRequestSideEnum.buy,
            order_domain.OrderSide.sell =>
              CreateOrderPreviewRequestSideEnum.sell,
          },
          notional: draft.notionalMinor == null
              ? null
              : PositiveInputMoney(
                  currency: PositiveInputMoneyCurrencyEnum.USD,
                  minorUnits: draft.notionalMinor!,
                ),
          quantity: draft.quantityValue == null
              ? null
              : Quantity(
                  value: draft.quantityValue!,
                  scale: draft.quantityScale!,
                ),
        ),
      )).data!.data;
      return _orderPreview(
        value,
        expectedPortfolioId: draft.portfolioId,
        expectedAssetId: draft.assetId,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  Future<order_domain.OrderReceipt> commitOrder(
    order_domain.OrderCommit command,
  ) async {
    try {
      final value = (await _orders.commitOrder(
        portfolioId: command.portfolioId,
        idempotencyKey: command.idempotencyKey,
        commitOrderRequest: CommitOrderRequest(
          previewId: command.previewId,
          portfolioVersion: command.portfolioVersion,
        ),
      )).data!.data;
      if (value.status != SimulationResultStatusEnum.committed) {
        _terminalContract();
      }
      _requireReceipt(
        commandId: value.commandId,
        portfolioVersion: value.portfolioVersion,
        ledgerTransactionIds: value.ledgerTransactionIds,
      );
      return order_domain.OrderReceipt(
        commandId: value.commandId,
        portfolioVersion: value.portfolioVersion,
        ledgerTransactionIds: List.unmodifiable(value.ledgerTransactionIds),
        demo: _orderDemo(value.demo),
      );
    } on DioException catch (error) {
      if (_isTransportFailure(error)) {
        throw const order_domain.AmbiguousOrderFailure();
      }
      final code = _apiErrorCode(error.response?.data);
      if (code == 'preview_stale' || code == 'version_conflict') {
        throw const order_domain.OrderCommitFailure.stalePreview();
      }
      _throwApiFailure(error);
    }
  }

  Future<List<order_domain.OrderView>> listOrders(String portfolioId) async {
    try {
      final values = (await _orders.listOrders(portfolioId: portfolioId))
          .data!
          .data;
      return values
          .map((value) => _orderView(value, expectedPortfolioId: portfolioId))
          .toList(growable: false);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  Future<order_domain.OrderView> getOrder(String orderId) async {
    try {
      final value = (await _orders.getOrder(orderId: orderId)).data!.data;
      if (value.id != orderId) _terminalContract();
      return _orderView(value);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  Future<List<recurring_domain.RecurringPlan>> listRecurringPlans(
    String portfolioId,
  ) async {
    try {
      final values = (await _recurring.listRecurringPlans(
        portfolioId: portfolioId,
      )).data!.data;
      return values
          .map(
            (value) => _recurringPlan(value, expectedPortfolioId: portfolioId),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  Future<recurring_domain.RecurringPlan> getRecurringPlan(String planId) async {
    try {
      final value = (await _recurring.getRecurringPlan(planId: planId))
          .data!
          .data;
      if (value.id != planId) _terminalContract();
      return _recurringPlan(value);
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }

  Future<recurring_domain.RecurringPlan> createRecurringPlan(
    recurring_domain.RecurringPlanCreate command,
  ) async {
    final draft = command.draft;
    try {
      final value = (await _recurring.createRecurringPlan(
        portfolioId: draft.portfolioId,
        idempotencyKey: command.idempotencyKey,
        createRecurringPlanRequest: CreateRecurringPlanRequest(
          type: switch (draft.type) {
            recurring_domain.RecurringType.contribution =>
              CreateRecurringPlanRequestTypeEnum.contribution,
            recurring_domain.RecurringType.allocation =>
              CreateRecurringPlanRequestTypeEnum.allocation,
          },
          amount: PositiveInputMoney(
            currency: PositiveInputMoneyCurrencyEnum.USD,
            minorUnits: draft.amountMinor,
          ),
          frequency: switch (draft.frequency) {
            recurring_domain.RecurringFrequency.weekly =>
              CreateRecurringPlanRequestFrequencyEnum.weekly,
            recurring_domain.RecurringFrequency.monthly =>
              CreateRecurringPlanRequestFrequencyEnum.monthly,
          },
          sourceId: draft.sourceId,
          allocations: draft.allocations
              .map(
                (item) => CreateRecurringPlanRequestAllocationsInner(
                  assetId: item.assetId,
                  weightBps: item.weightBps,
                ),
              )
              .toList(growable: false),
          firstRunAt: draft.firstRunAt.toUtc(),
        ),
      )).data!.data;
      return _recurringPlan(value, expectedPortfolioId: draft.portfolioId);
    } on DioException catch (error) {
      if (_isTransportFailure(error)) {
        throw const recurring_domain.AmbiguousRecurringCreateFailure();
      }
      _throwApiFailure(error);
    }
  }

  Future<recurring_domain.RecurringPlan> editRecurringPlan(
    recurring_domain.RecurringPlanEdit command,
  ) async {
    try {
      final value = (await _recurring.patchRecurringPlan(
        planId: command.planId,
        ifMatch: '"v${command.expectedVersion}"',
        patchRecurringPlanRequest: PatchRecurringPlanRequest(
          amount: command.amountMinor == null
              ? null
              : PositiveInputMoney(
                  currency: PositiveInputMoneyCurrencyEnum.USD,
                  minorUnits: command.amountMinor!,
                ),
          frequency: switch (command.frequency) {
            recurring_domain.RecurringFrequency.weekly =>
              PatchRecurringPlanRequestFrequencyEnum.weekly,
            recurring_domain.RecurringFrequency.monthly =>
              PatchRecurringPlanRequestFrequencyEnum.monthly,
            null => null,
          },
          allocations: command.allocations
              ?.map(
                (item) => CreateRecurringPlanRequestAllocationsInner(
                  assetId: item.assetId,
                  weightBps: item.weightBps,
                ),
              )
              .toList(growable: false),
        ),
      )).data!.data;
      if (value.id != command.planId) _terminalContract();
      return _recurringPlan(value);
    } on DioException catch (error) {
      _throwRecurringMutation(error);
    }
  }

  Future<recurring_domain.RecurringPlan> pauseRecurringPlan(
    String planId,
    int expectedVersion,
  ) => _transitionRecurring(
    planId,
    () => _recurring.pauseRecurringPlan(
      planId: planId,
      ifMatch: '"v$expectedVersion"',
    ),
  );

  Future<recurring_domain.RecurringPlan> resumeRecurringPlan(
    String planId,
    int expectedVersion,
  ) => _transitionRecurring(
    planId,
    () => _recurring.resumeRecurringPlan(
      planId: planId,
      ifMatch: '"v$expectedVersion"',
    ),
  );

  Future<recurring_domain.RecurringPlan> _transitionRecurring(
    String planId,
    Future<Response<CreateRecurringPlan201Response>> Function() request,
  ) async {
    try {
      final value = (await request()).data!.data;
      if (value.id != planId) _terminalContract();
      return _recurringPlan(value);
    } on DioException catch (error) {
      _throwRecurringMutation(error);
    }
  }

  Future<void> cancelRecurringPlan(String planId, int expectedVersion) async {
    try {
      await _recurring.cancelRecurringPlan(
        planId: planId,
        ifMatch: '"v$expectedVersion"',
      );
    } on DioException catch (error) {
      _throwRecurringMutation(error);
    }
  }

  Future<rebalance_domain.RebalancePreview> previewRebalance(
    String portfolioId,
    List<rebalance_domain.RebalanceAllocation> allocations,
  ) async {
    try {
      final value = (await _rebalancing.createRebalancePreview(
        portfolioId: portfolioId,
        createRebalancePreviewRequest: CreateRebalancePreviewRequest(
          targetAllocation: allocations
              .map(
                (item) => CreatePortfolioRequestTargetAllocationInner(
                  assetId: item.assetId,
                  targetBps: item.targetBps,
                ),
              )
              .toList(growable: false),
        ),
      )).data!.data;
      final preview = _rebalancePreview(value);
      if (preview.portfolioId != portfolioId) _terminalContract();
      return preview;
    } on DioException catch (error) {
      if (_apiErrorCode(error.response?.data) == 'already_balanced') {
        throw const rebalance_domain.RebalanceAlreadyBalanced();
      }
      _throwApiFailure(error);
    }
  }

  Future<rebalance_domain.RebalanceReceipt> commitRebalance(
    rebalance_domain.RebalanceCommit command,
  ) async {
    try {
      final value = (await _rebalancing.commitRebalance(
        portfolioId: command.portfolioId,
        idempotencyKey: command.idempotencyKey,
        commitOrderRequest: CommitOrderRequest(
          previewId: command.previewId,
          portfolioVersion: command.portfolioVersion,
        ),
      )).data!.data;
      if (value.status != SimulationResultStatusEnum.committed) {
        _terminalContract();
      }
      _requireReceipt(
        commandId: value.commandId,
        portfolioVersion: value.portfolioVersion,
        ledgerTransactionIds: value.ledgerTransactionIds,
      );
      return rebalance_domain.RebalanceReceipt(
        commandId: value.commandId,
        portfolioVersion: value.portfolioVersion,
        ledgerTransactionIds: List.unmodifiable(value.ledgerTransactionIds),
        demo: _rebalanceDemo(value.demo),
      );
    } on DioException catch (error) {
      if (_isTransportFailure(error)) {
        throw const rebalance_domain.AmbiguousRebalanceFailure();
      }
      final code = _apiErrorCode(error.response?.data);
      if (code == 'preview_stale' || code == 'version_conflict') {
        throw const rebalance_domain.RebalanceCommitFailure.stalePreview();
      }
      _throwApiFailure(error);
    }
  }

  Never _throwRecurringMutation(DioException error) {
    if (_isTransportFailure(error)) {
      throw const recurring_domain.AmbiguousRecurringMutationFailure();
    }
    final code = _apiErrorCode(error.response?.data);
    if (code == 'version_conflict') {
      throw const recurring_domain.RecurringFailure.conflict();
    }
    if (code == 'invalid_transition') {
      throw const recurring_domain.RecurringFailure.invalidTransition();
    }
    _throwApiFailure(error);
  }

  order_domain.OrderPreview _orderPreview(
    OrderPreview value, {
    required String expectedPortfolioId,
    required String expectedAssetId,
  }) {
    _requireUsd(value.notional.currency);
    _requireUsd(value.frozenPrice.currency);
    if (value.id.trim().isEmpty ||
        value.portfolioId != expectedPortfolioId ||
        value.assetId != expectedAssetId ||
        value.symbol.trim().isEmpty ||
        value.portfolioVersion < 1 ||
        value.notional.minorUnits < 1 ||
        value.frozenPrice.minorUnits < 1 ||
        value.quoteSnapshotId.trim().isEmpty ||
        !_validQuantity(value.quantity.value, value.quantity.scale) ||
        !value.expiresAt.isAfter(value.observedAt)) {
      _terminalContract();
    }
    return order_domain.OrderPreview(
      id: value.id,
      portfolioId: value.portfolioId,
      portfolioVersion: value.portfolioVersion,
      assetId: value.assetId,
      symbol: value.symbol,
      side: switch (value.side) {
        OrderPreviewSideEnum.buy => order_domain.OrderSide.buy,
        OrderPreviewSideEnum.sell => order_domain.OrderSide.sell,
        OrderPreviewSideEnum.unknownDefaultOpenApi => _terminalContract(),
      },
      notionalMinor: value.notional.minorUnits,
      quantityValue: value.quantity.value,
      quantityScale: value.quantity.scale,
      frozenPriceMinor: value.frozenPrice.minorUnits,
      quoteSnapshotId: value.quoteSnapshotId,
      observedAt: value.observedAt.toUtc(),
      expiresAt: value.expiresAt.toUtc(),
      status: switch (value.status) {
        OrderPreviewStatusEnum.active => order_domain.OrderPreviewStatus.active,
        OrderPreviewStatusEnum.executed =>
          order_domain.OrderPreviewStatus.executed,
        OrderPreviewStatusEnum.expired =>
          order_domain.OrderPreviewStatus.expired,
        OrderPreviewStatusEnum.invalidated =>
          order_domain.OrderPreviewStatus.invalidated,
        OrderPreviewStatusEnum.unknownDefaultOpenApi => _terminalContract(),
      },
      demo: _orderDemo(value.demo),
    );
  }

  order_domain.OrderView _orderView(
    SimulatedOrder value, {
    String? expectedPortfolioId,
  }) {
    if (value.notional case final amount?) _requireUsd(amount.currency);
    if (value.fill case final fill?) _requireUsd(fill.price.currency);
    final fill = value.fill;
    if (value.id.trim().isEmpty ||
        value.portfolioId.trim().isEmpty ||
        (expectedPortfolioId != null &&
            value.portfolioId != expectedPortfolioId) ||
        value.commandId.trim().isEmpty ||
        value.assetId.trim().isEmpty ||
        value.symbol.trim().isEmpty ||
        (value.notional != null && value.notional!.minorUnits < 1) ||
        (value.quantity != null &&
            !_validQuantity(value.quantity!.value, value.quantity!.scale)) ||
        (value.notional == null && value.quantity == null) ||
        (value.status == SimulatedOrderStatusEnum.accepted && fill == null) ||
        (value.status == SimulatedOrderStatusEnum.rejected && fill != null) ||
        (fill != null &&
            (!_validQuantity(fill.quantity.value, fill.quantity.scale) ||
                fill.price.minorUnits < 1))) {
      _terminalContract();
    }
    return order_domain.OrderView(
      id: value.id,
      portfolioId: value.portfolioId,
      commandId: value.commandId,
      assetId: value.assetId,
      symbol: value.symbol,
      side: switch (value.side) {
        SimulatedOrderSideEnum.buy => order_domain.OrderSide.buy,
        SimulatedOrderSideEnum.sell => order_domain.OrderSide.sell,
        SimulatedOrderSideEnum.unknownDefaultOpenApi => _terminalContract(),
      },
      status: switch (value.status) {
        SimulatedOrderStatusEnum.accepted => order_domain.OrderStatus.accepted,
        SimulatedOrderStatusEnum.rejected => order_domain.OrderStatus.rejected,
        SimulatedOrderStatusEnum.unknownDefaultOpenApi => _terminalContract(),
      },
      notionalMinor: value.notional?.minorUnits,
      quantityValue: value.quantity?.value,
      quantityScale: value.quantity?.scale,
      fill: value.fill == null
          ? null
          : order_domain.OrderFill(
              quantityValue: value.fill!.quantity.value,
              quantityScale: value.fill!.quantity.scale,
              priceMinor: value.fill!.price.minorUnits,
              filledAt: value.fill!.filledAt.toUtc(),
            ),
      demo: _orderDemo(value.demo),
    );
  }

  recurring_domain.RecurringPlan _recurringPlan(
    RecurringPlan value, {
    String? expectedPortfolioId,
  }) {
    _requireUsd(value.amount.currency);
    final allocations = value.allocations
        .map(
          (item) => recurring_domain.RecurringAllocation(
            assetId: item.assetId,
            weightBps: item.weightBps,
          ),
        )
        .toList(growable: false);
    final runIds = value.recentRuns
        .map((run) => run.id)
        .toList(growable: false);
    if (value.id.trim().isEmpty ||
        value.portfolioId.trim().isEmpty ||
        (expectedPortfolioId != null &&
            value.portfolioId != expectedPortfolioId) ||
        value.amount.minorUnits < 1 ||
        value.version < 1 ||
        !_validRecurringAllocations(allocations) ||
        runIds.any((id) => id.trim().isEmpty) ||
        runIds.toSet().length != runIds.length) {
      _terminalContract();
    }
    return recurring_domain.RecurringPlan(
      id: value.id,
      portfolioId: value.portfolioId,
      type: switch (value.type) {
        RecurringPlanTypeEnum.contribution =>
          recurring_domain.RecurringType.contribution,
        RecurringPlanTypeEnum.allocation =>
          recurring_domain.RecurringType.allocation,
        RecurringPlanTypeEnum.unknownDefaultOpenApi => _terminalContract(),
      },
      amountMinor: value.amount.minorUnits,
      frequency: switch (value.frequency) {
        RecurringPlanFrequencyEnum.weekly =>
          recurring_domain.RecurringFrequency.weekly,
        RecurringPlanFrequencyEnum.monthly =>
          recurring_domain.RecurringFrequency.monthly,
        RecurringPlanFrequencyEnum.unknownDefaultOpenApi => _terminalContract(),
      },
      nextRunAt: value.nextRunAt.toUtc(),
      status: switch (value.status) {
        RecurringPlanStatusEnum.active =>
          recurring_domain.RecurringStatus.active,
        RecurringPlanStatusEnum.paused =>
          recurring_domain.RecurringStatus.paused,
        RecurringPlanStatusEnum.cancelled =>
          recurring_domain.RecurringStatus.cancelled,
        RecurringPlanStatusEnum.completed =>
          recurring_domain.RecurringStatus.completed,
        RecurringPlanStatusEnum.unknownDefaultOpenApi => _terminalContract(),
      },
      allocations: allocations,
      recentRuns: value.recentRuns
          .map(
            (item) => recurring_domain.RecurringRun(
              id: item.id,
              scheduledFor: item.scheduledFor.toUtc(),
              status: switch (item.status) {
                RecurringPlanRecentRunsInnerStatusEnum.due =>
                  recurring_domain.RecurringRunStatus.due,
                RecurringPlanRecentRunsInnerStatusEnum.running =>
                  recurring_domain.RecurringRunStatus.running,
                RecurringPlanRecentRunsInnerStatusEnum.completed =>
                  recurring_domain.RecurringRunStatus.completed,
                RecurringPlanRecentRunsInnerStatusEnum.rejected =>
                  recurring_domain.RecurringRunStatus.rejected,
                RecurringPlanRecentRunsInnerStatusEnum.unknownDefaultOpenApi =>
                  _terminalContract(),
              },
            ),
          )
          .toList(growable: false),
      version: value.version,
      demo: _recurringDemo(value.demo),
    );
  }

  rebalance_domain.RebalancePreview _rebalancePreview(RebalancePreview value) {
    final targetAllocation = value.targetAllocation
        .map(
          (item) => rebalance_domain.RebalanceAllocation(
            assetId: item.assetId,
            targetBps: item.targetBps,
          ),
        )
        .toList(growable: false);
    final tradeIds = value.trades.map((trade) => trade.assetId).toList();
    if (value.id.trim().isEmpty ||
        value.portfolioId.trim().isEmpty ||
        value.portfolioVersion < 1 ||
        !rebalance_domain.validRebalanceAllocations(targetAllocation) ||
        value.trades.isEmpty ||
        tradeIds.any((id) => id.trim().isEmpty) ||
        tradeIds.toSet().length != tradeIds.length ||
        value.trades.any(
          (trade) =>
              !_validQuantity(trade.quantity.value, trade.quantity.scale) ||
              trade.notional.minorUnits < 1,
        )) {
      _terminalContract();
    }
    return rebalance_domain.RebalancePreview(
      id: value.id,
      portfolioId: value.portfolioId,
      portfolioVersion: value.portfolioVersion,
      targetAllocation: targetAllocation,
      trades: value.trades
          .map((item) {
            _requireUsd(item.notional.currency);
            return rebalance_domain.RebalanceTrade(
              assetId: item.assetId,
              side: switch (item.side) {
                RebalancePreviewTradesInnerSideEnum.buy =>
                  rebalance_domain.RebalanceSide.buy,
                RebalancePreviewTradesInnerSideEnum.sell =>
                  rebalance_domain.RebalanceSide.sell,
                RebalancePreviewTradesInnerSideEnum.unknownDefaultOpenApi =>
                  _terminalContract(),
              },
              quantityValue: item.quantity.value,
              quantityScale: item.quantity.scale,
              notionalMinor: item.notional.minorUnits,
            );
          })
          .toList(growable: false),
      expiresAt: value.expiresAt.toUtc(),
      status: switch (value.status) {
        RebalancePreviewStatusEnum.active =>
          rebalance_domain.RebalancePreviewStatus.active,
        RebalancePreviewStatusEnum.executed =>
          rebalance_domain.RebalancePreviewStatus.executed,
        RebalancePreviewStatusEnum.expired =>
          rebalance_domain.RebalancePreviewStatus.expired,
        RebalancePreviewStatusEnum.invalidated =>
          rebalance_domain.RebalancePreviewStatus.invalidated,
        RebalancePreviewStatusEnum.unknownDefaultOpenApi => _terminalContract(),
      },
      demo: _rebalanceDemo(value.demo),
    );
  }

  order_domain.OrderDemoDisclosure _orderDemo(SimulationDemoDisclosure value) {
    _requireGeneratedDemo(value);
    return order_domain.OrderDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  recurring_domain.RecurringDemoDisclosure _recurringDemo(
    SimulationDemoDisclosure value,
  ) {
    _requireGeneratedDemo(value);
    return recurring_domain.RecurringDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  rebalance_domain.RebalanceDemoDisclosure _rebalanceDemo(
    SimulationDemoDisclosure value,
  ) {
    _requireGeneratedDemo(value);
    return rebalance_domain.RebalanceDemoDisclosure(
      isDemo: true,
      observedAt: value.observedAt.toUtc(),
      sourceLabel: value.sourceLabel,
      limitations: List.unmodifiable(value.limitations),
    );
  }

  void _requireUsd(MoneyCurrencyEnum currency) {
    if (currency != MoneyCurrencyEnum.USD) _terminalContract();
  }

  void _requireGeneratedDemo(SimulationDemoDisclosure value) {
    if (!value.isDemo ||
        value.sourceLabel.trim().isEmpty ||
        value.limitations.isEmpty ||
        value.limitations.any((item) => item.trim().isEmpty)) {
      _terminalContract();
    }
  }

  void _requireReceipt({
    required String commandId,
    required int portfolioVersion,
    required List<String> ledgerTransactionIds,
  }) {
    if (commandId.trim().isEmpty ||
        portfolioVersion < 1 ||
        ledgerTransactionIds.isEmpty ||
        ledgerTransactionIds.any((id) => id.trim().isEmpty) ||
        ledgerTransactionIds.toSet().length != ledgerTransactionIds.length) {
      _terminalContract();
    }
  }

  bool _validRecurringAllocations(
    List<recurring_domain.RecurringAllocation> allocations,
  ) =>
      allocations.isNotEmpty &&
      allocations.length <= 50 &&
      allocations.every(
        (allocation) =>
            allocation.assetId.trim().isNotEmpty &&
            allocation.weightBps >= 0 &&
            allocation.weightBps <= 10000,
      ) &&
      allocations.map((allocation) => allocation.assetId).toSet().length ==
          allocations.length &&
      allocations.fold<int>(0, (sum, value) => sum + value.weightBps) == 10000;

  bool _validQuantity(String value, int scale) =>
      scale >= 0 &&
      scale <= 12 &&
      RegExp(r'^(?:0|[1-9]\d*)(?:\.\d{1,12})?$').hasMatch(value) &&
      value.replaceAll(RegExp(r'[^0-9]'), '').contains(RegExp(r'[1-9]'));
}

Never _terminalContract() => throw const LoadFailure(
  LoadPhase.terminalFailure,
  message: 'The Demo data format is not supported by this app version.',
);

bool _isTransportFailure(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;

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
    final code = _apiErrorCode(error.response?.data);
    final message = _apiErrorMessage(error.response?.data);
    if (code != null) {
      return LoadFailure(switch (code) {
        'forbidden' || 'insufficient_scope' => LoadPhase.forbidden,
        'not_found' || 'resource_not_found' => LoadPhase.empty,
        'conflict' ||
        'version_conflict' ||
        'idempotency_conflict' ||
        'portfolio_archive_blocked' => LoadPhase.conflict,
        'rate_limited' || 'throttled' => LoadPhase.throttled,
        'temporarily_unavailable' ||
        'service_unavailable' => LoadPhase.retryableFailure,
        _ => LoadPhase.terminalFailure,
      }, message: message);
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
}

String? _apiErrorCode(Object? data) {
  if (data is! Map) return null;
  final envelope = data['error'];
  if (envelope is! Map) return null;
  final code = envelope['code'];
  return code is String ? code : null;
}

String? _apiErrorMessage(Object? data) {
  if (data is! Map) return null;
  final envelope = data['error'];
  if (envelope is! Map) return null;
  final message = envelope['message'];
  return message is String && message.trim().isNotEmpty ? message : null;
}
