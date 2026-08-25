import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/bootstrap/entry_coordinator.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/asset_codex/data/repository.dart';
import 'package:ritual_investing_app/features/asset_codex/domain/model.dart';
import 'package:ritual_investing_app/features/briefings/application/briefing_controller.dart';
import 'package:ritual_investing_app/features/briefings/data/repository.dart';
import 'package:ritual_investing_app/features/briefings/domain/model.dart';
import 'package:ritual_investing_app/features/coven/application/controller.dart';
import 'package:ritual_investing_app/features/coven/data/repository.dart';
import 'package:ritual_investing_app/features/coven/domain/model.dart';
import 'package:ritual_investing_app/features/circles/data/repository.dart';
import 'package:ritual_investing_app/features/circles/domain/model.dart';
import 'package:ritual_investing_app/features/creators/data/repository.dart';
import 'package:ritual_investing_app/features/discover/application/controller.dart';
import 'package:ritual_investing_app/features/discover/data/repository.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';
import 'package:ritual_investing_app/features/entitlements/application/entitlement_controller.dart';
import 'package:ritual_investing_app/features/entitlements/data/repository.dart';
import 'package:ritual_investing_app/features/entitlements/domain/model.dart';
import 'package:ritual_investing_app/features/grimoires/data/repository.dart';
import 'package:ritual_investing_app/features/grimoires/domain/model.dart';
import 'package:ritual_investing_app/features/notifications/application/notification_controller.dart';
import 'package:ritual_investing_app/features/notifications/data/repository.dart';
import 'package:ritual_investing_app/features/notifications/domain/model.dart';
import 'package:ritual_investing_app/features/orders/application/order_controller.dart';
import 'package:ritual_investing_app/features/orders/data/repository.dart';
import 'package:ritual_investing_app/features/orders/domain/model.dart';
import 'package:ritual_investing_app/features/funding/application/contribution_controller.dart';
import 'package:ritual_investing_app/features/funding/application/funding_source_controller.dart';
import 'package:ritual_investing_app/features/funding/data/repository.dart';
import 'package:ritual_investing_app/features/funding/domain/model.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';
import 'package:ritual_investing_app/features/privacy/application/privacy_controller.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/rebalancing/application/rebalance_controller.dart';
import 'package:ritual_investing_app/features/rebalancing/data/repository.dart';
import 'package:ritual_investing_app/features/rebalancing/domain/model.dart';
import 'package:ritual_investing_app/features/recurring/application/recurring_plan_controller.dart';
import 'package:ritual_investing_app/features/recurring/data/repository.dart';
import 'package:ritual_investing_app/features/recurring/domain/model.dart';
import 'package:ritual_investing_app/features/profile/application/controller.dart';
import 'package:ritual_investing_app/features/profile/data/repository.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';

class FeatureLoadTracker {
  final Map<MemberBranch, int> _counts = {};

  int count(MemberBranch branch) => _counts[branch] ?? 0;
  void hit(MemberBranch branch) =>
      _counts.update(branch, (value) => value + 1, ifAbsent: () => 1);
}

