// Provider-free, memory-only services for the explicitly requested internal
// preview. Nothing in this file can reach Supabase, Webull, persistent browser
// storage, or any other network-backed provider.
//
// The data began as the deterministic member test fixture so the preview and
// the tested product surfaces stay aligned.
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/auth/auth_controller.dart';
import 'package:ritual_investing_app/core/auth/member_auth.dart';
import 'package:ritual_investing_app/core/bootstrap/dependency_container.dart';
import 'package:ritual_investing_app/core/bootstrap/entry_coordinator.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ai_analysis/application/controller.dart';
import 'package:ritual_investing_app/features/ai_analysis/data/repository.dart';
import 'package:ritual_investing_app/features/ai_analysis/domain/model.dart';
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
import 'package:ritual_investing_app/features/grimoires/data/repository.dart';
import 'package:ritual_investing_app/features/grimoires/domain/model.dart';
import 'package:ritual_investing_app/features/notifications/application/notification_controller.dart';
import 'package:ritual_investing_app/features/notifications/data/repository.dart';
import 'package:ritual_investing_app/features/notifications/domain/model.dart';
import 'package:ritual_investing_app/features/privacy/application/privacy_controller.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/profile/application/controller.dart';
import 'package:ritual_investing_app/features/profile/data/repository.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';
import 'package:ritual_investing_app/features/public_beta/domain/member_capability_policy.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/search/application/controller.dart';
import 'package:ritual_investing_app/features/search/data/repository.dart';
import 'package:ritual_investing_app/features/search/domain/model.dart';

import 'ai_analysis_fixture.dart';

class FeatureLoadTracker {
  final Map<MemberBranch, int> _counts = {};

  int count(MemberBranch branch) => _counts[branch] ?? 0;
  void hit(MemberBranch branch) =>
      _counts.update(branch, (value) => value + 1, ifAbsent: () => 1);
}

MemberNavigationCapabilities internalPreviewNavigationCapabilities({
  int version = 1,
}) => MemberNavigationCapabilities(
  schemaVersion: 'member-branch-capabilities-v1',
  capabilityVersion: version,
  environment: MemberReleaseEnvironment.beta,
  evaluatedAt: DateTime.utc(2026, 8, 23),
  expiresAt: DateTime.utc(2026, 8, 29),
  enabled: const {
    MemberBranchCapability.ritual,
    MemberBranchCapability.starpath,
    MemberBranchCapability.discover,
    MemberBranchCapability.coven,
    MemberBranchCapability.you,
  },
);

