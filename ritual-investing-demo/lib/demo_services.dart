import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/bootstrap/app_runtime.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/bootstrap/member_feature_scope.dart';
import 'package:ritual_investing_app/core/bootstrap/member_shell_runtime.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/asset_codex/data/repository.dart';
import 'package:ritual_investing_app/features/asset_codex/domain/model.dart';
import 'package:ritual_investing_app/features/coven/application/controller.dart';
import 'package:ritual_investing_app/features/coven/data/repository.dart';
import 'package:ritual_investing_app/features/coven/domain/model.dart';
import 'package:ritual_investing_app/features/discover/application/controller.dart';
import 'package:ritual_investing_app/features/discover/data/repository.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';
import 'package:ritual_investing_app/features/grimoires/data/repository.dart';
import 'package:ritual_investing_app/features/grimoires/domain/model.dart';
import 'package:ritual_investing_app/features/profile/application/controller.dart';
import 'package:ritual_investing_app/features/profile/data/repository.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';

/// A fresh, memory-only set of deterministic services for one demo document.
class DemoServices {
  DemoServices._(this.runtime);

  final MemberShellRuntime runtime;

  static Future<DemoServices> bootstrap() async {
    const scope = CacheScope(accountId: 'demo-frame', resetGeneration: 0);
    final cache = ScopedReadCache(storage: MemoryReadCache(), scope: scope);
    final invalidationBus = InvalidationBus();
    final covenRepository = CovenRepository(
      service: _DemoCovenService(),
      cache: cache,
    );
    final bootstrap = MemberBootstrap(
      accountId: 'demo-frame',
      resetGeneration: 0,
      onboarding: const MemberOnboardingGate.complete(version: 1),
      serverTime: _demoDate,
      contractVersion: 'demo-v2',
      themePreference: MemberThemePreference.light,
      branchCapabilities: MemberNavigationCapabilities(
        schemaVersion: 'member-branch-capabilities-v1',
        capabilityVersion: 1,
        environment: MemberReleaseEnvironment.beta,
        evaluatedAt: _demoDate.subtract(const Duration(minutes: 1)),
        expiresAt: _demoDate.add(const Duration(days: 1)),
        enabled: const {
          MemberBranchCapability.ritual,
          MemberBranchCapability.starpath,
          MemberBranchCapability.discover,
          MemberBranchCapability.coven,
          MemberBranchCapability.you,
        },
      ),
      personalization: const MemberPersonalization(
        explanationDepth: MemberExplanationDepth.guided,
        ritualVoice: MemberRitualVoice.mystical,
        riskFraming: MemberRiskFraming.moderate,
        ritualMode: MemberRitualMode.tarot,
        contributionRhythm: MemberContributionRhythm.monthly,
      ),
    );
    final featureScope = MemberFeatureScope(
      scope: scope,
      dailyRitualController: DailyRitualController(
        repository: DailyRitualRepository(
          service: _DemoRitualService(),
          cache: cache,
        ),
      ),
      starpathController: StarpathController(
        repository: StarpathRepository(
          service: _DemoStarpathService(),
          cache: cache,
        ),
        createKey: () => 'demo-starpath-command',
      ),
      discoverController: DiscoverController(
        repository: CachedDiscoverRepository(
          service: _DemoDiscoverService(),
          cache: cache,
        ),
        personalization: bootstrap.personalization,
      ),
      covenController: CovenController(repository: covenRepository),
      profileController: ProfileController(
        repository: CachedProfileRepository(
          service: _DemoProfileService(),
          cache: cache,
          now: () => _demoDate,
        ),
      ),
      invalidationBus: invalidationBus,
      assetCodexRepository: AssetCodexRepository(
        service: _DemoAssetCodexService(),
        cache: cache,
      ),
      covenRepository: covenRepository,
      grimoireRepository: GrimoireRepository(
        service: _DemoGrimoireService(),
        cache: cache,
      ),
    );
    final runtime = MemberShellRuntime.completed(
      bootstrap: bootstrap,
      featureScope: featureScope,
    );
    await runtime.ensureBranchLoaded(MemberBranch.ritual);
    if (runtime.dailyRitualController.state.value == null) {
      runtime.dispose();
      throw StateError('The initial Daily Ritual did not load.');
    }
    return DemoServices._(runtime);
  }

  void dispose() => runtime.dispose();
}

