import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../features/coven/data/repository.dart';
import '../../features/coven/domain/model.dart';
import '../../features/discover/data/repository.dart';
import '../../features/discover/domain/model.dart';
import '../../features/profile/data/repository.dart';
import '../../features/profile/domain/model.dart';
import '../../features/portfolio/data/repository.dart';
import '../../features/portfolio/domain/model.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/ritual/domain/daily_ritual.dart';
import '../bootstrap/member_bootstrap.dart';
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
      return MemberBootstrap(
        accountId: data.account.id,
        resetGeneration: data.resetGeneration,
        onboarding: MemberOnboardingGate.fromServer(
          cohort: data.onboarding.cohort.value,
          currentStep: data.onboarding.currentStep,
          completedAt: data.onboarding.completedAt,
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
          SessionBootstrapPreferencesThemeModeEnum.dark =>
            MemberThemePreference.dark,
          SessionBootstrapPreferencesThemeModeEnum.system ||
          SessionBootstrapPreferencesThemeModeEnum.unknownDefaultOpenApi =>
            MemberThemePreference.system,
        },
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

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
    : _api = AccountApi(client.dio);
  final AccountApi _api;
  @override
  Future<ProfileModel> fetch() async {
    try {
      return ProfileModel(
        displayName: (await _api.getMe()).data!.data.profile.displayName,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

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
