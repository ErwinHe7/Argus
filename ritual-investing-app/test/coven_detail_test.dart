import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/coven/application/controller.dart';
import 'package:ritual_investing_app/features/coven/data/repository.dart';
import 'package:ritual_investing_app/features/coven/domain/model.dart';
import 'package:ritual_investing_app/features/coven/presentation/coven_detail_screen.dart';
import 'package:ritual_investing_app/features/rowan/application/controller.dart';
import 'package:ritual_investing_app/features/rowan/data/repository.dart';
import 'package:ritual_investing_app/features/rowan/domain/model.dart';

void main() {
  test(
    'Coven detail preserves qualification dates, sources, and save state',
    () async {
      final service = _CovenService();
      final controller = CovenDetailController(
        entryId: _entryId,
        repository: CovenRepository(service: service, cache: MemoryReadCache()),
      );

      await controller.load();

      expect(controller.state.phase, LoadPhase.ready);
      final value = controller.state.value!;
      expect(value.id, _entryId);
      expect(value.revisionId, _revisionId);
      expect(
        value.qualifications.single.category,
        CovenQualificationCategory.founder,
      );
      expect(
        value.qualifications.single.verifiedAsOf,
        DateTime.utc(2026, 8, 25),
      );
      expect(value.evidence.single.sourceUrl.host, 'example.invalid');
      expect(value.saved, isFalse);

      await controller.toggleSaved();

      expect(service.saveCalls, 1);
      expect(controller.state.value!.saved, isTrue);
      expect(controller.savePhase, CovenSavePhase.saved);
    },
  );

  test('ambiguous Coven save reconciles authoritative server state', () async {
    final service = _CovenService(loseFirstSaveResponse: true);
    final controller = CovenDetailController(
      entryId: _entryId,
      repository: CovenRepository(service: service, cache: MemoryReadCache()),
    );
    await controller.load();

    await controller.toggleSaved();

    expect(service.saveCalls, 1);
    expect(service.saved, isTrue);
    expect(controller.state.value!.saved, isTrue);
    expect(controller.savePhase, CovenSavePhase.reconciled);
  });

  testWidgets('Coven and Rowan remain usable at 2x text in light mode', (
    tester,
  ) async {
    final detail = CovenDetailController(
      entryId: _entryId,
      repository: CovenRepository(
        service: _CovenService(),
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
    await detail.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: CovenDetailScreen(controller: detail, rowanController: rowan),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Woman founder'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Woman founder'), findsOneWidget);
    expect(find.textContaining('Verified Aug 25, 2026'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Demo Registry'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Demo Registry'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rowan-explain')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('not investment advice'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rowan-explain')));
    await tester.pumpAndSettle();

    expect(rowanService.request?.surface, RowanSurface.coven);
    expect(rowanService.request?.resourceId, _entryId);
    expect(
      find.text('Qualification evidence is dated, not assumed.'),
      findsOneWidget,
    );
  });
}

const _entryId = '00000000-0000-4000-8000-000000000721';
const _revisionId = '00000000-0000-4000-8000-000000000722';

class _CovenService implements CovenService {
  _CovenService({this.loseFirstSaveResponse = false});

  final bool loseFirstSaveResponse;
  bool saved = false;
  int saveCalls = 0;
  bool _saveResponseLost = false;

  @override
  Future<CovenModel> fetch() async => CovenModel(entries: [_summary()]);

  @override
  Future<CovenDetail> fetchDetail(String entryId) async =>
      _detail(saved: saved);

  @override
  Future<List<CovenEvidenceDetail>> fetchEvidence(String entryId) async =>
      _detail(saved: saved).evidence;

  @override
  Future<void> save(String entryId) async {
    saveCalls += 1;
    saved = true;
    if (loseFirstSaveResponse && !_saveResponseLost) {
      _saveResponseLost = true;
      throw const CovenAmbiguousMutation();
    }
  }

  @override
  Future<void> unsave(String entryId) async => saved = false;
}

class _RowanService implements RowanService {
  RowanRequest? request;

  @override
  Future<RowanCounselResult> fetch(RowanRequest request) async {
    this.request = request;
    return const RowanCounselResult(
      scriptRevisionId: '00000000-0000-4000-8000-000000000723',
      surface: RowanSurface.coven,
      body: 'Qualification evidence is dated, not assumed.',
      riskFooter: 'Demo only; not investment advice.',
    );
  }
}

CovenEntry _summary() => CovenEntry(
  id: _entryId,
  revisionId: _revisionId,
  slug: 'aurora-healthworks',
  name: 'Aurora Healthworks',
  symbol: 'AUR',
  category: CovenQualificationCategory.founder,
  focus: 'Preventive care',
  teaser: 'Fictional provider-free company.',
  effectiveDate: DateTime.utc(2026, 8, 1),
  verifiedAsOf: DateTime.utc(2026, 8, 25),
  demo: _demo,
);

CovenDetail _detail({required bool saved}) => CovenDetail(
  id: _entryId,
  revisionId: _revisionId,
  slug: 'aurora-healthworks',
  company: 'Aurora Healthworks',
  symbol: 'AUR',
  focus: 'Preventive care',
  summary: 'A fictional provider-free company profile.',
  inclusionRationale: 'Included because dated founder evidence is available.',
  limitations: 'Seeded Demo content; not investment advice.',
  qualifications: [
    CovenQualification(
      category: CovenQualificationCategory.founder,
      personName: 'Avery North',
      effectiveDate: DateTime.utc(2026, 8, 1),
      verifiedAsOf: DateTime.utc(2026, 8, 25),
      validTo: null,
      evidence: const [],
    ),
  ],
  evidence: [
    CovenEvidenceDetail(
      claimId: '00000000-0000-4000-8000-000000000724',
      factorLabel: 'Founder qualification',
      observedAt: DateTime.utc(2026, 8, 25, 12),
      summary: 'The Demo registry identifies the fictional founder.',
      uncertainty: 'Seeded content can be revised.',
      publisher: 'Demo Registry',
      sourceTitle: 'Aurora founder record',
      sourceUrl: Uri.parse('https://example.invalid/aurora-founder'),
      publishedAt: DateTime.utc(2026, 8, 24),
    ),
  ],
  saved: saved,
  demo: _demo,
);

final _demo = CovenDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Deterministic Coven fixture',
  limitations: const ['Fictional qualification scenario.'],
);