final _demoDate = DateTime.utc(2026, 8, 25, 12);
const _assetId = '20000000-0000-4000-8000-000000000001';
const _grimoireId = '00000000-0000-4000-8000-000000000541';
const _covenId = '00000000-0000-4000-8000-000000000510';

final _researchDisclosure = ResearchDemoDisclosure(
  isDemo: true,
  observedAt: _demoDate,
  sourceLabel: 'Ritual deterministic Demo',
  limitations: const [
    'Fictional research for product demonstration only.',
    'Not financial advice and no live market provider is connected.',
  ],
);

final _assetDisclosure = AssetDemoDisclosure(
  isDemo: true,
  observedAt: _demoDate,
  sourceLabel: 'Ritual deterministic Demo',
  limitations: const ['Fictional scenario; no live price provider.'],
);

final _covenDisclosure = CovenDemoDisclosure(
  isDemo: true,
  observedAt: _demoDate,
  sourceLabel: 'Ritual deterministic Demo',
  limitations: const ['Fictional company and qualification evidence.'],
);

class _DemoRitualService implements DailyRitualService {
  DailyRitual _value = _ritual(DailyRitualState.revealed);

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async => _value;

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async => _value;

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(
    String assignmentId,
  ) async => [
    RitualEvidenceDetail(
      claimId: '21000000-0000-4000-8000-000000000001',
      factorLabel: 'Durable dividend momentum',
      observedAt: _demoDate,
      summary: 'Lower volatility in the fictional scenario window.',
      uncertainty: 'Short windows can reverse and the scenario is simulated.',
      source: RitualEvidenceSource(
        publisher: 'Ritual Demo Research Desk',
        title: 'Provider-free scenario note',
        url: Uri.parse(
          'https://research.ritual-investing.test/demo/ritual-evidence',
        ),
        publishedAt: _demoDate,
      ),
    ),
  ];

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      RitualHistoryPage(items: const [], nextCursor: null, hasMore: false);

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) async {
    _value = _ritual(DailyRitualState.revealed);
    return _value;
  }

  @override
  Future<DailyRitual> complete(String assignmentId, int version) async {
    _value = _ritual(DailyRitualState.completed);
    return _value;
  }
}

class _DemoStarpathService implements StarpathService {
  final StarpathSnapshot _snapshot = _demoStarpathSnapshot();

  @override
  Future<StarpathSnapshot> fetch() async => _snapshot;

  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async =>
      _snapshot;

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async => _snapshot;

  @override
  Future<StarpathSnapshot> skipRecall({
    required String idempotencyKey,
    required int version,
    required String sessionId,
  }) async => _snapshot;
}

const _demoStarpathLessons = <List<String>>[
  ['What Is Investing?', 'What Is a Stock?'],
  ['Why Do Prices Move?', 'How the Market Works'],
  ['Indexes + the S&P 500', 'SPX, SPY, VOO + ETFs'],
  ['One Stock or a Basket?', 'Three Investing Principles'],
  ['What Is a Portfolio?', 'Allocation & Concentration'],
  ['Risk, Volatility & Drawdown', 'Compounding'],
  ['Research an Investment'],
  ['Make a Sample Investment'],
];

const _demoStarpathBodies = <List<String>>[
  [
    'Investing puts money into an asset that may grow or produce income, but returns are never guaranteed.',
    'A stock is an ownership interest in a company. Its market value can rise or fall.',
  ],
  [
    'Prices move as buyers and sellers react to new information and change what they will pay or accept.',
    'A broker routes an order to a market, where the bid, ask, spread, and order type affect execution.',
  ],
  [
    'An index measures a defined group of securities; the S&P 500 follows a published large-company methodology.',
    'SPX is an index. SPY and VOO are exchange-traded funds designed to track it, with their own costs and structures.',
  ],
  [
    'One company carries company-specific risk. A basket spreads exposure but cannot remove every possible loss.',
    'Keep the plan understandable, know what the investment owns, and choose risk before committing money.',
  ],
  [
    'A portfolio is the collection of investments you own, considered together rather than ticker by ticker.',
    'Allocation describes the mix. Concentration rises when one holding, sector, or asset type dominates it.',
  ],
  [
    'Volatility measures price movement and drawdown measures a decline from a prior peak.',
    'Compounding lets gains earn gains over time; losses and fees compound too.',
  ],
  [
    'Research begins with what an investment owns, how it may earn money, its costs, and what could break the thesis.',
  ],
  [
    'A sample order lets a learner review an amount and assumptions without sending money to a broker.',
  ],
];

