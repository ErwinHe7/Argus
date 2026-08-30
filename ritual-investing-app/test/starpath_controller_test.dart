import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/starpath/application/starpath_controller.dart';
import 'package:ritual_investing_app/features/starpath/data/starpath_repository.dart';
import 'package:ritual_investing_app/features/starpath/domain/starpath.dart';

void main() {
  group('StarpathController', () {
    test('loads the same curriculum without reading astrology state', () async {
      final service = _StarpathService(snapshot: _snapshot(version: 0));
      final controller = _controller(service);

      await controller.load();

      expect(controller.state.phase, StarpathViewPhase.ready);
      expect(controller.state.snapshot?.nodes, hasLength(8));
      expect(service.reads, 1);
    });

    test('exposes one due recall while preserving the current node', () async {
      final service = _StarpathService(
        snapshot: _snapshot(version: 3, currentOrdinal: 4, recall: true),
      );
      final controller = _controller(service);

      await controller.load();

      expect(controller.state.snapshot?.recall?.lessonId, 'lesson-2');
      expect(controller.state.snapshot?.progress?.currentNodeOrdinal, 4);
      expect(
        controller.state.snapshot?.nodes.where(
          (node) => node.state == StarpathNodeState.completed,
        ),
        hasLength(3),
      );
    });

    test('retains one start key across a transport retry', () async {
      final service = _StarpathService(snapshot: _snapshot(version: 0))
        ..startFailures.add(const StarpathAmbiguousCommand())
        ..readFailures.add(const OfflineException());
      final keys = <String>[];
      final controller = _controller(
        service,
        createKey: () {
          final key = 'key-${keys.length + 1}';
          keys.add(key);
          return key;
        },
      );
      await controller.load();

      await controller.start();
      expect(controller.state.phase, StarpathViewPhase.offlineReadOnly);
      await controller.start();

      expect(service.startKeys, ['key-1', 'key-1']);
      expect(keys, ['key-1']);
      expect(controller.state.phase, StarpathViewPhase.ready);
    });

    test('reconciles an ambiguous answer without optimistic unlock', () async {
      final before = _snapshot(version: 2, currentOrdinal: 3);
      final after = _snapshot(version: 3, currentOrdinal: 4);
      final service = _StarpathService(snapshot: before)
        ..answerFailures.add(const StarpathAmbiguousCommand())
        ..readsAfterCommand.add(after);
      final controller = _controller(service);
      await controller.load();

      final pending = controller.answer('option-a');
      await pending;

      expect(service.answerVersions, [2]);
      expect(service.answerSnapshotOrdinals, [3]);
      expect(controller.state.snapshot?.progress?.currentNodeOrdinal, 4);
      expect(controller.state.reconciled, isTrue);
    });

    test('reloads authoritative state after a stale precondition', () async {
      final before = _snapshot(version: 2, currentOrdinal: 3);
      final after = _snapshot(version: 4, currentOrdinal: 5);
      final service = _StarpathService(snapshot: before)
        ..answerFailures.add(const StarpathConflict())
        ..readsAfterCommand.add(after);
      final controller = _controller(service);
      final phases = <StarpathViewPhase>[];
      controller.addListener(() => phases.add(controller.state.phase));
      await controller.load();

      await controller.answer('option-a');

      expect(phases, contains(StarpathViewPhase.conflictReloading));
      expect(controller.state.snapshot?.version, 4);
      expect(controller.state.snapshot?.progress?.currentNodeOrdinal, 5);
    });

    test(
      'renders cached content read-only and never queues an answer',
      () async {
        final cache = MemoryReadCache();
        final cached = _snapshot(version: 2, currentOrdinal: 3);
        await cache.put('starpath', cached, DateTime.utc(2026, 8, 29));
        final service = _StarpathService(snapshot: cached)
          ..readFailures.add(const OfflineException());
        final controller = _controller(service, cache: cache);

        await controller.load();
        await controller.answer('option-a');

        expect(controller.state.phase, StarpathViewPhase.cachedStale);
        expect(controller.state.isReadOnly, isTrue);
        expect(service.answerKeys, isEmpty);
      },
    );

    test(
      'withdrawal without a complete replacement becomes unavailable',
      () async {
        final service = _StarpathService(snapshot: _snapshot(version: 2))
          ..answerFailures.add(const StarpathUnavailable());
        final controller = _controller(service);
        await controller.load();

        await controller.answer('option-a');

        expect(controller.state.phase, StarpathViewPhase.unavailable);
        expect(controller.state.snapshot, isNull);
      },
    );

    test('Rowan reveal is local and cannot mutate progress', () async {
      final service = _StarpathService(snapshot: _snapshot(version: 2));
      final controller = _controller(service);
      await controller.load();
      final version = controller.state.snapshot?.version;

      controller.revealRowan(2);

      expect(controller.state.rowanNodeOrdinal, 2);
      expect(controller.state.snapshot?.version, version);
      expect(service.answerKeys, isEmpty);
      expect(service.startKeys, isEmpty);
    });
  });
}

StarpathController _controller(
  _StarpathService service, {
  ReadCache? cache,
  String Function()? createKey,
}) => StarpathController(
  repository: StarpathRepository(
    service: service,
    cache: cache ?? MemoryReadCache(),
  ),
  createKey: createKey ?? () => 'command-key',
);

