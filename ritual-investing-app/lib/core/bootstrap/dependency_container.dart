// ignore_for_file: prefer_initializing_formals

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:ritual_investing_api_client/generated/api.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';

import '../../features/coven/application/controller.dart';
import '../../features/coven/data/repository.dart';
import '../../features/coven/domain/model.dart';
import '../../features/discover/application/controller.dart';
import '../../features/discover/data/repository.dart';
import '../../features/discover/domain/model.dart';
import '../../features/profile/application/controller.dart';
import '../../features/profile/data/repository.dart';
import '../../features/profile/domain/model.dart';
import '../../features/portfolio/application/controller.dart';
import '../../features/portfolio/data/repository.dart';
import '../../features/portfolio/domain/model.dart';
import '../../features/ritual/application/daily_ritual_controller.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/ritual/domain/daily_ritual.dart';
import '../api/ritual_api.dart';
import '../auth/auth0_session_repository.dart';
import '../auth/auth_controller.dart';
import '../cache/read_cache.dart';
import '../config/runtime_config.dart';

class DependencyContainer {
  DependencyContainer({
    required this.authController,
    required this.dailyRitualController,
    required this.discoverController,
    required this.covenController,
    required this.profileController,
    required this.portfolioController,
    required ReadCache cache,
  }) : _cache = cache;

  final AuthController authController;
  final DailyRitualController dailyRitualController;
  final DiscoverController discoverController;
  final CovenController covenController;
  final ProfileController profileController;
  final PortfolioController portfolioController;
  final ReadCache _cache;
  bool _legacyMutationsCleared = false;

  Future<void> bootstrap() async {
    await authController.restore();
    await _loadAuthenticatedState();
  }

  Future<void> login() async {
    await authController.login();
    await _loadAuthenticatedState();
  }

  Future<void> _loadAuthenticatedState() async {
    if (authController.state.phase != AuthPhase.signedIn) return;
    if (!_legacyMutationsCleared) {
      await _cache.clearLegacyMutations();
      _legacyMutationsCleared = true;
    }
    await Future.wait([
      dailyRitualController.load(),
      discoverController.load(),
      covenController.load(),
      profileController.load(),
      portfolioController.load(),
    ]);
  }

  factory DependencyContainer.production(RuntimeConfig config) {
    final cache = MemoryReadCache();
    final auth = AuthController(
      repository: Auth0SessionRepository(
        auth0: Auth0(config.auth0Domain, config.auth0ClientId),
        audience: config.auth0Audience,
      ),
    );
    final client = RitualInvestingApiClient(
      basePathOverride: config.apiBaseUrl,
      interceptors: [RitualAuthInterceptor(tokenProvider: auth)],
    );
    return DependencyContainer(
      authController: auth,
      dailyRitualController: DailyRitualController(
        repository: DailyRitualRepository(
          service: GeneratedRitualApiService(client),
          cache: cache,
        ),
      ),
      discoverController: DiscoverController(
        repository: CachedDiscoverRepository(
          service: GeneratedDiscoverApiService(client),
          cache: cache,
        ),
      ),
      covenController: CovenController(
        repository: CachedCovenRepository(
          service: GeneratedCovenApiService(client),
          cache: cache,
        ),
      ),
      profileController: ProfileController(
        repository: CachedProfileRepository(
          service: GeneratedProfileApiService(client),
          cache: cache,
        ),
      ),
      portfolioController: PortfolioController(
        repository: CachedPortfolioRepository(
          service: GeneratedPortfolioApiService(client),
          cache: cache,
        ),
      ),
      cache: cache,
    );
  }