StarpathSnapshot _demoStarpathSnapshot() => StarpathSnapshot(
  availability: StarpathAvailability.available,
  version: 1,
  authority: const StarpathAuthority(
    environment: StarpathEnvironment.beta,
    jurisdiction: 'US',
    capabilityVersion: 1,
    policyVersion: 'starpath-no-advice-v1',
    manifestId: 'demo-starpath-manifest',
    manifestVersion: 'demo-starpath-v1',
  ),
  nodes: List.generate(8, (index) {
    final ordinal = index + 1;
    return StarpathNode(
      lessonId: 'demo-starpath-lesson-$ordinal',
      revisionId: 'demo-starpath-revision-$ordinal',
      nodeOrdinal: ordinal,
      pathwayOrdinal: (index ~/ 2) + 1,
      pathwayPosition: (index % 2) + 1,
      title: _demoStarpathLessons[index].first,
      mythicMnemonic: 'Use the star as a memory marker for the definition, never as a prediction.',
      factualSummary: _demoStarpathBodies[index].first,
      materialLimitations:
          'Rights, costs, and risks vary by product and governing documents.',
      riskContext: 'Market value can fall and an investor can lose money.',
      recallPrompt: 'What is the main idea from this constellation?',
      rowanExplanation: 'The visual is only a memory aid. The written lesson and dated source carry the meaning.',
      guide: const StarpathGuide(
        tarotKey: 'the-star',
        accessibleLabel: 'The Star, used only as a memory aid.',
      ),
      factualSections: [
        for (
          var lessonIndex = 0;
          lessonIndex < _demoStarpathLessons[index].length;
          lessonIndex += 1
        )
          StarpathFactualSection(
            ordinal: lessonIndex + 1,
            kind: StarpathFactualSectionKind.fact,
            heading: _demoStarpathLessons[index][lessonIndex],
            body: _demoStarpathBodies[index][lessonIndex],
            observedAt: _demoDate,
            uncertainty: 'Specific products and market conditions can differ.',
            evidence: [
              StarpathEvidence(
                ordinal: 1,
                publisher: 'Investor.gov',
                sourceTitle: 'Introduction to Investing',
                canonicalUrl: Uri.parse(
                  'https://www.investor.gov/introduction-investing/investing-basics',
                ),
                claimSummary: 'Supports the reviewed educational definition and its risk boundary.',
                retrievedAt: _demoDate,
                sourceObservedAt: _demoDate,
                currentUntil: DateTime.utc(2027, 8, 25),
              ),
            ],
          ),
      ],
      knowledgeCheck: StarpathKnowledgeCheck(
        id: 'demo-starpath-question-$ordinal',
        prompt: 'Which statement respects the lesson?',
        options: [
          StarpathKnowledgeCheckOption(
            id: 'demo-starpath-option-$ordinal-a',
            ordinal: 1,
            label: 'Risk and outcomes are never guaranteed.',
          ),
          StarpathKnowledgeCheckOption(
            id: 'demo-starpath-option-$ordinal-b',
            ordinal: 2,
            label: 'The visual predicts the next return.',
          ),
        ],
      ),
      state: index == 0 ? StarpathNodeState.current : StarpathNodeState.locked,
    );
  }),
  session: StarpathSession(
    id: 'demo-starpath-session',
    explicitStart: true,
    startedAt: _demoDate,
    lastActionAt: _demoDate,
    state: StarpathSessionState.active,
  ),
  progress: StarpathProgress(
    currentNodeOrdinal: 1,
    version: 1,
    updatedAt: _demoDate,
  ),
  theme: const StarpathTheme(
    id: 'demo-starpath-theme',
    key: 'starpath-foundations',
    title: 'Starpath Foundations',
    horoscopeFrame: 'A visual memory frame only, never a forecast.',
    factualFocus: 'Four open constellations with fourteen short lessons.',
    accessibleLabel: 'A beginner investment education path.',
  ),
  recall: null,
);

