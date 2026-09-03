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
import 'package:ritual_investing_app/features/ritual/data/leonidas_voice_preference_store.dart';
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
      leonidasVoicePreferenceStore: _DemoLeonidasVoicePreferenceStore(),
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
        createKey: () => 'demo-starpath-command-key',
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

class _DemoLeonidasVoicePreferenceStore
    implements LeonidasVoicePreferencePersistence {
  LeonidasVoicePreference _preference = LeonidasVoicePreference.enabled;

  @override
  Future<LeonidasVoicePreference> read(CacheScope scope) async => _preference;

  @override
  Future<void> write(CacheScope scope, {required bool enabled}) async {
    _preference = enabled
        ? LeonidasVoicePreference.enabled
        : LeonidasVoicePreference.disabled;
  }

  @override
  Future<void> clearScope(CacheScope scope) async {
    _preference = LeonidasVoicePreference.enabled;
  }
}

final _demoDate = DateTime.utc(2026, 8, 25, 12);
const _assetId = '20000000-0000-4000-8000-000000000001';
const _grimoireId = '00000000-0000-4000-8000-000000000541';
const _covenId = '00000000-0000-4000-8000-000000000510';

class _DemoStarpathService implements StarpathService {
  int _version = 1;
  int _currentOrdinal = 1;

  @override
  Future<StarpathSnapshot> fetch() async => _snapshot();

  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async =>
      _snapshot();

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async {
    _version = version + 1;
    _currentOrdinal = (_currentOrdinal + 1).clamp(1, 8);
    return _snapshot();
  }

  @override
  Future<StarpathSnapshot> skipRecall({
    required String idempotencyKey,
    required int version,
    required String sessionId,
  }) async {
    _version = version + 1;
    return _snapshot();
  }

  StarpathSnapshot _snapshot() => StarpathSnapshot(
    availability: StarpathAvailability.available,
    version: _version,
    authority: const StarpathAuthority(
      environment: StarpathEnvironment.beta,
      jurisdiction: 'US',
      capabilityVersion: 1,
      policyVersion: 'starpath-no-advice-v1',
      manifestId: 'demo-starpath-manifest',
      manifestVersion: 'demo-v1',
    ),
    nodes: List.generate(8, (index) {
      final ordinal = index + 1;
      return StarpathNode(
        lessonId: 'demo-starpath-lesson-$ordinal',
        revisionId: 'demo-starpath-revision-$ordinal',
        nodeOrdinal: ordinal,
        pathwayOrdinal: (index ~/ 2) + 1,
        pathwayPosition: (index % 2) + 1,
        title: 'Star lesson $ordinal',
        mythicMnemonic:
            'Picture a steady star marking the definition, never an outcome.',
        factualSummary:
            'This lesson introduces an objective investing definition.',
        materialLimitations:
            'Definitions and contractual rights can vary by product.',
        riskContext: 'Investments can lose value, including principal.',
        recallPrompt: 'Recall the objective definition from this lesson.',
        rowanExplanation:
            'The star is only a memory aid for the reviewed definition.',
        guide: const StarpathGuide(
          tarotKey: 'the-star',
          accessibleLabel: 'The Star, used only as a memory aid.',
        ),
        factualSections: [
          StarpathFactualSection(
            ordinal: 1,
            kind: StarpathFactualSectionKind.fact,
            heading: 'What it means',
            body: 'The reviewed definition describes a concept without predicting returns.',
            observedAt: _demoDate,
            uncertainty:
                'Terms and rights can differ across products and issuers.',
            evidence: [
              StarpathEvidence(
                ordinal: 1,
                publisher: 'Investor.gov',
                sourceTitle: 'Investor education',
                canonicalUrl: Uri.parse('https://www.investor.gov/'),
                claimSummary: 'Primary public investor-education source.',
                retrievedAt: _demoDate,
                sourceObservedAt: _demoDate,
                currentUntil: DateTime.utc(2027, 8, 25, 12),
              ),
            ],
          ),
        ],
        knowledgeCheck: StarpathKnowledgeCheck(
          id: 'demo-starpath-question-$ordinal',
          prompt: 'Which answer restates the objective definition?',
          options: [
            StarpathKnowledgeCheckOption(
              id: 'demo-starpath-option-$ordinal-a',
              ordinal: 1,
              label: 'The reviewed definition',
            ),
            StarpathKnowledgeCheckOption(
              id: 'demo-starpath-option-$ordinal-b',
              ordinal: 2,
              label: 'A guaranteed investment outcome',
            ),
          ],
        ),
        state: ordinal < _currentOrdinal
            ? StarpathNodeState.completed
            : ordinal == _currentOrdinal
            ? StarpathNodeState.current
            : StarpathNodeState.locked,
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
      currentNodeOrdinal: _currentOrdinal,
      version: _version,
      updatedAt: _demoDate,
    ),
    theme: const StarpathTheme(
      id: 'demo-starpath-theme',
      key: 'walk-the-stars',
      title: 'Walk the Stars',
      horoscopeFrame: 'A memory frame, not a prediction.',
      factualFocus: 'Learn one objective concept at a time.',
      accessibleLabel: 'A celestial learning path.',
    ),
    recall: null,
  );
}

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
