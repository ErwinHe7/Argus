import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';

const _partTitles = [
  'What Investing Is',
  'How Markets Work',
  'Indexes and Funds',
  'Investing Principles',
  'Build a Portfolio',
  'Understand Risk',
  'Research an Investment',
  'Make a Sample Investment',
];

const _partSummaries = [
  'Start with the purpose of investing and what owning a share actually means.',
  'See why prices change and how an order moves from a broker to a market.',
  'Understand broad indexes, the S&P 500, and the funds people use to follow them.',
  'Compare a single stock with a basket and learn three durable investing habits.',
  'Learn what belongs in a portfolio and why concentration changes its risk.',
  'Make volatility, drawdown, time horizon, and compounding easier to reason about.',
  'Use a short research checklist before considering any investment.',
  'Walk through a simulated investment without placing a real trade.',
];

const _partLessons = [
  ['What Is Investing?', 'What Is a Stock?'],
  ['Why Do Prices Move?', 'How the Market Works'],
  ['Indexes + the S&P 500', 'SPX, SPY, VOO + ETFs'],
  ['One Stock or a Basket?', 'The Three Principles of Investing'],
  ['What Is a Portfolio?', 'Allocation & Concentration'],
  ['Risk, Volatility & Drawdown', 'Compounding'],
  ['Research an Investment'],
  ['Make a Sample Investment'],
];

const _partLessonBodies = [
  [
    'Investing means putting money into an asset with the hope that its value or income grows over time. Returns are never guaranteed.',
    'A stock is a small ownership interest in a company. Its price can rise or fall, including to zero.',
  ],
  [
    'Prices move when buyers and sellers change what they are willing to pay or accept as new information reaches the market.',
    'A broker routes an order to a market where it can meet another order. The bid, ask, spread, and order type affect execution.',
  ],
  [
    'An index measures a defined group of securities. The S&P 500 tracks large U.S. companies under a published methodology.',
    'SPX is an index, while SPY and VOO are exchange-traded funds designed to follow it. Similar names do not make them identical products.',
  ],
  [
    'One company can have company-specific risk. A basket spreads exposure across multiple holdings but cannot remove every loss.',
    'Keep the plan simple, focus on what the investment owns, and decide how much risk you can accept before putting money in.',
  ],
  [
    'A portfolio is the collection of investments you own. The mix matters more than any one ticker viewed alone.',
    'Allocation is how the portfolio is divided. Concentration rises when one holding, sector, or asset type dominates the total.',
  ],
  [
    'Volatility describes price movement; drawdown measures a fall from a prior peak. The time available before money is needed also matters.',
    'Compounding happens when gains can earn further gains over time. Losses and fees compound too, so the path is not smooth or guaranteed.',
  ],
  [
    'Research starts with what the investment owns, how it may earn money, its costs, and the risks that could change the thesis.',
  ],
  [
    'A sample order lets a learner choose an amount, review assumptions, and observe a hypothetical result without sending money to a broker.',
  ],
];

StarpathController starpathFixtureController({
  int version = 2,
  int currentOrdinal = 3,
  bool recall = false,
  StarpathAnswerFeedback? answer,
  bool offline = false,
  bool draftPreview = false,
  bool started = true,
}) {
  final snapshot = starpathFixtureSnapshot(
    version: version,
    currentOrdinal: currentOrdinal,
    recall: recall,
    answer: answer,
    draftPreview: draftPreview,
    started: started,
  );
  return StarpathController(
    repository: StarpathRepository(
      service: StarpathFixtureService(snapshot: snapshot, offline: offline),
      cache: MemoryReadCache(),
    ),
    createKey: () => 'fixture-command-key',
  );
}

class StarpathFixtureService implements StarpathService {
  StarpathFixtureService({required this.snapshot, this.offline = false});

  StarpathSnapshot snapshot;
  bool offline;

