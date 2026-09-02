import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/asset_codex/application/controller.dart';
import 'package:ritual_investing_app/features/asset_codex/data/repository.dart';
import 'package:ritual_investing_app/features/asset_codex/domain/model.dart';
import 'package:ritual_investing_app/features/asset_codex/presentation/asset_codex_screen.dart';
import 'package:ritual_investing_app/features/search/application/controller.dart'
    as search;
import 'package:ritual_investing_app/features/search/data/repository.dart';
import 'package:ritual_investing_app/features/search/domain/model.dart';

void main() {
  test(
    'ritual source preserves identity, evidence, risk, Demo, and save state',
    () async {
      final service = _AssetService();
      final controller = AssetCodexController(
        repository: AssetCodexRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
        assetId: _assetId,
        source: const AssetSourceContext(
          kind: AssetSourceKind.ritual,
          resourceId: _assignmentId,
        ),
      );

      await controller.load();

      final value = controller.state.value!;
      expect(value.id, _assetId);
      expect(value.revisionId, _revisionId);
      expect(value.source.kind, AssetSourceKind.ritual);
      expect(value.source.resourceId, _assignmentId);
      expect(value.evidence.single.claimId, _claimId);
      expect(value.risks.single.severity, AssetRiskSeverity.high);
      expect(value.demo.isDemo, isTrue);
      expect(value.saved, isFalse);
    },
  );

  test(
    'ambiguous save refetches authoritative detail without optimistic state',
    () async {
      final service = _AssetService(failSaveAfterCommit: true);
      final controller = AssetCodexController(
        repository: AssetCodexRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
        assetId: _assetId,
        source: const AssetSourceContext(kind: AssetSourceKind.search),
      );
      await controller.load();

      final operation = controller.toggleSaved();
      expect(controller.state.value!.saved, isFalse);
      await operation;

      expect(service.saveCalls, 1);
      expect(service.detailCalls, 2);
      expect(controller.state.value!.saved, isTrue);
      expect(controller.savePhase, AssetSavePhase.reconciled);
    },
  );

  test('compare preserves revision and metric observation time', () async {
    final service = _AssetService();
    final controller = AssetCodexController(
      repository: AssetCodexRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
      assetId: _assetId,
      source: const AssetSourceContext(kind: AssetSourceKind.direct),
    );

    await controller.compareWith(const [_peerId]);

    expect(controller.comparisonState.phase, LoadPhase.ready);
    final item = controller.comparisonState.value!.items.first;
    expect(item.asset.revisionId, _revisionId);
    expect(item.metric.observedAt, DateTime.utc(2026, 8, 25, 12));
    expect(service.comparedIds, [_assetId, _peerId]);
  });

  testWidgets('compare searches for a peer then renders server comparison', (
    tester,
  ) async {
    final service = _AssetService();
    final controller = AssetCodexController(
      repository: AssetCodexRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
      assetId: _assetId,
      source: const AssetSourceContext(kind: AssetSourceKind.direct),
    );
    final searchController = search.SearchController(
      repository: SearchRepository(service: _PeerSearchService()),
      debounce: Duration.zero,
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AssetCodexScreen(
          controller: controller,
          rowanController: null,
          searchController: searchController,
          personalization: const MemberPersonalization(),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('asset-compare')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('asset-compare')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('codex-search-field')), 'peer');
    await tester.pumpAndSettle();
    await tester.tap(find.text('PEER · Peer Demo Fund'));
    await tester.pumpAndSettle();

    expect(service.comparedIds, [_assetId, _peerId]);
    expect(find.byKey(const Key('asset-comparison-results')), findsOneWidget);
    expect(find.text('Compared research'), findsOneWidget);
  });
}

const _assetId = '00000000-0000-4000-8000-000000000201';
const _peerId = '00000000-0000-4000-8000-000000000202';
const _revisionId = '00000000-0000-4000-8000-000000000203';
const _assignmentId = '00000000-0000-4000-8000-000000000101';
const _claimId = '00000000-0000-4000-8000-000000000204';