class _StarpathService implements StarpathService {
  _StarpathService({required this.snapshot});

  StarpathSnapshot snapshot;
  int reads = 0;
  final List<Object> readFailures = [];
  final List<Object> startFailures = [];
  final List<Object> answerFailures = [];
  final List<StarpathSnapshot> readsAfterCommand = [];
  final List<String> startKeys = [];
  final List<String> answerKeys = [];
  final List<int> answerVersions = [];
  final List<int?> answerSnapshotOrdinals = [];
  bool commandAttempted = false;

  @override
  Future<StarpathSnapshot> fetch() async {
    reads += 1;
    if (readFailures.isNotEmpty) throw readFailures.removeAt(0);
    if (commandAttempted && readsAfterCommand.isNotEmpty) {
      await Future<void>.delayed(Duration.zero);
      snapshot = readsAfterCommand.removeAt(0);
    }
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> start({required String idempotencyKey}) async {
    startKeys.add(idempotencyKey);
    commandAttempted = true;
    if (startFailures.isNotEmpty) throw startFailures.removeAt(0);
    snapshot = _snapshot(version: 1, currentOrdinal: 1);
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> answer({
    required String idempotencyKey,
    required int version,
    required StarpathAnswerCommand command,
  }) async {
    answerKeys.add(idempotencyKey);
    answerVersions.add(version);
    answerSnapshotOrdinals.add(snapshot.progress?.currentNodeOrdinal);
    commandAttempted = true;
    if (answerFailures.isNotEmpty) throw answerFailures.removeAt(0);
    snapshot = _snapshot(
      version: version + 1,
      currentOrdinal: (snapshot.progress?.currentNodeOrdinal ?? 1) + 1,
    );
    return snapshot;
  }

  @override
  Future<StarpathSnapshot> skipRecall({
    required String idempotencyKey,
    required int version,
    required String sessionId,
  }) async => snapshot;
}

StarpathSnapshot _snapshot({
  required int version,
  int currentOrdinal = 1,
  bool recall = false,
}) {
  final started = version > 0;
  return StarpathSnapshot(
    availability: started
        ? StarpathAvailability.available
        : StarpathAvailability.notStarted,
    version: version,
    authority: const StarpathAuthority(
      environment: StarpathEnvironment.beta,
      jurisdiction: 'US',
      capabilityVersion: 1,
      policyVersion: 'no-advice-v1',
      manifestId: 'manifest-1',
      manifestVersion: '1',
    ),
    nodes: List.generate(8, (index) {
      final ordinal = index + 1;
      return StarpathNode(
        lessonId: 'lesson-$ordinal',
        revisionId: 'revision-$ordinal',
        nodeOrdinal: ordinal,
        pathwayOrdinal: ((ordinal - 1) ~/ 2) + 1,
        pathwayPosition: ((ordinal - 1) % 2) + 1,
        title: 'Lesson $ordinal',
        mythicMnemonic: 'Mnemonic $ordinal',
        factualSummary: 'Factual summary $ordinal',
        materialLimitations: 'Limitations $ordinal',
        riskContext: 'Risk context $ordinal',
        recallPrompt: 'Recall prompt $ordinal',
        rowanExplanation: 'Reviewed explanation $ordinal',
        guide: const StarpathGuide(
          tarotKey: 'the-star',
          accessibleLabel: 'The Star',
        ),
        factualSections: [
          StarpathFactualSection(
            ordinal: 1,
            kind: StarpathFactualSectionKind.fact,
            heading: 'Fact',
            body: 'Objective fact.',
            observedAt: DateTime.utc(2026, 8, 29),
            uncertainty: 'Terms can change.',
            evidence: [
              StarpathEvidence(
                ordinal: 1,
                publisher: 'Investor.gov',
                sourceTitle: 'Investor education',
                canonicalUrl: Uri.parse('https://www.investor.gov/'),
                claimSummary: 'Primary source.',
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
          options: const [
            StarpathKnowledgeCheckOption(
              id: 'option-a',
              ordinal: 1,
              label: 'A factual statement',
            ),
            StarpathKnowledgeCheckOption(
              id: 'option-b',
              ordinal: 2,
              label: 'A recommendation',
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
            lastActionAt: DateTime.utc(2026, 8, 29),
            state: StarpathSessionState.active,
          )
        : null,
    progress: started
        ? StarpathProgress(
            currentNodeOrdinal: currentOrdinal,
            version: version,
            updatedAt: DateTime.utc(2026, 8, 29),
          )
        : null,
    theme: started
        ? const StarpathTheme(
            id: 'theme-1',
            key: 'virgo-season',
            title: 'The Lantern Sky',
            horoscopeFrame: 'A mnemonic frame only.',
            factualFocus: 'Market mechanics.',
            accessibleLabel: 'A constellation-shaped learning path.',
          )
        : null,
    recall: recall
        ? StarpathRecall(
            id: 'recall-1',
            lessonId: 'lesson-2',
            revisionId: 'revision-2',
            questionId: 'question-2',
            prompt: 'Recall the factual point.',
            knowledgeCheck: StarpathKnowledgeCheck(
              id: 'question-2',
              prompt: 'Recall?',
              options: const [
                StarpathKnowledgeCheckOption(
                  id: 'option-a',
                  ordinal: 1,
                  label: 'Fact',
                ),
              ],
            ),
          )
        : null,
  );
}