DependencyContainer fixtureContainer({
  ScopedReadCacheStorage? cache,
  AuthController? authController,
  SessionRepository? sessionRepository,
  SessionBootstrapService? sessionBootstrapService,
  FeatureLoadTracker? loadTracker,
  PendingCommandStore? pendingCommandStore,
  EntryCoordinator? entryCoordinator,
  bool includeU7 = false,
  bool includeU9 = false,
  bool includeU10 = false,
  bool includeU11 = false,
  PrivacyRepository? privacyRepository,
}) {
  final storage = cache ?? MemoryReadCache();
  final tracker = loadTracker ?? FeatureLoadTracker();
  final memberState = _FixtureMemberState();
  final commands =
      pendingCommandStore ??
      PendingCommandStore(storage: _MemoryProtectedStorage());
  return DependencyContainer(
    authController:
        authController ??
        AuthController(
          repository: sessionRepository ?? _FixtureSessionRepository(),
        ),
    sessionBootstrapService:
        sessionBootstrapService ?? _FixtureSessionBootstrapService(memberState),
    cacheStorage: storage,
    pendingCommandStore: commands,
    entryCoordinator: entryCoordinator,
    featureScopeFactory: (scope, scopedCache, bootstrap) {
      final covenRepository = CovenRepository(
        service: _FixtureCovenService(tracker),
        cache: scopedCache,
      );
      final financeService = _FixturePortfolioService();
      final portfolioController = PortfolioController(
        repository: CachedPortfolioRepository(
          service: financeService,
          cache: scopedCache,
        ),
        bootstrapDefaultPortfolioId: bootstrap.defaultPortfolioId,
        createKey: () => 'fixture-portfolio-key',
      );
      final fundingRepository = CachedFundingRepository(
        service: financeService,
        cache: scopedCache,
      );
      final invalidationBus = InvalidationBus();
      final orderController = includeU7
          ? OrderController(
              repository: OrderRepository(service: _FixtureOrderService()),
              portfolioController: portfolioController,
              pendingStore: commands,
              invalidationBus: invalidationBus,
              scope: scope,
              createKey: () => 'fixture-order-key-01',
              now: () => DateTime.utc(2026, 8, 25, 12),
            )
          : null;
      final recurringPlanController = includeU7
          ? RecurringPlanController(
              repository: RecurringPlanRepository(
                service: _FixtureRecurringService(),
              ),
              pendingStore: commands,
              scope: scope,
              createKey: () => 'fixture-recurring-1',
              now: () => DateTime.utc(2026, 8, 25, 12),
              rhythm: bootstrap.personalization.contributionRhythm,
              isFundingSourceActive: (_) async => true,
            )
          : null;
      final rebalanceController = includeU7
          ? RebalanceController(
              repository: RebalanceRepository(
                service: _FixtureRebalanceService(),
              ),
              portfolioController: portfolioController,
              pendingStore: commands,
              invalidationBus: invalidationBus,
              scope: scope,
              createKey: () => 'fixture-rebalance-1',
              now: () => DateTime.utc(2026, 8, 25, 12),
            )
          : null;
      final briefingController = includeU9
          ? BriefingController(
              repository: CachedBriefingRepository(
                service: _FixtureBriefingService(),
                cache: scopedCache,
              ),
              invalidationBus: invalidationBus,
              scope: scope,
              personalization: bootstrap.personalization,
            )
          : null;
      final notificationController = includeU9
          ? NotificationController(
              repository: CachedNotificationRepository(
                service: _FixtureNotificationService(),
                cache: scopedCache,
              ),
              pendingStore: commands,
              invalidationBus: invalidationBus,
              scope: scope,
              createKey: () => 'fixture-read-all-key-01',
              now: () => DateTime.utc(2026, 8, 25, 12),
              personalization: bootstrap.personalization,
            )
          : null;
      final entitlementController = includeU10
          ? EntitlementController(
              repository: CachedEntitlementRepository(
                service: _FixtureEntitlementService(),
                cache: scopedCache,
              ),
              pendingStore: commands,
              scope: scope,
              createKey: () => 'fixture-membership-key-0001',
              now: () => DateTime.utc(2026, 8, 25, 12),
              personalization: bootstrap.personalization,
            )
          : null;
      final privacyController = includeU11
          ? PrivacyController(
              repository:
                  privacyRepository ??
                  (throw ArgumentError(
                    'privacyRepository is required when U11 is enabled.',
                  )),
              pendingStore: commands,
              scope: scope,
              createKey: () => 'fixture-privacy-key-00001',
              reauthenticate: () async {},
              onDeletionAccepted: () async {},
              onResetAccepted: (_) async {},
              personalization: bootstrap.personalization,
            )
          : null;
      return MemberFeatureScope(
        scope: scope,
        dailyRitualController: DailyRitualController(
          repository: DailyRitualRepository(
            service: _FixtureRitualService(tracker),
            cache: scopedCache,
          ),
        ),
        discoverController: DiscoverController(
          repository: CachedDiscoverRepository(
            service: _FixtureDiscoverService(tracker),
            cache: scopedCache,
          ),
          personalization: bootstrap.personalization,
        ),
        covenController: CovenController(repository: covenRepository),
        profileController: ProfileController(
          repository: CachedProfileRepository(
            service: _FixtureProfileService(tracker, memberState),
            cache: scopedCache,
          ),
        ),
        portfolioController: portfolioController,
        fundingSourceController: FundingSourceController(
          repository: fundingRepository,
          createKey: () => 'fixture-source-key',
        ),
        contributionController: ContributionController(
          repository: fundingRepository,
          portfolioController: portfolioController,
          pendingStore: commands,
          invalidationBus: invalidationBus,
          scope: scope,
          createKey: () => 'fixture-contribution-key',
          now: () => DateTime.utc(2026, 8, 25),
          rhythm: bootstrap.personalization.contributionRhythm,
        ),
        invalidationBus: invalidationBus,
        orderController: orderController,
        recurringPlanController: recurringPlanController,
        rebalanceController: rebalanceController,
        briefingController: briefingController,
        notificationController: notificationController,
        entitlementController: entitlementController,
        privacyController: privacyController,
        assetCodexRepository: AssetCodexRepository(
          service: _FixtureAssetCodexService(),
          cache: scopedCache,
        ),
        covenRepository: covenRepository,
        grimoireRepository: GrimoireRepository(
          service: _FixtureGrimoireService(),
          cache: scopedCache,
        ),
        circleRepository: CircleRepository(
          service: _FixtureCircleService(),
          cache: scopedCache,
        ),
        creatorRepository: CreatorRepository(
          service: _FixtureCreatorService(),
          cache: scopedCache,
        ),
      );
    },
  );
}