  @override
  Future<StarpathSnapshot> fetch() async {
    if (offline) throw const OfflineException();
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async =>
      snapshot;

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async => snapshot;

  @override
  Future<StarpathSnapshot> skipRecall({
    required String idempotencyKey,
    required int version,
    required String sessionId,
  }) async => snapshot;
}

StarpathSnapshot starpathFixtureSnapshot({
  int version = 2,
  int currentOrdinal = 3,
  bool recall = false,
  StarpathAnswerFeedback? answer,
  bool draftPreview = false,
  bool started = true,
}) => StarpathSnapshot(
  availability: started
      ? StarpathAvailability.available
      : StarpathAvailability.notStarted,
  version: version,
  authority: StarpathAuthority(
    environment: StarpathEnvironment.beta,
    jurisdiction: 'US',
    capabilityVersion: 4,
    policyVersion: draftPreview
        ? 'starpath-no-advice-v1-draft'
        : 'starpath-no-advice-v1',
    manifestId: 'manifest-1',
    manifestVersion: draftPreview ? draftPreviewStarpathManifestVersion : '1',
  ),
  nodes: List.generate(8, (index) {
    final ordinal = index + 1;
    return StarpathNode(
      lessonId: 'lesson-$ordinal',
      revisionId: 'revision-$ordinal',
      nodeOrdinal: ordinal,
      pathwayOrdinal: (index ~/ 2) + 1,
      pathwayPosition: (index % 2) + 1,
      title: _partTitles[index],
      mythicMnemonic: 'Picture a steady star marking the definition, never predicting an outcome.',
      factualSummary: _partSummaries[index],
      materialLimitations: 'Rights vary by security, share class, issuer, and governing documents.',
      riskContext:
          'A security’s market value can rise or fall, including to zero.',
      recallPrompt: 'What does a share generally represent?',
      rowanExplanation: 'The star is only a memory marker. The reviewed fact is the ownership definition and its limits.',
      guide: const StarpathGuide(
        tarotKey: 'the-star',
        accessibleLabel: 'The Star, used only as a memory aid.',
      ),
      factualSections: [
        for (
          var lessonIndex = 0;
          lessonIndex < _partLessons[index].length;
          lessonIndex += 1
        )
          StarpathFactualSection(
            ordinal: lessonIndex + 1,
            kind: StarpathFactualSectionKind.fact,
            heading: _partLessons[index][lessonIndex],
            body: _partLessonBodies[index][lessonIndex],
            observedAt: DateTime.utc(2026, 8, 29),
            uncertainty: 'Specific contractual rights can differ.',
            evidence: [
              StarpathEvidence(
                ordinal: 1,
                publisher: 'Investor.gov',
                sourceTitle: 'Stocks',
                canonicalUrl: Uri.parse(
                  'https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks',
                ),
                claimSummary: 'A stock is a security that can give holders an ownership interest.',
                retrievedAt: DateTime.utc(2026, 8, 29),
                sourceObservedAt: DateTime.utc(2026, 8, 29),
                currentUntil: DateTime.utc(2027, 8, 29),
              ),
            ],
          ),
      ],
      knowledgeCheck: StarpathKnowledgeCheck(
        id: 'question-$ordinal',
        prompt: 'Which statement is factual?',
        options: [
          StarpathKnowledgeCheckOption(
            id: 'option-$ordinal-a',
            ordinal: 1,
            label: 'A share can represent an ownership interest.',
          ),
          StarpathKnowledgeCheckOption(
            id: 'option-$ordinal-b',
            ordinal: 2,
            label: 'A share guarantees a positive return.',
          ),
        ],
      ),
      state: ordinal < currentOrdinal
          ? StarpathNodeState.completed
          : ordinal == currentOrdinal
          ? StarpathNodeState.current
          : StarpathNodeState.locked,
    );
  }),
  session: started
      ? StarpathSession(
          id: 'session-1',
          explicitStart: true,
          startedAt: DateTime.utc(2026, 8, 29),
          lastActionAt: DateTime.utc(2026, 8, 30),
          state: StarpathSessionState.active,
        )
      : null,
  progress: started
      ? StarpathProgress(
          currentNodeOrdinal: currentOrdinal,
          version: version,
          updatedAt: DateTime.utc(2026, 8, 30),
        )
      : null,
  theme: started
      ? const StarpathTheme(
          id: 'theme-1',
          key: 'starpath-foundations',
          title: 'StarPath Foundations',
          horoscopeFrame: 'A memory frame only—never evidence or a forecast.',
          factualFocus: 'Four open constellations with fourteen short lessons.',
          accessibleLabel: 'An open beginner investing learning path.',
        )
      : null,
  recall: started && recall
      ? StarpathRecall(
          id: 'recall-1',
          lessonId: 'lesson-1',
          revisionId: 'revision-1',
          questionId: 'recall-question-1',
          prompt: 'Before the next star, recall the ownership definition.',
          knowledgeCheck: StarpathKnowledgeCheck(
            id: 'recall-question-1',
            prompt: 'What can common stock represent?',
            options: const [
              StarpathKnowledgeCheckOption(
                id: 'recall-a',
                ordinal: 1,
                label: 'An ownership interest',
              ),
              StarpathKnowledgeCheckOption(
                id: 'recall-b',
                ordinal: 2,
                label: 'A guaranteed return',
              ),
            ],
          ),
        )
      : null,
  answer: answer,
);