  factory DependencyContainer.fixture({
    ReadCache? cache,
    SessionRepository? sessionRepository,
  }) {
    final fixtureCache = cache ?? MemoryReadCache();
    return DependencyContainer(
      authController: AuthController(
        repository: sessionRepository ?? _FixtureSessionRepository(),
      ),
      dailyRitualController: DailyRitualController(
        repository: DailyRitualRepository(
          service: _FixtureRitualService(),
          cache: fixtureCache,
        ),
      ),
      discoverController: DiscoverController(
        repository: CachedDiscoverRepository(
          service: _FixtureDiscoverService(),
          cache: fixtureCache,
        ),
      ),
      covenController: CovenController(
        repository: CachedCovenRepository(
          service: _FixtureCovenService(),
          cache: fixtureCache,
        ),
      ),
      profileController: ProfileController(
        repository: CachedProfileRepository(
          service: _FixtureProfileService(),
          cache: fixtureCache,
        ),
      ),
      portfolioController: PortfolioController(
        repository: CachedPortfolioRepository(
          service: _FixturePortfolioService(),
          cache: fixtureCache,
        ),
      ),
      cache: fixtureCache,
    );
  }
}

class _FixtureSessionRepository implements SessionRepository {
  @override
  Future<AuthSession?> credentials() async =>
      const AuthSession(accessToken: 'fixture');
  @override
  Future<AuthSession> login() async =>
      const AuthSession(accessToken: 'fixture');
  @override
  Future<void> logout() async {}
}

class _FixtureRitualService implements DailyRitualService {
  @override
  Future<DailyRitual> fetchDaily() async => DailyRitual(
    assignmentId: '00000000-0000-4000-8000-000000000101',
    date: DateTime.utc(2026, 8, 20),
    mode: DailyRitualMode.tarot,
    revision: const RitualRevision(
      id: '10000000-0000-4000-8000-000000000001',
      number: 1,
    ),
    title: 'Direction, not urgency.',
    art: const RitualArt(
      key: 'the_compass',
      alt: 'The Compass tarot card: a woman holding a lantern at a celestial crossroads',
    ),
    interpretation: 'The strongest path today rewards patience. Favor durable momentum; let noisy names pass without you.',
    guidance: 'Inspect the evidence, compare risks, and choose whether any research path deserves more attention.',
    marketLabel: 'Market-informed · reveal the pattern',
    ideas: const [
      RitualIdea(
        assetId: '20000000-0000-4000-8000-000000000001',
        symbol: 'VIG',
        name: 'Vanguard Dividend Appreciation ETF',
        appearanceReason: 'steady wealth',
        riskSummary: 'Short windows can reverse.',
        changeLabel: '+0.42%',
      ),
      RitualIdea(
        assetId: '20000000-0000-4000-8000-000000000002',
        symbol: 'XLV',
        name: 'Health Care Select Sector SPDR Fund',
        appearanceReason: 'defensive orbit',
        riskSummary: 'Sector concentration can underperform.',
        changeLabel: '+0.31%',
      ),
      RitualIdea(
        assetId: '20000000-0000-4000-8000-000000000003',
        symbol: 'WOMN',
        name: "Impact Shares YWCA Women's Empowerment ETF",
        appearanceReason: 'leadership ETF',
        riskSummary: 'The observation may not generalize.',
        changeLabel: '+0.27%',
      ),
    ],
    evidence: [
      RitualEvidence(
        claimId: '21000000-0000-4000-8000-000000000001',
        factorLabel: 'Durable dividend momentum',
        observedAt: DateTime.utc(2026, 8, 20, 13, 35),
        summary: 'Lower volatility and durable dividend momentum in the scenario window.',
        uncertainty: 'Uncertainty remains high: the scenario is simulated, prices are fictional, and short-term conditions can reverse.',
      ),
      RitualEvidence(
        claimId: '21000000-0000-4000-8000-000000000002',
        factorLabel: 'Defensive relative strength',
        observedAt: DateTime.utc(2026, 8, 20, 13, 35),
        summary: 'Defensive relative strength in the scenario window.',
        uncertainty: 'Short windows can reverse.',
      ),
      RitualEvidence(
        claimId: '21000000-0000-4000-8000-000000000003',
        factorLabel: 'Positive breadth',
        observedAt: DateTime.utc(2026, 8, 20, 13, 35),
        summary: 'Broad leadership exposure with positive breadth.',
        uncertainty: 'The observation may not generalize.',
      ),
    ],
    rowan: const RitualCounsel(
      scriptRevisionId: '10000000-0000-4000-8000-000000000002',
      surface: 'daily_ritual',
      body: 'I’ll show you what changed beneath the reading.',
      riskFooter: 'This deterministic demo explains uncertainty and never tells you to trade.',
    ),
    version: 1,
    state: DailyRitualState.assigned,
    revealedAt: null,
    completedAt: null,
    demo: RitualDisclosure(
      isDemo: true,
      observedAt: DateTime.utc(2026, 8, 20, 13, 35),
      sourceLabel: 'Ritual deterministic demonstration',
      limitations: const [
        'Deterministic demo data; prices and signals are fictional.',
        'Educational exploration only; not investment advice.',
      ],
    ),
  );
}