class _FixtureMemberState {
  ProfileTheme theme = ProfileTheme.system;
}

class _FixtureSessionBootstrapService implements SessionBootstrapService {
  _FixtureSessionBootstrapService(this.state);
  final _FixtureMemberState state;

  @override
  Future<MemberBootstrap> bootstrap() async => MemberBootstrap(
    accountId: 'fixture-account',
    resetGeneration: 0,
    onboarding: const MemberOnboardingGate.complete(),
    entitlement: const MemberEntitlement(
      planCode: 'demo-free',
      status: MemberEntitlementStatus.active,
    ),
    defaultPortfolioId: 'fixture-portfolio',
    serverTime: DateTime.utc(2026, 8, 24),
    contractVersion: '1.0.0',
    themePreference: switch (state.theme) {
      ProfileTheme.system => MemberThemePreference.system,
      ProfileTheme.light => MemberThemePreference.light,
      ProfileTheme.dark => MemberThemePreference.dark,
    },
  );
}

class _FixtureSessionRepository implements SessionRepository {
  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(authorizedParty: 'fixture-client');

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  Future<AuthSession?> recover() async =>
      const AuthSession(accessToken: 'fixture');
  @override
  Future<AuthSession> authenticate(MemberAuthIntent intent) async =>
      const AuthSession(accessToken: 'fixture');
  @override
  Future<void> logout() async {}
}

class _MemoryProtectedStorage implements ProtectedStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FixtureEntitlementService implements EntitlementService {
  DemoEntitlement _entitlement = DemoEntitlement(
    id: '00000000-0000-4000-8000-000000000701',
    planCode: DemoPlanCode.free,
    status: DemoEntitlementStatus.active,
    startsAt: DateTime.utc(2026, 8, 1),
    version: 1,
    disclosure: _membershipDisclosure,
  );
  DemoCheckout _checkout = DemoCheckout(
    id: '00000000-0000-4000-8000-000000000702',
    planCode: DemoPlanCode.premiumDemo,
    status: DemoCheckoutStatus.open,
    expiresAt: DateTime.utc(2026, 8, 25, 13),
    version: 1,
    disclosure: _membershipDisclosure,
  );

  @override
  Future<List<DemoPlan>> listPlans() async => [
    DemoPlan(
      code: DemoPlanCode.free,
      displayName: 'Ritual Free Demo',
      priceCopy: 'No charge — simulated access only',
      capabilityCodes: {'daily_ritual', 'demo_portfolio'},
      disclosure: _membershipDisclosure,
    ),
    DemoPlan(
      code: DemoPlanCode.premiumDemo,
      displayName: 'Ritual Premium Demo',
      priceCopy: 'Illustrative premium access — no charge',
      capabilityCodes: {'daily_ritual', 'demo_portfolio', 'future_mirror'},
      disclosure: _membershipDisclosure,
    ),
  ];

  @override
  Future<DemoEntitlement> getEntitlement() async => _entitlement;

  @override
  Future<DemoCheckout> getCheckout(String sessionId) async => _checkout;

  @override
  Future<DemoCheckout> createCheckout(String planCode, String key) async =>
      _checkout;

  @override
  Future<DemoEntitlement> confirmCheckout(
    String sessionId,
    int expectedVersion,
    String key,
  ) async {
    _checkout = DemoCheckout(
      id: _checkout.id,
      planCode: DemoPlanCode.premiumDemo,
      status: DemoCheckoutStatus.completed,
      expiresAt: _checkout.expiresAt,
      version: expectedVersion + 1,
      disclosure: _membershipDisclosure,
    );
    _entitlement = DemoEntitlement(
      id: '00000000-0000-4000-8000-000000000703',
      planCode: DemoPlanCode.premiumDemo,
      status: DemoEntitlementStatus.active,
      startsAt: DateTime.utc(2026, 8, 25, 12),
      version: 2,
      disclosure: _membershipDisclosure,
    );
    return _entitlement;
  }

  @override
  Future<DemoEntitlement> restore(String key) async => _entitlement;