DailyRitual _ritual(DailyRitualState state) => DailyRitual(
  assignmentId: '00000000-0000-4000-8000-000000000101',
  date: _demoDate,
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(
    id: '10000000-0000-4000-8000-000000000001',
    number: 1,
  ),
  title: 'Direction, not urgency.',
  art: const RitualArt(
    key: 'the_compass',
    alt: 'The Compass tarot card at a celestial crossroads',
  ),
  interpretation:
      'The strongest path today rewards patience. Favor durable momentum.',
  guidance: 'Inspect the evidence and compare risks before acting.',
  marketLabel: 'Simulated market context',
  ideas: const [
    RitualIdea(
      assetId: _assetId,
      symbol: 'VIG',
      name: 'Vanguard Dividend Appreciation ETF',
      appearanceReason: 'steady wealth',
      riskSummary: 'Short windows can reverse.',
      changeLabel: '+0.42%',
    ),
  ],
  evidence: [
    RitualEvidence(
      claimId: '21000000-0000-4000-8000-000000000001',
      factorLabel: 'Durable dividend momentum',
      observedAt: _demoDate,
      summary: 'Lower volatility in the fictional scenario window.',
      uncertainty: 'Short windows can reverse.',
    ),
  ],
  rowan: const RitualCounsel(
    scriptRevisionId: '10000000-0000-4000-8000-000000000002',
    surface: 'daily_ritual',
    body: 'I’ll show you what changed beneath the reading.',
    riskFooter: 'This deterministic Demo never tells you to trade.',
  ),
  version: state == DailyRitualState.completed ? 2 : 1,
  state: state,
  revealedAt: _demoDate,
  completedAt: state == DailyRitualState.completed ? _demoDate : null,
  demo: RitualDisclosure(
    isDemo: true,
    observedAt: _demoDate,
    sourceLabel: 'Ritual deterministic Demo',
    limitations: const [
      'Prices and signals are fictional.',
      'Educational exploration only; not investment advice.',
    ],
  ),
);

class _DemoDiscoverService implements DiscoverService {
  @override
  Future<DiscoverModel> fetch() async => DiscoverModel(
    items: [
      DiscoverItemView(
        id: _grimoireId,
        revisionId: '00000000-0000-4000-8000-000000000542',
        slug: 'quiet-power-grimoire',
        kind: DiscoverItemKind.grimoire,
        title: 'Quiet Power Grimoire',
        subtitle: 'A memory-only collection',
        appearanceReason: 'Demonstrates a reversible local save.',
        demo: _researchDisclosure,
      ),
    ],
    creators: const [],
    nextCursor: null,
    hasMore: false,
  );
}

class _DemoCovenService implements CovenService {
  bool _saved = false;

  @override
  Future<CovenModel> fetch() async => CovenModel(
    entries: [
      CovenEntry(
        id: _covenId,
        revisionId: '00000000-0000-4000-8000-000000000520',
        slug: 'aurora-healthworks',
        name: 'Aurora Healthworks',
        symbol: 'AUR',
        category: CovenQualificationCategory.founder,
        focus: 'Preventive health technology',
        teaser: 'Fictional, dated qualification evidence.',
        effectiveDate: _demoDate,
        verifiedAsOf: _demoDate,
        demo: _covenDisclosure,
      ),
    ],
  );

  @override
  Future<CovenDetail> fetchDetail(String entryId) async => CovenDetail(
    id: entryId,
    revisionId: '00000000-0000-4000-8000-000000000520',
    slug: 'aurora-healthworks',
    company: 'Aurora Healthworks',
    symbol: 'AUR',
    focus: 'Preventive health technology',
    summary: 'A fictional company used to demonstrate qualification evidence.',
    inclusionRationale: 'Dated founder evidence is present.',
    limitations: 'Demo only; not investment advice.',
    qualifications: [
      CovenQualification(
        category: CovenQualificationCategory.founder,
        personName: 'Avery North',
        effectiveDate: _demoDate,
        verifiedAsOf: _demoDate,
        validTo: null,
        evidence: const [],
      ),
    ],
    evidence: await fetchEvidence(entryId),
    saved: _saved,
    demo: _covenDisclosure,
  );

  @override
  Future<List<CovenEvidenceDetail>> fetchEvidence(String entryId) async => [
    CovenEvidenceDetail(
      claimId: '00000000-0000-4000-8000-000000000530',
      factorLabel: 'Founder qualification',
      observedAt: _demoDate,
      summary: 'Fictional founder record.',
      uncertainty: 'The evidence is illustrative and can be revised.',
      publisher: 'Ritual Demo Registry',
      sourceTitle: 'Fixture founder record',
      sourceUrl: Uri.parse(
        'https://research.ritual-investing.test/demo/coven-evidence',
      ),
      publishedAt: _demoDate,
    ),
  ];