class _FixtureDiscoverService implements DiscoverService {
  @override
  Future<DiscoverModel> fetch() async => DiscoverModel(
    grimoires: const [
      DiscoverCard(title: 'Quiet Power', subtitle: 'Durability over drama'),
      DiscoverCard(title: 'New Moons', subtitle: 'Early themes to study'),
      DiscoverCard(title: 'Long Horizon', subtitle: 'Patient compounding'),
    ],
    circles: const [
      DiscoverCard(
        title: 'Soft Power Portfolio',
        subtitle: 'A fictional curator’s diversified demo circle',
      ),
      DiscoverCard(
        title: 'Climate Keepers',
        subtitle: 'Themes to compare, edit, and save locally',
      ),
    ],
  );
}

class _FixtureCovenService implements CovenService {
  @override
  Future<CovenModel> fetch() async => CovenModel(
    entries: [
      CovenEntry(
        name: 'Aurora Healthworks',
        symbol: 'AURA',
        category: 'Woman founder',
        focus: 'Preventive health technology',
        effectiveDate: DateTime.utc(2026, 8, 20),
        verifiedAsOf: DateTime.utc(2026, 8, 20),
      ),
      CovenEntry(
        name: 'Juniper Robotics',
        symbol: 'JNPR',
        category: 'Woman chief executive',
        focus: 'Industrial automation',
        effectiveDate: DateTime.utc(2026, 8, 20),
        verifiedAsOf: DateTime.utc(2026, 8, 20),
      ),
      CovenEntry(
        name: 'Morrow Energy',
        symbol: 'MROW',
        category: 'Women-owned',
        focus: 'Distributed clean energy',
        effectiveDate: DateTime.utc(2026, 8, 20),
        verifiedAsOf: DateTime.utc(2026, 8, 20),
      ),
      CovenEntry(
        name: 'Thistle Foods',
        symbol: 'THST',
        category: 'Woman founder',
        focus: 'Sustainable nutrition',
        effectiveDate: DateTime.utc(2026, 8, 20),
        verifiedAsOf: DateTime.utc(2026, 8, 20),
      ),
    ],
  );
}

class _FixtureProfileService implements ProfileService {
  @override
  Future<ProfileModel> fetch() async =>
      const ProfileModel(displayName: 'Ritual Member');
}

class _FixturePortfolioService implements PortfolioService {
  @override
  Future<PortfolioCollection> fetch() async => const PortfolioCollection(
    items: [
      PortfolioSummary(
        id: '00000000-0000-4000-8000-000000000601',
        name: 'Demo Portfolio',
        cashMinor: 100000,
        valuationMinor: 100000,
        version: 1,
        ledgerWatermark: 0,
      ),
    ],
  );

  @override
  Future<ContributionReceipt> contribute({
    required String portfolioId,
    required String sourceId,
    required int minorUnits,
    required String idempotencyKey,
  }) async => const ContributionReceipt(
    commandId: '00000000-0000-4000-8000-000000000602',
    portfolioVersion: 2,
  );
}