  @override
  Future<DemoEntitlement> downgrade(int expectedVersion, String key) async {
    _entitlement = DemoEntitlement(
      id: '00000000-0000-4000-8000-000000000704',
      planCode: DemoPlanCode.free,
      status: DemoEntitlementStatus.active,
      startsAt: DateTime.utc(2026, 8, 25, 12),
      version: expectedVersion + 1,
      disclosure: _membershipDisclosure,
    );
    return _entitlement;
  }
}

final _membershipDisclosure = DemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Ritual deterministic Demo',
  limitations: [
    'No money moves and no external financial provider is contacted.',
  ],
);

class _FixtureRitualService implements DailyRitualService {
  _FixtureRitualService(this.tracker);
  final FeatureLoadTracker tracker;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async {
    tracker.hit(MemberBranch.ritual);
    return DailyRitual(
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
      version: 3,
      state: DailyRitualState.completed,
      revealedAt: DateTime.utc(2026, 8, 20, 13, 40),
      completedAt: DateTime.utc(2026, 8, 20, 13, 55),
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

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) => fetchDaily();

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(
    String assignmentId,
  ) async => [
    RitualEvidenceDetail(
      claimId: '21000000-0000-4000-8000-000000000001',
      factorLabel: 'Durable dividend momentum',
      observedAt: DateTime.utc(2026, 8, 20, 13, 35),
      summary: 'Lower volatility and durable dividend momentum in the scenario window.',
      uncertainty:
          'The scenario is simulated and short-term conditions can reverse.',
      source: RitualEvidenceSource(
        publisher: 'Demo Research Desk',
        title: 'Provider-free scenario note',
        url: Uri.parse('https://example.invalid/ritual-evidence'),
        publishedAt: DateTime.utc(2026, 8, 20, 13),
      ),
    ),
  ];

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      RitualHistoryPage(items: const [], nextCursor: null, hasMore: false);

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) => fetchDaily();

  @override
  Future<DailyRitual> complete(String assignmentId, int version) =>
      fetchDaily();
}

class _FixtureDiscoverService implements DiscoverService {
  _FixtureDiscoverService(this.tracker);
  final FeatureLoadTracker tracker;
  @override
  Future<DiscoverModel> fetch() async {
    tracker.hit(MemberBranch.discover);
    return DiscoverModel(
      items: [
        DiscoverItemView(
          id: '00000000-0000-4000-8000-000000000501',
          revisionId: '00000000-0000-4000-8000-000000000502',
          slug: 'quiet-power',
          kind: DiscoverItemKind.asset,
          title: 'Quiet Power',
          subtitle: 'Durability over drama',
          appearanceReason: 'Deterministic fixture research.',
          demo: _fixtureResearchDemo,
        ),
      ],
      creators: const [],
      nextCursor: null,
      hasMore: false,
    );
  }
}

class _FixtureCovenService implements CovenService {
  _FixtureCovenService(this.tracker);
  final FeatureLoadTracker tracker;
  bool saved = false;
  @override
  Future<CovenModel> fetch() async {
    tracker.hit(MemberBranch.coven);
    return CovenModel(
      entries: List.generate(
        4,
        (index) => CovenEntry(
          id: '00000000-0000-4000-8000-00000000051$index',
          revisionId: '00000000-0000-4000-8000-00000000052$index',
          slug: 'aurora-healthworks-$index',
          name: 'Aurora Healthworks $index',
          symbol: 'AUR$index',
          category: CovenQualificationCategory.founder,
          focus: 'Preventive health technology',
          teaser: 'Fictional provider-free qualification.',
          effectiveDate: DateTime.utc(2026, 8, 20),
          verifiedAsOf: DateTime.utc(2026, 8, 20),
          demo: _fixtureCovenDemo,
        ),
      ),
    );
  }

  @override
  Future<CovenDetail> fetchDetail(String entryId) async => CovenDetail(
    id: entryId,
    revisionId: '00000000-0000-4000-8000-000000000520',
    slug: 'aurora-healthworks',
    company: 'Aurora Healthworks',
    symbol: 'AUR',
    focus: 'Preventive health technology',
    summary: 'Fictional provider-free company research.',
    inclusionRationale: 'Dated founder evidence is present.',
    limitations: 'Demo only; not investment advice.',
    qualifications: [
      CovenQualification(
        category: CovenQualificationCategory.founder,
        personName: 'Avery North',
        effectiveDate: DateTime.utc(2026, 8, 20),
        verifiedAsOf: DateTime.utc(2026, 8, 20),
        validTo: null,
        evidence: const [],
      ),
    ],
    evidence: await fetchEvidence(entryId),
    saved: saved,
    demo: _fixtureCovenDemo,
  );

