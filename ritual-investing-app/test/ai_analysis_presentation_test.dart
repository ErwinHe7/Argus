import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/ai_analysis/application/controller.dart';
import 'package:ritual_investing_app/features/ai_analysis/data/repository.dart';
import 'package:ritual_investing_app/features/ai_analysis/domain/model.dart';
import 'package:ritual_investing_app/features/ai_analysis/presentation/ai_analysis_screen.dart';
import 'package:ritual_investing_app/internal_preview/ai_analysis_fixture.dart';

void main() {
  testWidgets(
    'overview and ChatGPT detail stay auditable and overflow-free at 2x in dark mode',
    (tester) async {
      await _pumpAiAnalysis(tester);

      final screen = find.byKey(const Key('ai-analysis-screen'));
      expect(screen, findsOneWidget);
      expect(Theme.of(tester.element(screen)).brightness, Brightness.dark);
      expect(find.textContaining('Leo Research'), findsOneWidget);
      _expectNoTradeActions();
      _expectNoFlutterException(tester);

      await _expectCategory(
        tester,
        category: AiPortfolioCategory.leoModel,
        title: 'Leo Models',
      );
      await _expectCategory(
        tester,
        category: AiPortfolioCategory.aiSimulation,
        title: 'AI Model Experiments',
      );
      await _expectPortfolioRow(
        tester,
        id: 'chatgpt-simulation',
        name: 'ChatGPT Simulation',
        extraBadge: 'UNOFFICIAL',
      );
      await _expectPortfolioRow(
        tester,
        id: 'claude-simulation',
        name: 'Claude Simulation',
        extraBadge: 'UNOFFICIAL',
      );
      await _expectCategory(
        tester,
        category: AiPortfolioCategory.publicDisclosureTracker,
        title: 'Smart Money',
      );
      await _expectSmartMoneyCard(
        tester,
        id: 'trump-disclosed-purchases-tracker',
        personName: 'Donald Trump',
        majorHoldingIds: const ['trump-nvda', 'trump-msft'],
      );
      await _expectSmartMoneyCard(
        tester,
        id: 'berkshire-disclosure-tracker',
        personName: 'Warren Buffett',
        majorHoldingIds: const ['berkshire-aapl', 'berkshire-axp'],
      );
      await _expectSmartMoneyCard(
        tester,
        id: 'ark-disclosure-tracker',
        personName: 'Cathie Wood',
        majorHoldingIds: const ['ark-tsla', 'ark-coin'],
      );
      await _expectSmartMoneyCard(
        tester,
        id: 'soros-disclosure-tracker',
        personName: 'George Soros',
        majorHoldingIds: const ['soros-amzn', 'soros-tsm'],
      );
      await _expectSmartMoneyCard(
        tester,
        id: 'situational-awareness-leopold-tracker',
        personName: 'Leopold Aschenbrenner',
        majorHoldingIds: const ['situational-sndk', 'situational-mu'],
      );
      expect(
        find.textContaining('Five-name educational sample from'),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Top-five common-stock basket reconstructed from SEC Form 13F-HR',
        ),
        findsNothing,
      );
      _expectNoTradeActions();

      const chatGptId = 'chatgpt-simulation';
      const chatGptPrefix = 'discover-ai-model-$chatGptId';
      final chatGptTitle = _withinKey(
        chatGptPrefix,
        find.text('ChatGPT Simulation'),
      );
      await _scrollTo(tester, chatGptTitle, delta: -560);
      await tester.tap(chatGptTitle);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('discover-ai-detail-$chatGptId')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('discover-ai-detail-back')), findsOneWidget);
      expect(find.text('ChatGPT Simulation'), findsWidgets);
      expect(find.text('BACKTEST'), findsOneWidget);
      expect(find.text('HYPOTHETICAL'), findsOneWidget);
      expect(find.text('UNOFFICIAL SIMULATION'), findsOneWidget);
      _expectNoTradeActions();
      _expectNoFlutterException(tester);

      final chart = find.byKey(
        const Key('discover-ai-detail-$chatGptId-chart'),
      );
      await _scrollTo(tester, chart);
      for (final window in const ['3m', '6m', '1y']) {
        expect(
          find.byKey(Key('discover-ai-detail-$chatGptId-window-$window')),
          findsOneWidget,
        );
      }
      expect(find.text('Historical return'), findsOneWidget);
      expect(chart, findsOneWidget);
      expect(find.byKey(const Key('$chatGptPrefix-benchmark')), findsOneWidget);
      expect(
        find.byKey(const Key('$chatGptPrefix-max-drawdown')),
        findsOneWidget,
      );
      _expectNoFlutterException(tester);

      final calculator = find.byKey(
        const Key('discover-ai-detail-$chatGptId-calculator'),
      );
      await _scrollTo(tester, calculator);
      expect(find.text('Historical return calculator'), findsOneWidget);
      for (final amount in const [1000, 5000, 10000]) {
        expect(
          find.byKey(Key('discover-ai-detail-$chatGptId-amount-$amount')),
          findsOneWidget,
        );
      }
      expect(find.textContaining('Hypothetical only.'), findsOneWidget);
      _expectNoTradeActions();
      _expectNoFlutterException(tester);

      final holdings = find.byKey(const Key('$chatGptPrefix-holdings'));
      await _scrollTo(tester, holdings);
      expect(find.text('Holdings'), findsOneWidget);
      expect(
        find.byKey(const Key('$chatGptPrefix-holdings-as-of')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('$chatGptPrefix-holding-chatgpt-msft')),
        findsOneWidget,
      );
      expect(find.text('MSFT'), findsOneWidget);
      _expectNoFlutterException(tester);

      final sectors = find.byKey(
        const Key('discover-ai-detail-$chatGptId-sectors'),
      );
      await _scrollTo(tester, sectors);
      expect(find.text('Sector allocation'), findsOneWidget);
      expect(sectors, findsOneWidget);
      _expectNoFlutterException(tester);

      await _scrollTo(tester, find.text('How this record was built'));
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Universe'), findsOneWidget);
      expect(find.text('Cadence'), findsOneWidget);
      expect(find.text('Costs'), findsOneWidget);

      final disclosure = find.byKey(const Key('$chatGptPrefix-disclosure'));
      await _scrollTo(tester, disclosure);
      expect(find.text('Read before comparing'), findsOneWidget);
      expect(
        _withinKey(
          '$chatGptPrefix-disclosure',
          find.textContaining(
            'not affiliated with, sponsored by, or endorsed by OpenAI',
          ),
        ),
        findsOneWidget,
      );
      expect(
        _withinKey(
          '$chatGptPrefix-disclosure',
          find.textContaining('Backtests and paper results are hypothetical'),
        ),
        findsOneWidget,
      );
      _expectNoTradeActions();
      _expectNoFlutterException(tester);

      await tester.tap(find.byKey(const Key('discover-ai-detail-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('discover-ai-model-list')), findsOneWidget);
      expect(
        find.byKey(const Key('discover-ai-detail-$chatGptId')),
        findsNothing,
      );
      _expectNoFlutterException(tester);
    },
  );

  testWidgets(
    'every Leo and AI profile keeps its editorial cover and company-logo holding rows at 2x',
    (tester) async {
      final snapshot = buildFixtureAiAnalysisSnapshot();
      final profiles = snapshot.models
          .where(
            (portfolio) =>
                portfolio.category !=
                AiPortfolioCategory.publicDisclosureTracker,
          )
          .toList(growable: false);
      expect(profiles, hasLength(5));
      expect(
        profiles.every((portfolio) => portfolio.visualAssetPath != null),
        isTrue,
      );

      await _pumpAiAnalysis(tester);

      for (final portfolio in profiles) {
        final prefix = 'discover-ai-model-${portfolio.id}';
        final row = find.byKey(Key(prefix));
        await _scrollTo(tester, row);

        final overviewCover = find.byKey(Key('$prefix-cover'));
        expect(overviewCover, findsOneWidget);
        expect(
          find.descendant(of: overviewCover, matching: find.byType(Image)),
          findsOneWidget,
        );
        expect(find.byKey(Key('$prefix-company-logos')), findsOneWidget);

        final visibleHoldings = [...portfolio.holdings]
          ..sort((a, b) => b.weightBps.compareTo(a.weightBps));
        for (final holding in visibleHoldings.take(4)) {
          expect(
            find.byKey(Key('$prefix-company-logo-${holding.id}')),
            findsOneWidget,
          );
        }
        _expectNoFlutterException(tester);

        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(
          find.byKey(Key('discover-ai-detail-${portfolio.id}')),
          findsOneWidget,
        );
        final detailCover = find.byKey(
          Key('discover-ai-detail-${portfolio.id}-cover'),
        );
        expect(detailCover, findsOneWidget);
        expect(
          find.descendant(of: detailCover, matching: find.byType(Image)),
          findsOneWidget,
        );
        expect(
          find.byKey(Key('discover-ai-detail-${portfolio.id}-company-logos')),
          findsOneWidget,
        );
        for (final holding in visibleHoldings.take(4)) {
          expect(
            find.byKey(
              Key(
                'discover-ai-detail-${portfolio.id}-company-logo-${holding.id}',
              ),
            ),
            findsOneWidget,
          );
        }

        final holdings = find.byKey(Key('$prefix-holdings'));
        await _scrollTo(tester, holdings);
        for (final holding in portfolio.holdings) {
          expect(
            find.byKey(Key('$prefix-holding-${holding.id}')),
            findsOneWidget,
          );
          expect(
            find.byKey(Key('$prefix-holding-${holding.id}-logo')),
            findsOneWidget,
          );
        }
        _expectNoTradeActions();
        _expectNoFlutterException(tester);

        await tester.tap(find.byKey(const Key('discover-ai-detail-back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('discover-ai-model-list')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'each Smart Money card keeps its portrait-led overview and opens auditable holdings',
    (tester) async {
      final snapshot = buildFixtureAiAnalysisSnapshot();
      await _pumpAiAnalysis(tester);

      const profiles =
          <({String id, String personName, String firstHoldingId})>[
            (
              id: 'trump-disclosed-purchases-tracker',
              personName: 'Donald Trump',
              firstHoldingId: 'trump-nvda',
            ),
            (
              id: 'berkshire-disclosure-tracker',
              personName: 'Warren Buffett',
              firstHoldingId: 'berkshire-aapl',
            ),
            (
              id: 'ark-disclosure-tracker',
              personName: 'Cathie Wood',
              firstHoldingId: 'ark-tsla',
            ),
            (
              id: 'soros-disclosure-tracker',
              personName: 'George Soros',
              firstHoldingId: 'soros-amzn',
            ),
            (
              id: 'situational-awareness-leopold-tracker',
              personName: 'Leopold Aschenbrenner',
              firstHoldingId: 'situational-sndk',
            ),
          ];

      for (final profile in profiles) {
        final portfolio = snapshot.models.singleWhere(
          (candidate) => candidate.id == profile.id,
        );
        final card = find.byKey(Key('discover-ai-smart-money-${profile.id}'));
        await _scrollTo(tester, card);
        expect(
          find.descendant(of: card, matching: find.text(profile.personName)),
          findsOneWidget,
        );

        await tester.tap(card);
        await tester.pumpAndSettle();

        expect(
          find.byKey(Key('discover-ai-detail-${profile.id}')),
          findsOneWidget,
        );
        final detailPortrait = find.byKey(
          Key('discover-ai-detail-smart-money-${profile.id}-portrait'),
        );
        expect(detailPortrait, findsOneWidget);
        expect(
          find.descendant(of: detailPortrait, matching: find.byType(Image)),
          findsOneWidget,
        );
        expect(
          find.byKey(
            Key('discover-ai-detail-smart-money-${profile.id}-allocation'),
          ),
          findsOneWidget,
        );
        final holdings = find.byKey(
          Key('discover-ai-model-${profile.id}-holdings'),
        );
        await _scrollTo(tester, holdings);
        expect(
          find.descendant(of: holdings, matching: find.text('Holdings')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            Key(
              'discover-ai-model-${profile.id}-holding-${profile.firstHoldingId}',
            ),
          ),
          findsOneWidget,
        );
        for (final holding in portfolio.holdings) {
          expect(
            find.byKey(
              Key('discover-ai-model-${profile.id}-holding-${holding.id}-logo'),
            ),
            findsOneWidget,
          );
        }
        _expectNoTradeActions();
        _expectNoFlutterException(tester);

        await tester.tap(find.byKey(const Key('discover-ai-detail-back')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('discover-ai-model-list')), findsOneWidget);
      }
    },
  );

  testWidgets(
    'Trump tracker presents dated disclosed purchases as a simulation, never current holdings or copy trading',
    (tester) async {
      await _pumpAiAnalysis(tester);

      const id = 'trump-disclosed-purchases-tracker';
      const prefix = 'discover-ai-model-$id';
      final card = find.byKey(const Key('discover-ai-smart-money-$id'));
      await _scrollTo(tester, card);
      expect(
        find.descendant(of: card, matching: find.text('Donald Trump')),
        findsOneWidget,
      );
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('discover-ai-detail-$id')), findsOneWidget);
      expect(find.text('BACKTEST'), findsOneWidget);
      expect(find.text('FILING-BASED'), findsOneWidget);
      expect(find.text('DELAYED PUBLIC DISCLOSURE'), findsOneWidget);

      final source = find.textContaining(
        'received 2026-05-12 and certified 2026-05-13',
      );
      await _scrollTo(tester, source);
      expect(source, findsOneWidget);
      expect(
        find.textContaining(r'$1,000,001-$5,000,000 range'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not Donald Trump\'s actual portfolio return'),
        findsOneWidget,
      );
      expect(
        find.textContaining('current positions are not established'),
        findsOneWidget,
      );

      final period = find.byKey(const Key('$prefix-period'));
      await _scrollTo(tester, period);
      expect(tester.widget<Text>(period).data, '2026-05-14 – 2026-08-28');
      final holdings = find.byKey(const Key('$prefix-holdings'));
      await _scrollTo(tester, holdings);
      expect(
        find.byKey(const Key('$prefix-holding-trump-nvda-logo')),
        findsOneWidget,
      );
      _expectNoTradeActions();
      _expectNoFlutterException(tester);
    },
  );

  testWidgets(
    'Leopold tracker shows its exact tradable period and delayed 13F source',
    (tester) async {
      await _pumpAiAnalysis(tester);

      const id = 'situational-awareness-leopold-tracker';
      const prefix = 'discover-ai-model-$id';
      final card = find.byKey(const Key('discover-ai-smart-money-$id'));
      await _scrollTo(tester, card);
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('discover-ai-detail-$id')), findsOneWidget);
      expect(find.text('BACKTEST'), findsOneWidget);
      expect(find.text('FILING-BASED'), findsOneWidget);
      expect(find.text('DELAYED PUBLIC DISCLOSURE'), findsOneWidget);
      _expectNoTradeActions();
      _expectNoFlutterException(tester);

      final sourceDisclosure = find.textContaining(
        'Top-five common-stock basket reconstructed from SEC Form 13F-HR',
      );
      await _scrollTo(tester, sourceDisclosure);
      expect(sourceDisclosure, findsOneWidget);
      expect(find.textContaining('filed 2026-08-14'), findsOneWidget);
      expect(
        find.textContaining(
          'The simulation begins at the next tradable close, 2026-08-17',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('13F data are delayed and incomplete'),
        findsOneWidget,
      );
      _expectNoFlutterException(tester);

      final period = find.byKey(const Key('$prefix-period'));
      await _scrollTo(tester, period);
      expect(tester.widget<Text>(period).data, '2026-08-17 – 2026-08-28');
      expect(
        find.byKey(const Key('discover-ai-detail-$id-chart')),
        findsOneWidget,
      );
      _expectNoFlutterException(tester);

      final disclosure = find.byKey(const Key('$prefix-disclosure'));
      await _scrollTo(tester, disclosure);
      expect(
        _withinKey(
          '$prefix-disclosure',
          find.textContaining(
            'No affiliation with or endorsement by Leopold Aschenbrenner',
          ),
        ),
        findsOneWidget,
      );
      expect(
        _withinKey(
          '$prefix-disclosure',
          find.textContaining(
            'options, shorts, private assets, and smaller names are omitted',
          ),
        ),
        findsOneWidget,
      );
      expect(
        _withinKey(
          '$prefix-disclosure',
          find.textContaining('not a recommendation to buy or sell'),
        ),
        findsOneWidget,
      );
      _expectNoTradeActions();
      _expectNoFlutterException(tester);
    },
  );
}

Future<void> _pumpAiAnalysis(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final snapshot = buildFixtureAiAnalysisSnapshot();
  final controller = AiAnalysisController(
    repository: AiAnalysisRepository(
      service: _FixtureAiAnalysisService(snapshot),
    ),
    utcClock: () => DateTime.utc(2026, 9, 1, 12),
  );
  addTearDown(controller.dispose);
  await controller.load();
  expect(controller.state.phase, LoadPhase.ready);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: AiAnalysisScreen(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectCategory(
  WidgetTester tester, {
  required AiPortfolioCategory category,
  required String title,
}) async {
  final categoryFinder = find.byKey(
    Key('discover-ai-category-${category.name}'),
  );
  await _scrollTo(tester, categoryFinder);
  expect(
    find.descendant(of: categoryFinder, matching: find.text(title)),
    findsOneWidget,
  );
}

Future<void> _expectPortfolioRow(
  WidgetTester tester, {
  required String id,
  required String name,
  required String extraBadge,
}) async {
  final prefix = 'discover-ai-model-$id';
  final row = find.byKey(Key(prefix));
  final title = _withinKey(prefix, find.text(name));
  await _scrollTo(tester, title);
  expect(row, findsOneWidget);
  expect(title, findsOneWidget);
  expect(_withinKey(prefix, find.text('BACKTEST')), findsOneWidget);
  expect(_withinKey(prefix, find.text('HYPOTHETICAL')), findsOneWidget);
  expect(_withinKey(prefix, find.text(extraBadge)), findsOneWidget);
  expect(find.byKey(Key('$prefix-period')), findsOneWidget);
  expect(find.byKey(Key('$prefix-return')), findsOneWidget);
  expect(find.byKey(Key('$prefix-benchmark')), findsOneWidget);
  expect(find.byKey(Key('$prefix-max-drawdown')), findsOneWidget);
  _expectNoFlutterException(tester);
}

Future<void> _expectSmartMoneyCard(
  WidgetTester tester, {
  required String id,
  required String personName,
  required List<String> majorHoldingIds,
}) async {
  final prefix = 'discover-ai-smart-money-$id';
  final card = find.byKey(Key(prefix));
  await _scrollTo(tester, card);
  expect(card, findsOneWidget);
  expect(find.byKey(Key('$prefix-person')), findsOneWidget);
  expect(
    tester.widget<Text>(find.byKey(Key('$prefix-person'))).data,
    personName,
  );
  final portrait = find.byKey(Key('$prefix-portrait'));
  expect(portrait, findsOneWidget);
  expect(
    find.descendant(of: portrait, matching: find.byType(Image)),
    findsOneWidget,
  );
  expect(find.byKey(Key('$prefix-allocation')), findsOneWidget);
  expect(find.byKey(Key('discover-ai-model-$id-return')), findsOneWidget);
  expect(find.byKey(Key('discover-ai-model-$id-period')), findsOneWidget);
  expect(find.byKey(Key('$prefix-updated')), findsOneWidget);
  expect(find.byKey(Key('$prefix-disclosure')), findsOneWidget);
  for (final holdingId in majorHoldingIds) {
    expect(find.byKey(Key('$prefix-holding-$holdingId')), findsOneWidget);
    expect(find.byKey(Key('$prefix-holding-$holdingId-logo')), findsOneWidget);
  }
  _expectNoFlutterException(tester);
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  double delta = 520,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
  expect(finder, findsAtLeastNWidgets(1));
  _expectNoFlutterException(tester);
}

void _expectNoTradeActions() {
  expect(find.text('Buy'), findsNothing);
  expect(find.text('Copy'), findsNothing);
  expect(find.text('Follow'), findsNothing);
}

void _expectNoFlutterException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

Finder _withinKey(String key, Finder matching) =>
    find.descendant(of: find.byKey(Key(key)), matching: matching);

class _FixtureAiAnalysisService implements AiAnalysisService {
  const _FixtureAiAnalysisService(this.snapshot);

  final AiAnalysisSnapshot snapshot;

  @override
  Future<AiAnalysisSnapshot> fetch() async => snapshot;
}
