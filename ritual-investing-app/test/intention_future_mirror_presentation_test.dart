import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/core/navigation/member_routes.dart';
import 'package:ritual_investing_app/features/future_mirror/application/future_mirror_controller.dart';
import 'package:ritual_investing_app/features/future_mirror/data/repository.dart';
import 'package:ritual_investing_app/features/future_mirror/domain/model.dart';
import 'package:ritual_investing_app/features/future_mirror/presentation/future_mirror_screen.dart';
import 'package:ritual_investing_app/features/intentions/application/intention_controller.dart';
import 'package:ritual_investing_app/features/intentions/data/repository.dart';
import 'package:ritual_investing_app/features/intentions/domain/model.dart';
import 'package:ritual_investing_app/features/intentions/presentation/intention_screen.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/portfolio/application/controller.dart';
import 'package:ritual_investing_app/features/portfolio/data/repository.dart';
import 'package:ritual_investing_app/features/portfolio/domain/model.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';

void main() {
  test('U8 route registry uses stable portfolio, intention, and run IDs', () {
    expect(
      MemberRoutes.futureMirrorRunLocation(
        _portfolioId,
        _intentionId,
        _mirrorId,
      ),
      '/you/portfolios/$_portfolioId/intentions/$_intentionId/'
      'future-mirror/$_mirrorId',
    );
    expect(
      () => MemberRoutes.futureMirrorRunLocation(
        _portfolioId,
        _intentionId,
        'not-a-run',
      ),
      throwsArgumentError,
    );
  });

  testWidgets(
    'Intention creation visibly exposes editable profile defaults and review',
    (tester) async {
      final fixture = _Fixture();
      fixture.intentions.updateProfile(_investor);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: IntentionsScreen(
            portfolioId: _portfolioId,
            controller: fixture.intentions,
            onOpenIntention: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('provider-free'), findsWidgets);
      expect(find.textContaining('not investment advice'), findsOneWidget);
      expect(find.text(_intentionId), findsNothing);
      await tester.tap(find.byKey(const Key('intentions-new')));
      await tester.pump();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('intention-title')))
            .controller
            ?.text,
        'Build a calm fund',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('intention-target-date')))
            .controller
            ?.text,
        '2027-08-25',
      );
      expect(find.textContaining('Calm fund'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('intention-review-create'))).height,
        greaterThanOrEqualTo(48),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('intention-review-create')),
        250,
        scrollable: _verticalScrollable,
      );
      await tester.ensureVisible(
        find.byKey(const Key('intention-review-create')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('intention-review-create')));
      await tester.pump();
      expect(fixture.intentions.phase, IntentionPhase.createReview);
      expect(find.byKey(const Key('intention-confirm-create')), findsOneWidget);
    },
  );

  testWidgets(
    'Future Mirror is usable in dark mode at 2x and shows result authority',
    (tester) async {
      String? openedRun;
      final fixture = _Fixture(
        personalization: const MemberPersonalization(
          riskFraming: MemberRiskFraming.high,
          contributionRhythm: MemberContributionRhythm.weekly,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: FutureMirrorScreen(
            portfolioId: _portfolioId,
            intentionId: _intentionId,
            controller: fixture.mirror,
            intentionController: fixture.intentions,
            portfolioController: fixture.portfolios,
            onOpenRun: (runId) => openedRun = runId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('promise'), findsWidgets);
      expect(find.text(_mirrorId), findsNothing);
      await tester.scrollUntilVisible(
        find.textContaining('Source: Deterministic Demo ledger'),
        300,
        scrollable: _verticalScrollable,
      );
      expect(
        find.textContaining('Source: Deterministic Demo ledger'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Limitation: No real money moves.'),
        300,
        scrollable: _verticalScrollable,
      );
      expect(find.text('Limitation: No real money moves.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('future-mirror-personalization-source')),
        300,
        scrollable: _verticalScrollable,
      );
      expect(find.textContaining('never a predicted return'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const Key('future-mirror-review')),
        300,
        scrollable: _verticalScrollable,
      );

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('future-mirror-low')))
            .controller
            ?.text,
        '-25.0',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('future-mirror-contribution')),
            )
            .controller
            ?.text,
        '100.00',
      );
      expect(tester.takeException(), isNull);

      expect(
        tester.getSize(find.byKey(const Key('future-mirror-review'))).height,
        greaterThanOrEqualTo(48),
      );
      await tester.scrollUntilVisible(
        find.text('Compare'),
        300,
        scrollable: _verticalScrollable,
      );
      await tester.tap(find.text('Compare'));
      expect(openedRun, _mirrorId);
    },
  );
}

final _verticalScrollable = find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

class _Fixture {
  _Fixture({this.personalization = const MemberPersonalization()}) {
    final pendingStore = PendingCommandStore(storage: _Storage());
    intentions = IntentionController(
      repository: _IntentionRepository(),
      pendingStore: pendingStore,
      invalidationBus: bus,
      scope: _scope,
      createKey: () => 'intention-key',
      now: () => DateTime.utc(2026, 8, 25),
    );
    mirror = FutureMirrorController(
      repository: _MirrorRepository(),
      pendingStore: pendingStore,
      invalidationBus: bus,
      scope: _scope,
      createKey: () => 'mirror-key',
      now: () => DateTime.utc(2026, 8, 25),
      personalization: personalization,
    );
    portfolios = PortfolioController(
      repository: _PortfolioRepository(),
      bootstrapDefaultPortfolioId: _portfolioId,
      createKey: () => 'portfolio-key',
    );
  }

  final MemberPersonalization personalization;
  final InvalidationBus bus = InvalidationBus();
  late final IntentionController intentions;
  late final FutureMirrorController mirror;
  late final PortfolioController portfolios;
}

