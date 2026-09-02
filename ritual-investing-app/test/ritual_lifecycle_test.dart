import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';

void main() {
  test(
    'reveal and complete each send one current version and refresh history',
    () async {
      final service = _LifecycleService();
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );

      await controller.load();
      await Future.wait([controller.reveal(), controller.reveal()]);

      expect(service.revealVersions, [1]);
      expect(controller.state.value?.state, DailyRitualState.revealed);
      expect(
        controller.historyState.value?.items.single.state,
        DailyRitualState.revealed,
      );

      await Future.wait([controller.complete(), controller.complete()]);

      expect(service.completeVersions, [2]);
      expect(controller.state.value?.state, DailyRitualState.completed);
      expect(
        controller.historyState.value?.items.single.state,
        DailyRitualState.completed,
      );
    },
  );

  test(
    'ambiguous reveal refetches assignment instead of sending again',
    () async {
      final service = _LifecycleService(failRevealAfterCommit: true);
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );

      await controller.load();
      await controller.reveal();

      expect(service.revealVersions, [1]);
      expect(service.assignmentReads, 1);
      expect(controller.state.value?.state, DailyRitualState.revealed);
      expect(controller.mutationPhase, RitualMutationPhase.reconciled);
    },
  );

  test('successful reveal does not wait for ritual history refresh', () async {
    final history = Completer<RitualHistoryPage>();
    final service = _LifecycleService(historyGate: history);
    final controller = DailyRitualController(
      repository: DailyRitualRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
    );

    await controller.load();
    await controller.reveal(waitForHistory: false);

    expect(controller.state.value?.state, DailyRitualState.revealed);
    expect(controller.historyState.phase, LoadPhase.loading);

    history.complete(service.historyPage);
    await Future<void>.delayed(Duration.zero);
    expect(controller.historyState.phase, LoadPhase.ready);
  });

  test('a late reveal history response cannot replace completed history', () async {
    final service = _OutOfOrderHistoryService();
    final controller = DailyRitualController(
      repository: DailyRitualRepository(
        service: service,
        cache: MemoryReadCache(),
      ),
    );

    await controller.load();
    await controller.reveal(waitForHistory: false);
    final completion = controller.complete();
    await Future<void>.delayed(Duration.zero);

    service.completeHistory.complete(
      service.pageFor(DailyRitualState.completed),
    );
    await completion;
    service.revealHistory.complete(service.pageFor(DailyRitualState.revealed));
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.historyState.value?.items.single.state,
      DailyRitualState.completed,
    );
  });

  test(
    'evidence loads complete source context independently of interpretation',
    () async {
      final service = _LifecycleService();
      final controller = DailyRitualController(
        repository: DailyRitualRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );

      await controller.load();
      await controller.loadEvidence();

      final evidence = controller.evidenceState.value!.single;
      expect(evidence.claimId, 'claim-1');
      expect(evidence.source.publisher, 'Demo Research Desk');
      expect(evidence.observedAt, DateTime.utc(2026, 8, 25, 12));
      expect(evidence.uncertainty, contains('change'));
    },
  );
}

class _LifecycleService implements DailyRitualService {
  _LifecycleService({this.failRevealAfterCommit = false, this.historyGate});

  final bool failRevealAfterCommit;
  final Completer<RitualHistoryPage>? historyGate;
  DailyRitual current = _ritual(DailyRitualState.assigned, 1);
  final List<int> revealVersions = [];
  final List<int> completeVersions = [];
  int assignmentReads = 0;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async => current;

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async {
    assignmentReads += 1;
    return current;
  }

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async =>
      [
        RitualEvidenceDetail(
          claimId: 'claim-1',
          factorLabel: 'Durability',
          observedAt: DateTime.utc(2026, 8, 25, 12),
          summary: 'The fictional scenario held its range.',
          uncertainty: 'The pattern can change.',
          source: RitualEvidenceSource(
            publisher: 'Demo Research Desk',
            title: 'Provider-free scenario note',
            url: Uri.parse('https://example.invalid/demo-note'),
            publishedAt: DateTime.utc(2026, 8, 25, 11),
          ),
        ),
      ];

  RitualHistoryPage get historyPage => RitualHistoryPage(
    items: [RitualHistoryEntry.fromRitual(current)],
    nextCursor: null,
    hasMore: false,
  );

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      historyGate?.future ?? historyPage;

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) async {
    revealVersions.add(version);
    current = _ritual(DailyRitualState.revealed, version + 1);
    if (failRevealAfterCommit) throw const RitualAmbiguousMutation();
    return current;
  }

  @override
  Future<DailyRitual> complete(String assignmentId, int version) async {
    completeVersions.add(version);
    current = _ritual(DailyRitualState.completed, version + 1);
    return current;
  }
}

class _OutOfOrderHistoryService extends _LifecycleService {
  final Completer<RitualHistoryPage> revealHistory = Completer();
  final Completer<RitualHistoryPage> completeHistory = Completer();
  var _historyRequestCount = 0;

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) {
    _historyRequestCount += 1;
    return _historyRequestCount == 1
        ? revealHistory.future
        : completeHistory.future;
  }

  RitualHistoryPage pageFor(DailyRitualState state) => RitualHistoryPage(
    items: [RitualHistoryEntry.fromRitual(_ritual(state, current.version))],
    nextCursor: null,
    hasMore: false,
  );
}

DailyRitual _ritual(DailyRitualState state, int version) => DailyRitual(
  assignmentId: '00000000-0000-4000-8000-000000000101',
  date: DateTime.utc(2026, 8, 25),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(
    id: '00000000-0000-4000-8000-000000000102',
    number: 3,
  ),
  title: 'The Compass',
  art: const RitualArt(key: 'the_compass', alt: 'The Compass'),
  interpretation: 'Direction is an invitation, not an instruction.',
  guidance: 'Inspect the evidence before choosing what to research.',
  marketLabel: 'Market-informed Demo',
  ideas: const [],
  evidence: const [],
  rowan: const RitualCounsel(
    scriptRevisionId: '00000000-0000-4000-8000-000000000103',
    surface: 'daily_ritual',
    body: 'Notice what changed without rushing to act.',
    riskFooter: 'Demo counsel; not investment advice.',
  ),
  version: version,
  state: state,
  revealedAt: state == DailyRitualState.assigned
      ? null
      : DateTime.utc(2026, 8, 25, 12, 1),
  completedAt: state == DailyRitualState.completed
      ? DateTime.utc(2026, 8, 25, 12, 2)
      : null,
  demo: RitualDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25, 12),
    sourceLabel: 'Deterministic fixture',
    limitations: const ['Fictional scenario; no live provider data.'],
  ),
);
