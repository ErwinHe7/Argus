import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_screen.dart';
import 'package:ritual_investing_app/features/rowan/application/controller.dart';
import 'package:ritual_investing_app/features/rowan/data/repository.dart';
import 'package:ritual_investing_app/features/rowan/domain/model.dart';
import 'package:ritual_investing_app/features/search/application/controller.dart'
    as member_search;
import 'package:ritual_investing_app/features/search/data/repository.dart';
import 'package:ritual_investing_app/features/search/domain/model.dart';
import 'package:ritual_investing_app/features/search/presentation/search_screen.dart';

void main() {
  testWidgets(
    'evidence opens while loading, retries live, and uses evidence Rowan context',
    (tester) async {
      final service = _RitualService(evidenceFailures: 1);
      final ritual = DailyRitualController(
        repository: DailyRitualRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      final rowanService = _RowanService();
      final rowan = RowanController(
        repository: RowanRepository(
          service: rowanService,
          cache: MemoryReadCache(),
        ),
      );
      await ritual.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DailyRitualScreen(
              controller: ritual,
              onOpenCoven: () {},
              onToggleTheme: () {},
              rowanController: rowan,
              personalization: const MemberPersonalization(
                ritualVoice: MemberRitualVoice.practical,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Market-informed Demo evidence'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ritual-evidence-sheet')), findsOneWidget);
      expect(find.byKey(const Key('state-retryableFailure')), findsOneWidget);
      final evidenceScrollable = find.descendant(
        of: find.byKey(const Key('ritual-evidence-sheet')),
        matching: find.byType(Scrollable),
      );
      expect(evidenceScrollable, findsOneWidget);
      final evidencePosition = tester
          .state<ScrollableState>(evidenceScrollable)
          .position;
      expect(evidencePosition.maxScrollExtent, greaterThan(0));
      evidencePosition.jumpTo(evidencePosition.maxScrollExtent);
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      evidencePosition.jumpTo(0);
      await tester.pump();
      expect(find.textContaining('Demo Research Desk'), findsOneWidget);

      evidencePosition.jumpTo(evidencePosition.maxScrollExtent);
      await tester.pump();
      await tester.tap(find.byKey(const Key('rowan-explain')));
      await tester.pumpAndSettle();
      expect(rowanService.request?.surface, RowanSurface.evidence);
      expect(rowanService.request?.resourceId, _assignmentId);
      expect(
        find.text('Evidence stays separate from interpretation.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'history stays usable at large text and shows authoritative lifecycle',
    (tester) async {
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: _RitualService(),
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: DailyRitualScreen(
              controller: controller,
              onOpenCoven: () {},
              onToggleTheme: () {},
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('ritual-history')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('ritual-history')));
      await tester.pumpAndSettle();

      expect(find.text('Ritual history'), findsWidgets);
      expect(find.textContaining('Completed'), findsOneWidget);
      expect(find.textContaining('Tarot'), findsOneWidget);
      expect(find.textContaining('Aug 25, 2026'), findsOneWidget);
      expect(find.textContaining('Demo'), findsWidgets);
    },
  );

  testWidgets('shared search restores the retained visible query', (
    tester,
  ) async {
    final controller = member_search.SearchController(
      repository: SearchRepository(service: _SearchService()),
      debounce: Duration.zero,
    );
    controller.updateQuery('vig');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SearchScreen(controller: controller, onOpenAsset: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('codex-search-field')),
    );
    expect(field.controller?.text, 'vig');
    expect(find.text('VIG · Vigilant Demo ETF'), findsOneWidget);
  });
}

const _assignmentId = '00000000-0000-4000-8000-000000000501';
const _assetId = '00000000-0000-4000-8000-000000000502';

class _RitualService implements DailyRitualService {
  _RitualService({this.evidenceFailures = 0});

  int evidenceFailures;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async => _ritual();

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async => _ritual();

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async {
    if (evidenceFailures > 0) {
      evidenceFailures -= 1;
      throw const LoadFailure(LoadPhase.retryableFailure);
    }
    return [
      RitualEvidenceDetail(
        claimId: '00000000-0000-4000-8000-000000000503',
        factorLabel: 'Provider-free durability',
        observedAt: DateTime.utc(2026, 8, 25, 12),
        summary: 'The Demo scenario held its fictional range.',
        uncertainty: 'It can reverse.',
        source: RitualEvidenceSource(
          publisher: 'Demo Research Desk',
          title: 'Provider-free evidence note',
          url: Uri.parse('https://example.invalid/evidence'),
          publishedAt: DateTime.utc(2026, 8, 25, 11),
        ),
      ),
    ];
  }

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      RitualHistoryPage(
        items: [RitualHistoryEntry.fromRitual(_ritual())],
        nextCursor: null,
        hasMore: false,
      );

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) async =>
      _ritual();

  @override
  Future<DailyRitual> complete(String assignmentId, int version) async =>
      _ritual();
}

class _RowanService implements RowanService {
  RowanRequest? request;

  @override
  Future<RowanCounselResult> fetch(RowanRequest request) async {
    this.request = request;
    return const RowanCounselResult(
      scriptRevisionId: '00000000-0000-4000-8000-000000000504',
      surface: RowanSurface.evidence,
      body: 'Evidence stays separate from interpretation.',
      riskFooter: 'Demo only; not investment advice.',
    );
  }
}

class _SearchService implements SearchService {
  @override
  Future<SearchPage> search(SearchRequest request) async => SearchPage(
    items: const [
      SearchItem(
        id: _assetId,
        revisionId: '00000000-0000-4000-8000-000000000505',
        kind: SearchKind.asset,
        title: 'Vigilant Demo ETF',
        subtitle: 'Provider-free Demo result',
        symbol: 'VIG',
        isDemo: true,
      ),
    ],
    nextCursor: null,
    hasMore: false,
  );
}

DailyRitual _ritual() => DailyRitual(
  assignmentId: _assignmentId,
  date: DateTime.utc(2026, 8, 25),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(
    id: '00000000-0000-4000-8000-000000000506',
    number: 1,
  ),
  title: 'Direction, not urgency.',
  art: const RitualArt(key: 'the_compass', alt: 'The Compass'),
  interpretation: 'Direction is an invitation, not an instruction.',
  guidance: 'Inspect sources before choosing what to research.',
  marketLabel: 'Market-informed Demo evidence',
  ideas: const [
    RitualIdea(
      assetId: _assetId,
      symbol: 'VIG',
      name: 'Vigilant Demo ETF',
      appearanceReason: 'provider-free durability',
      riskSummary: 'The scenario can reverse.',
    ),
  ],
  evidence: const [],
  rowan: const RitualCounsel(
    scriptRevisionId: '00000000-0000-4000-8000-000000000507',
    surface: 'daily_ritual',
    body: 'Notice without rushing.',
    riskFooter: 'Demo counsel; not advice.',
  ),
  version: 3,
  state: DailyRitualState.completed,
  revealedAt: null,
  completedAt: null,
  demo: RitualDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25, 12),
    sourceLabel: 'Deterministic fixture',
    limitations: const ['Fictional scenario; no live provider.'],
  ),
);