  @override
  Future<List<CovenEvidenceDetail>> fetchEvidence(String entryId) async => [
    CovenEvidenceDetail(
      claimId: '00000000-0000-4000-8000-000000000530',
      factorLabel: 'Founder qualification',
      observedAt: DateTime.utc(2026, 8, 20),
      summary: 'Fixture founder record.',
      uncertainty: 'Fictional evidence can be revised.',
      publisher: 'Demo Registry',
      sourceTitle: 'Fixture founder record',
      sourceUrl: Uri.parse('https://example.invalid/coven'),
      publishedAt: DateTime.utc(2026, 8, 20),
    ),
  ];

  @override
  Future<void> save(String entryId) async => saved = true;

  @override
  Future<void> unsave(String entryId) async => saved = false;
}

final _fixtureResearchDemo = ResearchDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 20),
  sourceLabel: 'Deterministic fixture',
  limitations: const ['Fictional provider-free research.'],
);

final _fixtureCovenDemo = CovenDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 20),
  sourceLabel: 'Deterministic fixture',
  limitations: const ['Fictional provider-free qualification.'],
);

class _FixtureGrimoireService implements GrimoireService {
  bool saved = false;

  @override
  Future<GrimoireDetail> fetchDetail(String grimoireId) async => GrimoireDetail(
    id: grimoireId,
    revisionId: '00000000-0000-4000-8000-000000000541',
    slug: 'quiet-power',
    title: 'Quiet Power Grimoire',
    description: 'Fictional read-only provider-free research.',
    theme: 'durability',
    curatorLabel: 'Ritual Research Desk',
    assets: [
      GrimoireAssetReference(
        id: '00000000-0000-4000-8000-000000000501',
        revisionId: '00000000-0000-4000-8000-000000000502',
        slug: 'quiet-power',
        symbol: 'QPW',
        name: 'Quiet Power',
        appearanceReason: 'Deterministic fixture research.',
        demo: _fixtureResearchDemo,
      ),
    ],
    saved: saved,
    demo: _fixtureResearchDemo,
  );

  @override
  Future<void> save(String grimoireId) async => saved = true;

  @override
  Future<void> unsave(String grimoireId) async => saved = false;
}

class _FixtureCreatorService implements CreatorService {
  @override
  Future<SeededCreatorView> fetchById(String creatorId) async =>
      SeededCreatorView(
        id: creatorId,
        slug: 'mira-vale',
        displayName: 'Mira Vale',
        bio: 'A fictional deterministic research curator.',
        isFictional: true,
        demo: _fixtureResearchDemo,
      );
}

class _FixtureAssetCodexService implements AssetCodexService {
  bool saved = false;

  @override
  Future<AssetCodex> fetchDetail(String assetId) async => AssetCodex(
    id: assetId,
    revisionId: '00000000-0000-4000-8000-000000000502',
    slug: 'quiet-power',
    symbol: 'QPW',
    name: 'Quiet Power',
    kind: AssetKind.etf,
    currency: 'USD',
    appearanceReason: 'Deterministic provider-free fixture.',
    thesis: 'A fictional durability scenario.',
    limitations: 'No live price or provider connection.',
    metricsAsOf: DateTime.utc(2026, 8, 25, 12),
    evidence: const [],
    detailedEvidence: const [],
    risks: const [],
    saved: saved,
    demo: _fixtureAssetDemo,
    source: const AssetSourceContext(kind: AssetSourceKind.direct),
  );

  @override
  Future<List<AssetEvidenceDetail>> fetchEvidence(String assetId) async =>
      const [];

  @override
  Future<List<AssetMetric>> fetchMetrics(String assetId) async => [
    AssetMetric(
      priceMinor: 10000,
      changeBps: 0,
      expenseRatioBps: 10,
      observedAt: DateTime.utc(2026, 8, 25, 12),
      sourceLabel: 'Deterministic fixture',
      demo: _fixtureAssetDemo,
    ),
  ];

  @override
  Future<AssetComparison> compare(List<String> assetIds) async =>
      AssetComparison(
        items: const [],
        comparedAt: DateTime.utc(2026, 8, 25, 12),
        demo: _fixtureAssetDemo,
      );

  @override
  Future<void> save(String assetId, AssetSourceContext source) async =>
      saved = true;

  @override
  Future<void> unsave(String assetId) async => saved = false;
}

final _fixtureAssetDemo = AssetDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Deterministic Asset Codex fixture',
  limitations: const ['Fictional scenario; no live market provider.'],
);

class _FixtureCircleService implements CircleService {
  bool templateSaved = false;
  late PrivateCircle current = _circle();