  @override
  Future<void> save(String entryId) async => _saved = true;

  @override
  Future<void> unsave(String entryId) async => _saved = false;
}

class _DemoGrimoireService implements GrimoireService {
  bool _saved = false;

  @override
  Future<GrimoireDetail> fetchDetail(String grimoireId) async => GrimoireDetail(
    id: grimoireId,
    revisionId: '00000000-0000-4000-8000-000000000542',
    slug: 'quiet-power-grimoire',
    title: 'Quiet Power Grimoire',
    description:
        'A fictional collection that resets with this browser document.',
    theme: 'durability',
    curatorLabel: 'Ritual Demo Research Desk',
    assets: [
      GrimoireAssetReference(
        id: _assetId,
        revisionId: '00000000-0000-4000-8000-000000000502',
        slug: 'quiet-power',
        symbol: 'VIG',
        name: 'Dividend Appreciation',
        appearanceReason: 'Deterministic durability research.',
        demo: _researchDisclosure,
      ),
    ],
    saved: _saved,
    demo: _researchDisclosure,
  );

  @override
  Future<void> save(String grimoireId) async => _saved = true;

  @override
  Future<void> unsave(String grimoireId) async => _saved = false;
}

class _DemoAssetCodexService implements AssetCodexService {
  bool _saved = false;

  @override
  Future<AssetCodex> fetchDetail(String assetId) async => AssetCodex(
    id: assetId,
    revisionId: '00000000-0000-4000-8000-000000000502',
    slug: 'quiet-power',
    symbol: 'VIG',
    name: 'Dividend Appreciation',
    kind: AssetKind.etf,
    currency: 'USD',
    appearanceReason: 'Deterministic durability research.',
    thesis: 'A fictional quality-and-dividend scenario.',
    limitations: 'No live price or provider connection.',
    metricsAsOf: _demoDate,
    evidence: const [],
    detailedEvidence: const [],
    risks: const [],
    saved: _saved,
    demo: _assetDisclosure,
    source: const AssetSourceContext(kind: AssetSourceKind.direct),
  );

  @override
  Future<List<AssetEvidenceDetail>> fetchEvidence(String assetId) async =>
      const [];

  @override
  Future<List<AssetMetric>> fetchMetrics(String assetId) async => [
    AssetMetric(
      priceMinor: 10000,
      changeBps: 42,
      expenseRatioBps: 6,
      observedAt: _demoDate,
      sourceLabel: 'Ritual deterministic Demo',
      demo: _assetDisclosure,
    ),
  ];

  @override
  Future<AssetComparison> compare(List<String> assetIds) async =>
      AssetComparison(
        items: const [],
        comparedAt: _demoDate,
        demo: _assetDisclosure,
      );

  @override
  Future<void> save(String assetId, AssetSourceContext source) async =>
      _saved = true;

  @override
  Future<void> unsave(String assetId) async => _saved = false;
}

class _DemoProfileService implements ProfileService {
  @override
  Future<ProfileModel> fetch() async => const ProfileModel(
    displayName: 'Ritual Demo Member',
    profileVersion: 1,
    preferences: SavedRitualPreferences(
      locale: 'en-US',
      timezone: 'America/New_York',
      ritualMode: ProfileRitualMode.tarot,
      theme: ProfileTheme.light,
      version: 1,
    ),
  );

  @override
  Future<void> patchPreferences(ProfilePreferencesUpdate update) async {}

  @override
  Future<void> putInvestor(ProfileInvestorUpdate update) async {}

  @override
  Future<ProfileConsentReceipt> putAstrology(ProfileAstrologyUpdate update) =>
      _receipt(ProfileConsentDecision.accepted);

  @override
  Future<ProfileConsentReceipt> deleteAstrology({
    required int expectedVersion,
  }) => _receipt(ProfileConsentDecision.withdrawn);

  Future<ProfileConsentReceipt> _receipt(
    ProfileConsentDecision decision,
  ) async => ProfileConsentReceipt(
    id: 'demo-consent',
    decision: decision,
    policyVersion: 'demo-v2',
    recordedAt: _demoDate,
  );
}