DependencyContainer createInternalPreviewDependencyContainer({
  ScopedReadCacheStorage? cache,
  void Function(ReadCache cache)? onScopedCacheCreated,
  AuthController? authController,
  SessionRepository? sessionRepository,
  SessionBootstrapService? sessionBootstrapService,
  FeatureLoadTracker? loadTracker,
  PendingCommandStore? pendingCommandStore,
  EntryCoordinator? entryCoordinator,
  bool includeU9 = false,
  bool includeU11 = false,
  bool includeSearch = false,
  PrivacyRepository? privacyRepository,
  MemberCapabilityPolicy capabilityPolicy = MemberCapabilityPolicy.native,
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
      onScopedCacheCreated?.call(scopedCache);
      final covenRepository = CovenRepository(
        service: _FixtureCovenService(tracker),
        cache: scopedCache,
      );
      final invalidationBus = InvalidationBus();
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
              authorizeDeletion: () async =>
                  'delete_step_up_receipt_000000000001',
              onDeletionAccepted: () async {},
              personalization: bootstrap.personalization,
            )
          : null;
      return MemberFeatureScope(
        scope: scope,
        capabilityPolicy: capabilityPolicy,
        dailyRitualController: DailyRitualController(
          repository: DailyRitualRepository(
            service: _FixtureRitualService(tracker),
            cache: scopedCache,
          ),
        ),
        starpathController: StarpathController(
          repository: StarpathRepository(
            service: _FixtureStarpathService(tracker),
            cache: scopedCache,
          ),
          createKey: () => 'fixture-starpath-key',
        ),
        discoverController: DiscoverController(
          repository: CachedDiscoverRepository(
            service: _FixtureDiscoverService(tracker),
            cache: scopedCache,
          ),
          personalization: bootstrap.personalization,
        ),
        aiAnalysisController: AiAnalysisController(
          repository: AiAnalysisRepository(
            service: _FixtureAiAnalysisService(),
          ),
          utcClock: () => DateTime.utc(2026, 9, 1, 12),
        ),
        covenController: CovenController(repository: covenRepository),
        profileController: ProfileController(
          repository: CachedProfileRepository(
            service: _FixtureProfileService(tracker, memberState),
            cache: scopedCache,
          ),
        ),
        invalidationBus: invalidationBus,
        briefingController: briefingController,
        notificationController: notificationController,
        privacyController: privacyController,
        searchController: includeSearch
            ? SearchController(
                repository: SearchRepository(service: _FixtureSearchService()),
                debounce: Duration.zero,
              )
            : null,
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

class _FixtureAiAnalysisService implements AiAnalysisService {
  @override
  Future<AiAnalysisSnapshot> fetch() async => buildFixtureAiAnalysisSnapshot();
}

class _PreviewStarpathLesson {
  const _PreviewStarpathLesson({
    required this.heading,
    required this.body,
    required this.uncertainty,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.publisher,
  });

  final String heading;
  final String body;
  final String uncertainty;
  final String sourceTitle;
  final String sourceUrl;
  final String publisher;
}

class _PreviewStarpathPart {
  const _PreviewStarpathPart({
    required this.title,
    required this.summary,
    required this.tarotKey,
    required this.mnemonic,
    required this.limitations,
    required this.riskContext,
    required this.recallPrompt,
    required this.rowanExplanation,
    required this.checkPrompt,
    required this.correctOption,
    required this.distractor,
    required this.lessons,
  });

  final String title;
  final String summary;
  final String tarotKey;
  final String mnemonic;
  final String limitations;
  final String riskContext;
  final String recallPrompt;
  final String rowanExplanation;
  final String checkPrompt;
  final String correctOption;
  final String distractor;
  final List<_PreviewStarpathLesson> lessons;
}

const _previewStarpathParts = <_PreviewStarpathPart>[
  _PreviewStarpathPart(
    title: 'Market Basics: Ownership',
    summary: 'Start with two plain ideas: what investing means and what one share actually represents.',
    tarotKey: 'the-magician',
    mnemonic:
        'Before following a ticker, know what the asset is and what you own.',
    limitations: 'These definitions explain ownership, not whether any asset is suitable for someone.',
    riskContext:
        'Investments can lose value, including shares of familiar companies.',
    recallPrompt: 'What do you actually own when you buy one share?',
    rowanExplanation: 'A share is one small unit of ownership in a company. Its price can rise or fall, and neither outcome is promised.',
    checkPrompt: 'What is a share of common stock?',
    correctOption: 'A small ownership interest in a company.',
    distractor: 'A promise that the company will repay you with interest.',
    lessons: [
      _PreviewStarpathLesson(
        heading: 'What Is Investing?',
        body: 'Investing means putting capital into an asset because you expect it to create or preserve value over time. It usually involves longer-term ownership. Trading is different: it focuses on trying to profit from shorter-term price moves. Both involve risk, and neither promises a profit.',
        uncertainty: 'The line between investing and trading is not always perfectly sharp, but they require different habits and time horizons.',
        sourceTitle: 'Introduction to Investing',
        sourceUrl:
            'https://www.investor.gov/introduction-investing/investing-basics',
        publisher: 'Investor.gov',
      ),
      _PreviewStarpathLesson(
        heading: 'What Is a Stock?',
        body: 'A stock is a piece of ownership in a company. One share is one small unit of that ownership, and a person who owns it is a shareholder. A ticker is the short code for the stock: Apple is AAPL, Nvidia is NVDA, and Tesla is TSLA.',
        uncertainty: 'A familiar company can still have a falling share price. Ownership never guarantees a profit or a dividend.',
        sourceTitle: 'Stocks',
        sourceUrl: 'https://www.investor.gov/introduction-investing/investing-basics/investment-products/stocks',
        publisher: 'Investor.gov',
      ),
    ],
  ),
  _PreviewStarpathPart(
    title: 'Market Basics: How It Works',
    summary: 'See why prices move, how a broker reaches the market, and what a live quote is saying.',
    tarotKey: 'the-hermit',
    mnemonic: 'A quote is a conversation between buyers and sellers.',
    limitations: 'A quote is a moment in time. Prices and available shares can change before an order arrives.',
    riskContext: 'Fast or thin markets can have wider spreads and less predictable execution.',
    recallPrompt: 'What do bid, ask, and spread tell you?',
    rowanExplanation: 'The bid is the highest current buying price, the ask is the lowest current selling price, and the spread is the difference.',
    checkPrompt:
        'If the bid is \$199.98 and the ask is \$200.02, what is the spread?',
    correctOption: '\$0.04.',
    distractor: '\$399.00.',
    lessons: [
      _PreviewStarpathLesson(
        heading: 'Why Do Prices Move?',
        body: 'A stock price moves because buyers and sellers keep changing what they are willing to pay. Earnings, company news, expectations, and the broader market mood can all shift that balance. A good company can still have a down day because the price reflects expectations about the future, not only what the company is doing today.',
        uncertainty: 'Most price moves have several causes, and a headline cannot tell you what the next move will be.',
        sourceTitle: 'How Stock Markets Work',
        sourceUrl: 'https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work',
        publisher: 'Investor.gov',
      ),
      _PreviewStarpathLesson(
        heading: 'How the Market Works',
        body: 'Your broker is the app or service that sends an order to the market: you, then the broker, then the market. On a quote, the bid is the highest current buying price and the ask is the lowest current selling price. Their difference is the spread. If AAPL shows a \$199.98 bid and a \$200.02 ask, the spread is \$0.04. Regular U.S. stock-market hours are 9:30 a.m. to 4:00 p.m. ET, with premarket and after-hours sessions around them.',
        uncertainty: 'Outside regular hours, trading can be lighter and spreads can be wider. A displayed quote does not guarantee an execution price.',
        sourceTitle: 'Executing an Order',
        sourceUrl: 'https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/executing-order',
        publisher: 'Investor.gov',
      ),
    ],
  ),
  _PreviewStarpathPart(
    title: 'The Art of Investing: Indexes',
    summary: 'Meet the S&P 500, then separate the index itself from the ETFs designed to follow it.',
    tarotKey: 'the-star',
    mnemonic: 'The index is the map. An ETF is one vehicle built to follow it.',
    limitations: 'An index describes a defined group of assets. It is not a company and cannot be purchased directly like a share.',
    riskContext:
        'An index can fall, and an ETF designed to track it can lose value.',
    recallPrompt: 'How are SPX, SPY, and VOO related?',
    rowanExplanation: 'SPX refers to the S&P 500 index. SPY and VOO are separate ETFs designed to track that index.',
    checkPrompt: 'Which one is the S&P 500 index itself?',
    correctOption: 'SPX.',
    distractor: 'SPY and VOO are both the index itself.',
    lessons: [
      _PreviewStarpathLesson(
        heading: 'Indexes and the S&P 500',
        body: 'An index tracks the performance of a group of assets. It is not a company; think of it as a scoreboard built from a set of rules. The S&P 500 is the main beginner example: it represents roughly 500 large U.S. companies and is widely used as a reference for large U.S. stocks.',
        uncertainty: 'The S&P 500 does not include every U.S. company, and its largest members have more influence on its movement.',
        sourceTitle: 'S&P 500',
        sourceUrl: 'https://www.spglobal.com/spdji/en/indices/equity/sp-500/',
        publisher: 'S&P Dow Jones Indices',
      ),
      _PreviewStarpathLesson(
        heading: 'SPX, SPY, VOO and ETFs',
        body: 'SPX refers to the S&P 500 index itself. SPY and VOO are two different ETFs designed to track that index. An ETF is a fund that can hold a basket of investments and trade on an exchange, so one purchase can give exposure to many companies. SPX, SPY, and VOO are related, but they are not the same product.',
        uncertainty: 'Two ETFs with a similar goal can still differ in fees, trading, structure, and how closely they follow an index.',
        sourceTitle: 'Exchange-Traded Funds',
        sourceUrl: 'https://www.investor.gov/introduction-investing/investing-basics/investment-products/mutual-funds-and-exchange-traded-2',
        publisher: 'Investor.gov',
      ),
    ],
  ),
  _PreviewStarpathPart(
    title: 'The Art of Investing: Principles',
    summary: 'Compare one company with a basket, then learn three habits that keep investment thinking clear.',
    tarotKey: 'the-high-priestess',
    mnemonic: 'Understand what you own, focus on the asset beneath the price, and leave room for uncertainty.',
    limitations: 'Simple questions are a starting point, not a complete valuation or a recommendation.',
    riskContext: 'Diversification can reduce concentration risk, but it cannot remove market risk or guarantee a gain.',
    recallPrompt: 'What are the three basic principles in this lesson?',
    rowanExplanation: 'Keep it understandable, focus on fundamentals, and manage how much one investment or assumption can affect the whole portfolio.',
    checkPrompt: 'What can diversification do?',
    correctOption:
        'Reduce how much one holding can affect the whole portfolio.',
    distractor: 'Guarantee that the portfolio will not lose money.',
    lessons: [
      _PreviewStarpathLesson(
        heading: 'One Stock or a Basket?',
        body: 'Owning NVDA gives you exposure to one company. Owning a broad basket such as SPY spreads exposure across many companies. That is diversification: one company usually has less control over the result. The opposite is concentration risk, when one investment becomes so large that the portfolio depends heavily on it.',
        uncertainty: 'A basket can still be concentrated, and diversification does not eliminate a market-wide decline. An ETF is not automatically safe.',
        sourceTitle: 'Asset Allocation and Diversification',
        sourceUrl: 'https://www.investor.gov/introduction-investing/getting-started/asset-allocation',
        publisher: 'Investor.gov',
      ),
      _PreviewStarpathLesson(
        heading: 'The Three Principles of Investing',
        body: 'First, keep it simple: understand what you own and why you own it instead of collecting random assets or following every trend. Second, focus on fundamentals: ask what the company sells, whether revenue and profit are growing, what advantage it may have, and what expectations are already in the price. Third, manage risk: notice concentration, diversification, time horizon, and the possibility of drawdowns. These are questions to investigate, not a formula for what to buy.',
        uncertainty: 'Revenue, profit, growth, and valuation are only part of the picture. Past results do not guarantee future performance.',
        sourceTitle: 'Researching Investments',
        sourceUrl: 'https://www.investor.gov/introduction-investing/getting-started/researching-investments',
        publisher: 'Investor.gov',
      ),
    ],
  ),
  _PreviewStarpathPart(
    title: 'Portfolio & Risk: Your Portfolio',
    summary: 'Put the holdings together, then see how allocation changes the effect of each one.',
    tarotKey: 'justice',
    mnemonic: 'A portfolio is the whole picture; position weight shows how loudly each holding speaks.',
    limitations: 'An example allocation is only an illustration. It is not a model portfolio or a recommendation.',
    riskContext: 'Several holdings can still fall together when they share the same sector, market, or economic risk.',
    recallPrompt: 'How do you calculate a position weight?',
    rowanExplanation: 'Divide the position value by the total portfolio value. A \$2,000 position in a \$10,000 portfolio has a 20% weight.',
    checkPrompt:
        'What is the weight of a \$2,000 position in a \$10,000 portfolio?',
    correctOption: '20%.',
    distractor: '2%.',
    lessons: [
      _PreviewStarpathLesson(
        heading: 'What Is a Portfolio?',
        body: 'A portfolio is the collection of investments you own. Allocation means how much of the portfolio is exposed to each one. For example, a sample portfolio might show SPY at 45%, AAPL at 20%, NVDA at 15%, other holdings at 10%, and cash at 10%. Those numbers are just an illustration, not a suggested mix.',
        uncertainty: 'A portfolio can contain many positions and still carry substantial risk if the holdings behave alike.',
        sourceTitle: 'Asset Allocation',
        sourceUrl: 'https://www.investor.gov/introduction-investing/getting-started/asset-allocation',
        publisher: 'Investor.gov',
      ),
      _PreviewStarpathLesson(
        heading: 'Allocation and Concentration',
        body: 'Allocation changes how much each investment can affect the portfolio. Position weight equals position value divided by total portfolio value, so a \$2,000 NVDA position in a \$10,000 portfolio has a 20% weight. A portfolio that is 95% NVDA depends much more on NVDA than one where it is 15%.',
        uncertainty: 'There is no single correct weight for everyone, and a lower position weight does not remove the chance of loss.',
        sourceTitle: 'Diversification',
        sourceUrl: 'https://www.investor.gov/introduction-investing/getting-started/asset-allocation',
        publisher: 'Investor.gov',
      ),
    ],
  ),
  _PreviewStarpathPart(
    title: 'Portfolio & Risk: Risk Over Time',
    summary: 'Understand price swings and drawdowns, then see how gains can build on earlier gains.',
    tarotKey: 'the-chariot',
    mnemonic: 'Volatility is the motion, drawdown is the fall, and compounding changes the base.',
    limitations: 'Past volatility, past drawdowns, and simple compounding examples cannot predict future results.',
    riskContext: 'A loss may be difficult or impossible to recover from, especially when money is needed soon.',
    recallPrompt: 'Why is the second 10% gain larger in the example?',
    rowanExplanation: 'After the first gain, the starting amount is larger. The next percentage change applies to that new amount.',
    checkPrompt: 'After \$1,000 gains 10% twice, with no fees or withdrawals, what is the result?',
    correctOption: '\$1,210.',
    distractor: '\$1,200.',
    lessons: [
      _PreviewStarpathLesson(
        heading: 'Risk, Volatility and Drawdown',
        body: 'Volatility describes how much a price moves around. Drawdown measures a fall from an earlier high: if a portfolio rises to \$10,000 and then falls to \$8,000, the drawdown is 20%. Time horizon matters because money needed soon has less time to wait through a decline than capital intended for many years.',
        uncertainty: 'Volatility does not capture every kind of risk. More time may allow a recovery, but recovery is never guaranteed.',
        sourceTitle: 'Risk',
        sourceUrl:
            'https://www.finra.org/investors/investing/investing-basics/risk',
        publisher: 'FINRA',
      ),
      _PreviewStarpathLesson(
        heading: 'Compounding',
        body: 'Compounding happens when a return builds on earlier gains. Start with \$1,000: after a 10% gain, it becomes \$1,100. Another 10% gain produces \$110, not \$100, so the total becomes \$1,210. The second gain applies to the larger amount.',
        uncertainty: 'This is simple arithmetic, not a promised return. Real investments can gain, lose, charge fees, and compound unevenly.',
        sourceTitle: 'Compound Interest Calculator',
        sourceUrl: 'https://www.investor.gov/financial-tools-calculators/calculators/compound-interest-calculator',
        publisher: 'Investor.gov',
      ),
    ],
  ),
  _PreviewStarpathPart(
    title: 'Practice Investing: Research',
    summary: 'Practice explaining an example asset before making any simulated order.',
    tarotKey: 'the-moon',
    mnemonic: 'A ticker is only a label. Say what the asset represents before looking at the order button.',
    limitations: 'A short research checklist cannot determine suitability, fair value, or future performance.',
    riskContext: 'Company-specific risk, market declines, valuation, and concentration can all affect an investment.',
    recallPrompt: 'What are you actually buying when you choose SPY?',
    rowanExplanation: 'SPY is an ETF designed to track the S&P 500, giving exposure to a basket of large U.S. companies.',
    checkPrompt: 'What is the goal of this research exercise?',
    correctOption:
        'Understand what the example asset is and what risks it carries.',
    distractor: 'Decide that everyone should buy the example asset.',
    lessons: [
      _PreviewStarpathLesson(
        heading: 'Research an Investment',
        body: 'Choose an example such as AAPL, NVDA, SPY, or VOO and explain it in plain language. Is it one company or an ETF? What does it represent? Why might someone study it: a business, broad-market exposure, or diversification? Then name what could go wrong, such as company-specific trouble, a market decline, a high valuation, or too much concentration. For SPY, the key fact is that it is an ETF designed to track the S&P 500 and hold exposure to many large U.S. companies.',
        uncertainty: 'The question is “Do you understand what it is?” not “Should you buy it?” This exercise provides education, not a recommendation.',
        sourceTitle: 'Researching Investments',
        sourceUrl: 'https://www.investor.gov/introduction-investing/getting-started/researching-investments',
        publisher: 'Investor.gov',
      ),
    ],
  ),
  _PreviewStarpathPart(
    title: 'Practice Investing: Sample Order',
    summary: 'Walk through one simulated investment order and see how it would appear in a practice portfolio.',
    tarotKey: 'justice',
    mnemonic: 'Pause at the preview: asset, side, shares, order type, price boundary, value, and weight.',
    limitations: 'A simulation cannot reproduce every live price, fill, fee, tax, or market condition.',
    riskContext: 'A real order can create a real gain or loss. Nothing in this practice flow predicts the result.',
    recallPrompt:
        'What is the difference between a market order and a limit order?',
    rowanExplanation: 'A market order uses the best prices available when it reaches the market. A limit order sets a price boundary but may not execute.',
    checkPrompt: 'What does a buy limit order do?',
    correctOption:
        'It can execute only at the limit price or lower, but it may not fill.',
    distractor: 'It guarantees an immediate fill at the displayed price.',
    lessons: [
      _PreviewStarpathLesson(
        heading: 'Make a Sample Investment',
        body: 'Use a hypothetical SPY price and enter a sample amount, such as \$1,000. The preview can estimate shares, position value, and portfolio weight. A market order tries to execute using the best available prices; a limit order executes only at the chosen price or better and may not fill. After “Simulate Order,” add it only to a fake portfolio and show average cost, current value, unrealized gain or loss, and position weight. The final check is simple: you simulated buying an ETF designed to track the S&P 500.',
        uncertainty: 'All prices and results in this lesson are hypothetical. No real brokerage order is created, and an estimate is never a guaranteed execution price.',
        sourceTitle: 'Types of Orders',
        sourceUrl: 'https://www.investor.gov/introduction-investing/investing-basics/how-stock-markets-work/types-orders',
        publisher: 'Investor.gov',
      ),
    ],
  ),
];

class _FixtureStarpathService implements StarpathService {
  _FixtureStarpathService(this.tracker);

  final FeatureLoadTracker tracker;
  int _version = 0;
  int _currentOrdinal = 1;

  @override
  Future<StarpathSnapshot> fetch() async {
    tracker.hit(MemberBranch.starpath);
    return _snapshot();
  }

  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async {
    _version = _version == 0 ? 1 : _version;
    return _snapshot();
  }

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async {
    _version = version + 1;
    _currentOrdinal = (_currentOrdinal + 1).clamp(1, 9);
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
    availability: _version == 0
        ? StarpathAvailability.notStarted
        : StarpathAvailability.available,
    version: _version,
    authority: const StarpathAuthority(
      environment: StarpathEnvironment.beta,
      jurisdiction: 'US',
      capabilityVersion: 1,
      policyVersion: 'starpath-no-advice-v1',
      manifestId: 'fixture-manifest',
      manifestVersion: 'fixture-v1',
    ),
    nodes: List.generate(8, (index) {
      final ordinal = index + 1;
      final part = _previewStarpathParts[index];
      return StarpathNode(
        lessonId: 'fixture-lesson-$ordinal',
        revisionId: 'fixture-revision-$ordinal',
        nodeOrdinal: ordinal,
        pathwayOrdinal: (index ~/ 2) + 1,
        pathwayPosition: (index % 2) + 1,
        title: part.title,
        mythicMnemonic: part.mnemonic,
        factualSummary: part.summary,
        materialLimitations: part.limitations,
        riskContext: part.riskContext,
        recallPrompt: part.recallPrompt,
        rowanExplanation: part.rowanExplanation,
        guide: StarpathGuide(
          tarotKey: part.tarotKey,
          accessibleLabel:
              '${part.title} uses ${part.tarotKey.replaceAll('-', ' ')} only as a memory aid; it predicts nothing.',
        ),
        factualSections: [
          for (
            var lessonIndex = 0;
            lessonIndex < part.lessons.length;
            lessonIndex += 1
          )
            StarpathFactualSection(
              ordinal: lessonIndex + 1,
              kind: StarpathFactualSectionKind.fact,
              heading: part.lessons[lessonIndex].heading,
              body: part.lessons[lessonIndex].body,
              observedAt: DateTime.utc(2026, 8, 31),
              uncertainty: part.lessons[lessonIndex].uncertainty,
              evidence: [
                StarpathEvidence(
                  ordinal: 1,
                  publisher: part.lessons[lessonIndex].publisher,
                  sourceTitle: part.lessons[lessonIndex].sourceTitle,
                  canonicalUrl: Uri.parse(part.lessons[lessonIndex].sourceUrl),
                  claimSummary: 'Supports the reviewed educational definition and risk boundary.',
                  retrievedAt: DateTime.utc(2026, 8, 31),
                  sourceObservedAt: DateTime.utc(2026, 8, 31),
                  currentUntil: DateTime.utc(2027, 2, 28),
                ),
              ],
            ),
        ],
        knowledgeCheck: StarpathKnowledgeCheck(
          id: 'fixture-question-$ordinal',
          prompt: part.checkPrompt,
          options: [
            StarpathKnowledgeCheckOption(
              id: 'fixture-option-$ordinal-a',
              ordinal: 1,
              label: part.correctOption,
            ),
            StarpathKnowledgeCheckOption(
              id: 'fixture-option-$ordinal-b',
              ordinal: 2,
              label: part.distractor,
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
    session: _version == 0
        ? null
        : StarpathSession(
            id: 'fixture-session',
            explicitStart: true,
            startedAt: DateTime.utc(2026, 8, 30),
            lastActionAt: DateTime.utc(2026, 8, 30),
            state: StarpathSessionState.active,
          ),
    progress: _version == 0
        ? null
        : StarpathProgress(
            currentNodeOrdinal: _currentOrdinal,
            version: _version,
            updatedAt: DateTime.utc(2026, 8, 30),
          ),
    theme: _version == 0
        ? null
        : const StarpathTheme(
            id: 'fixture-theme',
            key: 'walk-the-stars',
            title: 'StarPath Foundations',
            horoscopeFrame: 'A memory frame for eight open beginner parts, not a prediction.',
            factualFocus: 'Nineteen short lessons covering ownership, orders, risk, options, news, and process.',
            accessibleLabel: 'Eight immediately accessible investment education parts with nineteen short lessons.',
          ),
    recall: null,
  );
}

class _FixtureSearchService implements SearchService {
  @override
  Future<SearchPage> search(SearchRequest request) async =>
      SearchPage(items: const [], nextCursor: null, hasMore: false);
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
    branchCapabilities: internalPreviewNavigationCapabilities(),
  );
}

class _FixtureSessionRepository implements SessionRepository {
  @override
  MemberClientExpectation get memberClientExpectation =>
      const MemberClientExpectation(
        issuer: 'https://fixture-auth.test/auth/v1',
      );

  @override
  Stream<AuthSession> get recoveredSessions => const Stream.empty();

  @override
  Future<AuthSession?> recover() async =>
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
        key: 'the_emperor',
        alt: 'The Emperor tarot card: a ruler sits on a ram-carved throne before mountains',
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
        riskFooter: 'This simulated scenario explains uncertainty and never tells you to trade.',
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
          'Simulated sample data; prices and signals are fictional.',
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
        publisher: 'Leo Research Desk',
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
    limitations: 'Simulated research only; not investment advice.',
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
      publisher: 'Leo Research Registry',
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
        disclosure: 'Internal preview briefing $briefingId',
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
    body: 'Open Ritual to review the simulated recap.',
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