  @override
  Future<CircleCollection> fetchList({required bool includeArchived}) async =>
      CircleCollection(items: [current], nextCursor: null, hasMore: false);

  @override
  Future<PrivateCircle> fetchDetail(String circleId) async => current;

  @override
  Future<PrivateCircle> create(CircleCreateCommand command) async {
    current = _circle(title: command.title, description: command.description);
    return current;
  }

  @override
  Future<PrivateCircle> copy(CircleCopyCommand command) async {
    current = _circle(
      title: command.title ?? 'Soft Power Circle',
      sourceTemplateId: command.templateId,
    );
    return current;
  }

  @override
  Future<PrivateCircle> patch(
    String circleId,
    int expectedVersion,
    CircleDraft draft,
  ) async {
    current = _circle(
      title: draft.title,
      description: draft.description,
      version: expectedVersion + 1,
      assets: current.assets,
    );
    return current;
  }

  @override
  Future<PrivateCircle> replaceAssets(
    String circleId,
    int expectedVersion,
    List<CircleAsset> assets,
  ) async {
    current = _circle(version: expectedVersion + 1, assets: assets);
    return current;
  }

  @override
  Future<PrivateCircle> putAsset(
    String circleId,
    int expectedVersion,
    CircleAsset asset,
  ) async {
    current = _circle(
      version: expectedVersion + 1,
      assets: [
        for (final existing in current.assets)
          if (existing.assetId == asset.assetId) asset else existing,
        if (!current.assets.any((value) => value.assetId == asset.assetId))
          asset,
      ],
    );
    return current;
  }

  @override
  Future<PrivateCircle> removeAsset(
    String circleId,
    int expectedVersion,
    String assetId,
  ) async {
    current = _circle(
      version: expectedVersion + 1,
      assets: current.assets
          .where((asset) => asset.assetId != assetId)
          .toList(growable: false),
    );
    return current;
  }

  @override
  Future<void> archive(String circleId, int expectedVersion) async {
    current = _circle(
      version: expectedVersion + 1,
      assets: current.assets,
      archivedAt: DateTime.utc(2026, 8, 25),
    );
  }

  @override
  Future<CircleTemplateDetail> fetchTemplate(String templateId) async =>
      CircleTemplateDetail(
        id: templateId,
        revisionId: '00000000-0000-4000-8000-000000000551',
        slug: 'soft-power-circle',
        title: 'Soft Power Circle',
        description: 'Fictional read-only seeded research.',
        theme: 'leadership',
        creator: await _FixtureCreatorService().fetchById(
          '00000000-0000-4000-8000-000000000552',
        ),
        assets: [
          CircleTemplateAsset(
            id: '00000000-0000-4000-8000-000000000501',
            revisionId: '00000000-0000-4000-8000-000000000502',
            slug: 'quiet-power',
            symbol: 'QPW',
            name: 'Quiet Power',
            appearanceReason: 'Deterministic fixture research.',
            note: 'Read the limitations.',
            ordinal: 1,
            weightBps: 10000,
            demo: _fixtureResearchDemo,
          ),
        ],
        saved: templateSaved,
        demo: _fixtureResearchDemo,
      );

  @override
  Future<void> saveTemplate(String templateId) async => templateSaved = true;

  @override
  Future<void> unsaveTemplate(String templateId) async => templateSaved = false;
}

PrivateCircle _circle({
  String title = 'Private research',
  String description = 'Editable only by this member.',
  int version = 2,
  List<CircleAsset>? assets,
  String? sourceTemplateId,
  DateTime? archivedAt,
}) => PrivateCircle(
  id: '00000000-0000-4000-8000-000000000560',
  title: title,
  description: description,
  private: true,
  version: version,
  assets:
      assets ??
      const [
        CircleAsset(
          assetId: '00000000-0000-4000-8000-000000000501',
          ordinal: 1,
          note: 'Private fixture note.',
          weightBps: 10000,
        ),
      ],
  sourceTemplateId: sourceTemplateId,
  sourceRevisionId: sourceTemplateId == null
      ? null
      : '00000000-0000-4000-8000-000000000551',
  archivedAt: archivedAt,
);

class _FixtureProfileService implements ProfileService {
  _FixtureProfileService(this.tracker, this.state);
  final FeatureLoadTracker tracker;
  final _FixtureMemberState state;
  @override
  Future<ProfileModel> fetch() async {
    tracker.hit(MemberBranch.you);
    return ProfileModel(
      displayName: 'Ritual Member',
      profileVersion: 1,
      preferences: SavedRitualPreferences(
        locale: 'en-US',
        timezone: 'America/New_York',
        ritualMode: ProfileRitualMode.tarot,
        theme: state.theme,
        version: 1,
      ),
    );
  }