class _IntentionRepository implements IntentionRepository {
  Intention value = _intention;

  @override
  Future<RepositoryRead<IntentionPage>> load({
    String? cursor,
    IntentionStatus? status,
  }) async => RepositoryRead(
    value: IntentionPage(items: [value], hasMore: false),
    isStale: false,
    committedAt: _now,
  );

  @override
  Future<RepositoryRead<Intention>> get(String intentionId) async =>
      RepositoryRead(value: value, isStale: false, committedAt: _now);

  @override
  Future<Intention> create(IntentionCreate command) async {
    value = Intention(
      id: _intentionId,
      portfolioId: command.draft.portfolioId,
      title: command.draft.title,
      targetMinor: command.draft.targetMinor,
      targetDate: command.draft.targetDate,
      status: command.draft.status,
      progressMinor: 0,
      progressBps: 0,
      version: 1,
      demo: _intentionDemo,
    );
    return value;
  }

  @override
  Future<Intention> patch(IntentionPatch command) async => value;

  @override
  Future<void> archive(String intentionId, int expectedVersion) async {}
}

class _MirrorRepository implements FutureMirrorRepository {
  @override
  Future<RepositoryRead<FutureMirror?>> latest(String intentionId) async =>
      RepositoryRead(value: _mirror, isStale: false, committedAt: _now);

  @override
  Future<RepositoryRead<FutureMirror>> get(
    String intentionId,
    String runId,
  ) async => RepositoryRead(value: _mirror, isStale: false, committedAt: _now);

  @override
  Future<FutureMirror> generate(FutureMirrorGenerate command) async => _mirror;

  @override
  Future<List<RepositoryRead<FutureMirror>>> recent(String intentionId) async =>
      [RepositoryRead(value: _mirror, isStale: false, committedAt: _now)];

  @override
  Future<void> remember(FutureMirror value) async {}
}

class _PortfolioRepository implements PortfolioRepository {
  @override
  Future<RepositoryRead<PortfolioCollection>> loadList() async =>
      RepositoryRead(
        value: PortfolioCollection(items: [_portfolio]),
        isStale: false,
        committedAt: _now,
      );

  @override
  Future<RepositoryRead<PortfolioDetail>> loadDetail(
    String portfolioId,
  ) async => RepositoryRead(
    value: PortfolioDetail(
      portfolio: _portfolio,
      holdings: [],
      activity: [],
      snapshots: [],
    ),
    isStale: false,
    committedAt: _now,
  );

  @override
  Future<PortfolioSummary> create({
    required String name,
    required String idempotencyKey,
  }) async => _portfolio;

  @override
  Future<PortfolioSummary> rename({
    required String portfolioId,
    required String name,
    required int expectedVersion,
  }) async => _portfolio;

  @override
  Future<void> archive({
    required String portfolioId,
    required int expectedVersion,
  }) async {}
}

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

const _scope = CacheScope(accountId: 'account-a', resetGeneration: 4);
final _now = DateTime.utc(2026, 8, 25, 12);
const _portfolioId = '00000000-0000-4000-8000-000000000002';
const _intentionId = '00000000-0000-4000-8000-000000000020';
const _mirrorId = '00000000-0000-4000-8000-000000000021';

final _investor = SavedInvestorProfile(
  experience: InvestingExperience.newToInvesting,
  goal: InvestmentGoal.calmFund,
  horizon: InvestmentHorizon.short,
  risk: RiskComfort.moderate,
  contributionRhythm: ContributionRhythm.weekly,
  isDemo: true,
  version: 1,
);

final _intention = Intention(
  id: _intentionId,
  portfolioId: _portfolioId,
  title: 'Build a calm fund',
  targetMinor: 250000,
  targetDate: DateTime.utc(2027, 8, 25),
  status: IntentionStatus.active,
  progressMinor: 50000,
  progressBps: 2000,
  latestProjectionId: _mirrorId,
  version: 2,
  demo: _intentionDemo,
);

final _intentionDemo = IntentionDemoDisclosure(
  isDemo: true,
  observedAt: _now,
  sourceLabel: 'Deterministic Demo ledger',
  limitations: const ['No real money moves.'],
);

final _mirror = FutureMirror(
  id: _mirrorId,
  intentionId: _intentionId,
  assumptions: const FutureMirrorDraft(
    name: 'Calm path',
    monthlyContributionMinor: 10000,
    lowReturnBps: -2500,
    midReturnBps: 750,
    highReturnBps: 4500,
  ),
  points: [
    FutureMirrorPoint(
      date: DateTime.utc(2027, 8, 25),
      lowMinor: 250000,
      midMinor: 275000,
      highMinor: 310000,
    ),
  ],
  generatedAt: _now,
  modelVersion: 'ritual-demo-v1',
  inputHash: 'a' * 64,
  ledgerWatermark: 12,
  uncertainty: 'Illustrative Demo range only; never a guarantee.',
  demo: FutureMirrorDemoDisclosure(
    isDemo: true,
    observedAt: _now,
    sourceLabel: 'Deterministic Demo ledger',
    limitations: const ['No real money moves.'],
  ),
);

final _portfolio = PortfolioSummary(
  id: _portfolioId,
  name: 'Steady orbit',
  cashMinor: 50000,
  valuationMinor: 250000,
  currency: PortfolioCurrency.usd,
  status: PortfolioStatus.active,
  isDefault: true,
  version: 3,
  ledgerWatermark: 12,
  asOfTransactionId: null,
  demo: PortfolioDemoDisclosure(
    isDemo: true,
    observedAt: _now,
    sourceLabel: 'Deterministic Demo ledger',
    limitations: ['No real money moves.'],
  ),
  targetAllocation: [],
);