class _AssetService implements AssetCodexService {
  _AssetService({this.failSaveAfterCommit = false});

  final bool failSaveAfterCommit;
  bool saved = false;
  int saveCalls = 0;
  int detailCalls = 0;
  List<String> comparedIds = const [];

  @override
  Future<AssetCodex> fetchDetail(String assetId) async {
    detailCalls += 1;
    return _asset(saved: saved);
  }

  @override
  Future<List<AssetEvidenceDetail>> fetchEvidence(String assetId) async =>
      _asset(saved: saved).detailedEvidence;

  @override
  Future<List<AssetMetric>> fetchMetrics(String assetId) async => [_metric()];

  @override
  Future<AssetComparison> compare(List<String> assetIds) async {
    comparedIds = List.of(assetIds);
    return AssetComparison(
      items: [
        AssetComparisonItem(
          asset: _asset(saved: saved).summary,
          metric: _metric(),
          riskCount: 1,
        ),
      ],
      comparedAt: DateTime.utc(2026, 8, 25, 12, 1),
      demo: _demo(),
    );
  }

  @override
  Future<void> save(String assetId, AssetSourceContext source) async {
    saveCalls += 1;
    saved = true;
    if (failSaveAfterCommit) throw const AssetAmbiguousMutation();
  }

  @override
  Future<void> unsave(String assetId) async => saved = false;
}

class _PeerSearchService implements SearchService {
  @override
  Future<SearchPage> search(SearchRequest request) async => SearchPage(
    items: const [
      SearchItem(
        id: _peerId,
        revisionId: '00000000-0000-4000-8000-000000000205',
        kind: SearchKind.asset,
        title: 'Peer Demo Fund',
        subtitle: 'Provider-free comparison peer',
        symbol: 'PEER',
        isDemo: true,
      ),
    ],
    nextCursor: null,
    hasMore: false,
  );
}

AssetCodex _asset({required bool saved}) => AssetCodex(
  id: _assetId,
  revisionId: _revisionId,
  slug: 'quiet-power-etf',
  symbol: 'QPW',
  name: 'Quiet Power ETF',
  kind: AssetKind.etf,
  currency: 'USD',
  appearanceReason: 'Durable fictional scenario signal.',
  thesis: 'A Demo research thesis, never a buy instruction.',
  limitations: 'No live market or provider data.',
  metricsAsOf: DateTime.utc(2026, 8, 25, 12),
  evidence: [
    AssetEvidenceSummary(
      claimId: _claimId,
      factorLabel: 'Durability',
      observedAt: DateTime.utc(2026, 8, 25, 12),
      summary: 'The Demo signal held its range.',
      uncertainty: 'It can reverse.',
    ),
  ],
  detailedEvidence: [
    AssetEvidenceDetail(
      claimId: _claimId,
      factorLabel: 'Durability',
      observedAt: DateTime.utc(2026, 8, 25, 12),
      summary: 'The Demo signal held its range.',
      uncertainty: 'It can reverse.',
      publisher: 'Demo Research Desk',
      sourceTitle: 'Provider-free research note',
      sourceUrl: Uri.parse('https://example.invalid/note'),
      publishedAt: DateTime.utc(2026, 8, 25, 11),
    ),
  ],
  risks: const [
    AssetRisk(
      title: 'Scenario reversal',
      detail: 'The observed pattern can change.',
      severity: AssetRiskSeverity.high,
    ),
  ],
  saved: saved,
  demo: _demo(),
  source: const AssetSourceContext(kind: AssetSourceKind.direct),
);

AssetMetric _metric() => AssetMetric(
  priceMinor: 12345,
  changeBps: 31,
  expenseRatioBps: 20,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Deterministic fixture',
  demo: _demo(),
);

AssetDemoDisclosure _demo() => AssetDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Deterministic fixture',
  limitations: const ['Fictional scenario; no live market provider.'],
);