  @override
  Future<void> patchPreferences(ProfilePreferencesUpdate update) async {
    state.theme = update.theme ?? state.theme;
  }

  @override
  Future<void> putInvestor(ProfileInvestorUpdate update) async {}

  @override
  Future<ProfileConsentReceipt> putAstrology(
    ProfileAstrologyUpdate update,
  ) async => ProfileConsentReceipt(
    id: 'fixture-consent',
    decision: ProfileConsentDecision.accepted,
    policyVersion: '2026-08',
    recordedAt: DateTime.utc(2026, 8, 25),
  );

  @override
  Future<ProfileConsentReceipt> deleteAstrology({
    required int expectedVersion,
  }) async => ProfileConsentReceipt(
    id: 'fixture-consent',
    decision: ProfileConsentDecision.withdrawn,
    policyVersion: '2026-08',
    recordedAt: DateTime.utc(2026, 8, 25),
  );
}

class _FixturePortfolioService implements PortfolioService, FundingService {
  static const assetId = '00000000-0000-4000-8000-000000000604';
  static final portfolio = PortfolioSummary(
    id: '00000000-0000-4000-8000-000000000601',
    name: 'Demo Portfolio',
    cashMinor: 100000,
    valuationMinor: 100000,
    currency: PortfolioCurrency.usd,
    status: PortfolioStatus.active,
    isDefault: true,
    version: 1,
    ledgerWatermark: 0,
    asOfTransactionId: null,
    demo: PortfolioDemoDisclosure(
      isDemo: true,
      observedAt: DateTime.utc(2026, 8, 25),
      sourceLabel: 'Fixture Demo ledger',
      limitations: const ['No real money moves.'],
    ),
    targetAllocation: const [],
  );

  static final fundingDemo = FundingDemoDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25),
    sourceLabel: 'Fixture Demo ledger',
    limitations: const ['No real money moves.'],
  );

  @override
  Future<PortfolioCollection> fetchList() async =>
      PortfolioCollection(items: [portfolio]);
  @override
  Future<PortfolioSummary> fetchDetail(String portfolioId) async => portfolio;
  @override
  Future<List<PortfolioHolding>> fetchHoldings(String portfolioId) async =>
      const [
        PortfolioHolding(
          assetId: assetId,
          symbol: 'VIG',
          quantityValue: '1.250000',
          quantityScale: 6,
          marketValueMinor: 2500,
          currency: PortfolioCurrency.usd,
          ledgerWatermark: 1,
          asOfTransactionId: 'fixture-transaction-1',
        ),
      ];
  @override
  Future<List<PortfolioActivityEntry>> fetchActivity(
    String portfolioId,
  ) async => const [];
  @override
  Future<List<PortfolioSnapshotView>> fetchSnapshots(
    String portfolioId,
  ) async => const [];
  @override
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  }) async => portfolio;
  @override
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  }) async => portfolio;
  @override
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
  }) async {}
  @override
  Future<List<FundingSource>> fetchSources() async => [
    FundingSource(
      id: '00000000-0000-4000-8000-000000000603',
      fixture: FundingFixture.moonReserve,
      displayLabel: 'Moon Reserve (fictional)',
      fictionalLast4: '1108',
      status: FundingSourceStatus.active,
      demo: fundingDemo,
    ),
  ];
  @override
  Future<FundingSource> createSource({
    required FundingFixture fixture,
    required String idempotencyKey,
  }) async => (await fetchSources()).single;
  @override
  Future<void> deleteSource(String sourceId) async {}
  @override
  Future<ContributionReceipt> contribute(ContributionCommand command) async =>
      ContributionReceipt(
        commandId: '00000000-0000-4000-8000-000000000602',
        portfolioVersion: 2,
        ledgerTransactionIds: const [],
        demo: fundingDemo,
      );
}

class _FixtureOrderService implements OrderService {
  @override
  Future<List<OrderView>> list(String portfolioId) async => const [];
  @override
  Future<OrderView> get(String orderId) => throw UnimplementedError();
  @override
  Future<OrderPreview> preview(OrderDraft draft) => throw UnimplementedError();
  @override
  Future<OrderReceipt> commit(OrderCommit command) =>
      throw UnimplementedError();
}

class _FixtureRecurringService implements RecurringPlanService {
  @override
  Future<List<RecurringPlan>> list(String portfolioId) async => const [];
  @override
  Future<RecurringPlan> get(String planId) => throw UnimplementedError();
  @override
  Future<RecurringPlan> create(RecurringPlanCreate command) =>
      throw UnimplementedError();
  @override
  Future<RecurringPlan> edit(RecurringPlanEdit command) =>
      throw UnimplementedError();
  @override
  Future<RecurringPlan> pause(String planId, int expectedVersion) =>
      throw UnimplementedError();
  @override
  Future<RecurringPlan> resume(String planId, int expectedVersion) =>
      throw UnimplementedError();
  @override
  Future<void> cancel(String planId, int expectedVersion) =>
      throw UnimplementedError();
}

class _FixtureRebalanceService implements RebalanceService {
  @override
  Future<RebalancePreview> preview(
    String portfolioId,
    List<RebalanceAllocation> allocations,
  ) async => RebalancePreview(
    id: 'fixture-rebalance-preview',
    portfolioId: portfolioId,
    portfolioVersion: 1,
    targetAllocation: allocations,
    trades: const [
      RebalanceTrade(
        assetId: _FixturePortfolioService.assetId,
        side: RebalanceSide.buy,
        quantityValue: '0.125',
        quantityScale: 3,
        notionalMinor: 2500,
      ),
    ],
    expiresAt: DateTime.utc(2026, 8, 25, 12, 15),
    status: RebalancePreviewStatus.active,
    demo: RebalanceDemoDisclosure(
      isDemo: true,
      observedAt: DateTime.utc(2026, 8, 25, 12),
      sourceLabel: 'Fixture Demo ledger',
      limitations: const ['No brokerage or real money is connected.'],
    ),
  );
  @override
  Future<RebalanceReceipt> commit(RebalanceCommit command) =>
      throw UnimplementedError();
}

class _FixtureBriefingService implements BriefingService {
  BriefingSummary _summary(String id) => BriefingSummary(
    id: id,
    type: BriefingType.daily,
    periodStart: DateTime.utc(2026, 8, 25),
    periodEnd: DateTime.utc(2026, 8, 25),
    generatedAt: DateTime.utc(2026, 8, 25, 12),
    generation: 1,
    sourceSequence: id.endsWith('92') ? 92 : 91,
    readAt: null,
  );

  @override
  Future<BriefingPage> list({
    BriefingType? type,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? cursor,
  }) async => BriefingPage(
    items: [_summary('00000000-0000-4000-8000-000000000091')],
    hasMore: false,
  );

  @override
  Future<BriefingDetail> get(String briefingId) async => BriefingDetail(
    summary: _summary(briefingId),
    sections: [
      BriefingSummarySection(
        ordinal: 1,
        sourceSequence: _summary(briefingId).sourceSequence,
        disclosure: 'Fixture Demo briefing $briefingId',
      ),
    ],
  );

  @override
  Future<DailyBriefingResult> daily(DateTime localDate) async =>
      DailyBriefingResult.available(
        await get('00000000-0000-4000-8000-000000000091'),
      );

  @override
  Future<BriefingSummary> setRead(String briefingId, bool read) async =>
      _summary(briefingId).copyWith(
        readAt: read ? DateTime.utc(2026, 8, 25, 12, 1) : null,
        clearReadAt: !read,
      );
}

class _FixtureNotificationService implements NotificationService {
  NotificationItem get _item => NotificationItem(
    id: '00000000-0000-4000-8000-000000000093',
    kind: NotificationKind.briefingReady,
    title: 'Fixture briefing ready',
    body: 'Open Ritual to review the Demo recap.',
    destination: NotificationDestination.tryParse('/briefings'),
    scheduledAt: DateTime.utc(2026, 8, 25, 12),
    readAt: null,
  );

  @override
  Future<NotificationPage> list({
    NotificationReadFilter filter = NotificationReadFilter.all,
    String? cursor,
  }) async => NotificationPage(items: [_item], hasMore: false);

  @override
  Future<NotificationPreferences> getPreferences() async =>
      const NotificationPreferences(
        dailyRitual: true,
        weeklyRecap: true,
        moonCycle: true,
        quietHours: NotificationQuietHours(
          enabled: false,
          start: '22:00',
          end: '07:00',
          timezone: 'UTC',
        ),
        version: 1,
      );

  @override
  Future<NotificationPreferences> patchPreferences(
    NotificationPreferencesDraft draft,
    int expectedVersion,
  ) async => draft.toPreferences(version: expectedVersion + 1);

  @override
  Future<int> readAll(NotificationReadAll command) async => 1;

  @override
  Future<NotificationItem> setRead(String notificationId, bool read) async =>
      _item.copyWith(
        readAt: read ? DateTime.utc(2026, 8, 25, 12, 1) : null,
        clearReadAt: !read,
      );
}
