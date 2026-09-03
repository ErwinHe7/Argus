import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ritual/application/daily_ritual_controller.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_cache_record.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';

void main() {
  const scope = CacheScope(accountId: 'member-a', resetGeneration: 3);

  test('server duration is enforced with monotonic elapsed time', () {
    final ritual = _authority(
      serverEvaluatedAt: DateTime.utc(2026, 11, 1, 4),
      validUntil: DateTime.utc(2026, 11, 2, 5),
    );
    final record = DailyRitualCacheRecord.fromAuthority(
      scope: scope,
      mode: DailyRitualMode.tarot,
      ritual: ritual,
      receivedAt: DateTime.utc(2026, 11, 1, 4),
      receivedAtElapsed: Duration.zero,
    );

    expect(record.serverValidity, const Duration(hours: 25));
    expect(
      record.isUsable(
        expectedScope: scope,
        expectedMode: DailyRitualMode.tarot,
        now: DateTime.utc(2026, 11, 2, 4, 59, 59),
        elapsed: const Duration(hours: 24, minutes: 59, seconds: 59),
      ),
      isTrue,
    );
    expect(
      record.isUsable(
        expectedScope: scope,
        expectedMode: DailyRitualMode.tarot,
        now: DateTime.utc(2026, 11, 2, 5),
        elapsed: const Duration(hours: 25),
      ),
      isFalse,
    );
    expect(
      record.isUsable(
        expectedScope: scope,
        expectedMode: DailyRitualMode.tarot,
        now: DateTime.utc(2026, 11, 1, 8),
        elapsed: const Duration(minutes: 1),
      ),
      isFalse,
      reason: 'a wall-clock discontinuity forces authoritative revalidation',
    );
  });

  test('response latency cannot extend the server validity window', () {
    final ritual = _authority(
      serverEvaluatedAt: DateTime.utc(2026, 8, 25, 12),
      validUntil: DateTime.utc(2026, 8, 25, 12, 10),
    );
    final record = DailyRitualCacheRecord.fromAuthority(
      scope: scope,
      mode: DailyRitualMode.tarot,
      ritual: ritual,
      receivedAt: DateTime.utc(2026, 8, 25, 12, 9),
      receivedAtElapsed: const Duration(minutes: 4),
    );

    expect(record.serverValidity, const Duration(minutes: 1));
    expect(
      record.isUsable(
        expectedScope: scope,
        expectedMode: DailyRitualMode.tarot,
        now: DateTime.utc(2026, 8, 25, 12, 9, 59),
        elapsed: const Duration(minutes: 4, seconds: 59),
      ),
      isTrue,
    );
    expect(
      record.isUsable(
        expectedScope: scope,
        expectedMode: DailyRitualMode.tarot,
        now: DateTime.utc(2026, 8, 25, 12, 10),
        elapsed: const Duration(minutes: 5),
      ),
      isFalse,
    );
  });

  test('authority received at or after valid-until is rejected', () {
    final ritual = _authority(
      serverEvaluatedAt: DateTime.utc(2026, 8, 25, 12),
      validUntil: DateTime.utc(2026, 8, 25, 12, 10),
    );

    for (final receivedAt in <DateTime>[
      DateTime.utc(2026, 8, 25, 12, 10),
      DateTime.utc(2026, 8, 25, 12, 11),
    ]) {
      expect(
        () => DailyRitualCacheRecord.fromAuthority(
          scope: scope,
          mode: DailyRitualMode.tarot,
          ritual: ritual,
          receivedAt: receivedAt,
          receivedAtElapsed: Duration.zero,
        ),
        throwsA(
          isA<RitualAuthorityInvalid>().having(
            (failure) => failure.reason,
            'reason',
            RitualAuthorityInvalidReason.validity,
          ),
        ),
      );
    }
  });

  test(
    'strict record validation rejects every authority identity mismatch',
    () {
      final cases = <DailyRitual, RitualAuthorityInvalidReason>{
        _authority(userId: 'member-b'): RitualAuthorityInvalidReason.scope,
        _authority(deletionEpoch: 4): RitualAuthorityInvalidReason.scope,
        _authority(mode: DailyRitualMode.astrology):
            RitualAuthorityInvalidReason.mode,
        _authority(assignmentId: ''): RitualAuthorityInvalidReason.lineage,
        _authority(revisionNumber: 0): RitualAuthorityInvalidReason.revision,
        _authority(version: 0): RitualAuthorityInvalidReason.lifecycle,
        _authority(contentIdentity: ''): RitualAuthorityInvalidReason.content,
        _authority(
          artKey: '',
          mediaAvailability: RitualMediaAvailability.exactIdentity,
        ): RitualAuthorityInvalidReason.media,
        _authority(state: DailyRitualState.unknown):
            RitualAuthorityInvalidReason.lifecycle,
        _authority(validUntil: DateTime.utc(2026, 8, 25, 12)):
            RitualAuthorityInvalidReason.validity,
      };

      for (final entry in cases.entries) {
        expect(
          () => DailyRitualCacheRecord.fromAuthority(
            scope: scope,
            mode: DailyRitualMode.tarot,
            ritual: entry.key,
            receivedAt: DateTime.utc(2026, 8, 25, 12),
            receivedAtElapsed: Duration.zero,
          ),
          throwsA(
            isA<RitualAuthorityInvalid>().having(
              (failure) => failure.reason,
              'reason',
              entry.value,
            ),
          ),
        );
      }
    },
  );

  test(
    'a wrong-scope cached record is rejected before offline fallback',
    () async {
      final cache = MemoryReadCache();
      await _putRecord(
        cache,
        _authority(userId: 'member-b', deletionEpoch: 9),
        recordScope: const CacheScope(
          accountId: 'member-b',
          resetGeneration: 9,
        ),
      );
      final service = _ScriptedService(daily: [_offlineAuthority()]);
      final controller = _controller(service: service, cache: cache);

      await controller.load();

      expect(controller.state.value, isNull);
      expect(controller.state.phase, LoadPhase.retryableFailure);
      expect(service.dailyReads, 1);
    },
  );

  test(
    'valid cached authority remains actionable when refresh is offline',
    () async {
      final cache = MemoryReadCache();
      final cached = _authority();
      await _putRecord(cache, cached);
      final service = _ScriptedService(daily: [_offlineAuthority()]);
      final controller = _controller(service: service, cache: cache);

      await controller.load();
      await controller.authorityIdle;

      expect(controller.state.phase, LoadPhase.stale);
      expect(controller.state.value, cached);
      expect(controller.mutationAuthorityEnabled, isTrue);
    },
  );

  test('wrong-scope network authority is rejected before display', () async {
    final cache = MemoryReadCache();
    final service = _ScriptedService(
      daily: [_async(_authority(userId: 'member-b'))],
    );
    final controller = _controller(service: service, cache: cache);

    await controller.load();

    expect(controller.state.phase, LoadPhase.terminalFailure);
    expect(controller.state.value, isNull);
    expect(controller.mutationAuthorityEnabled, isFalse);
    expect(
      await cache.get<DailyRitualCacheRecord>(
        DailyRitualCacheRecord.cacheKey(DailyRitualMode.tarot),
      ),
      isNull,
    );
  });

  test(
    'valid cached authority renders while a refresh remains pending',
    () async {
      final cache = MemoryReadCache();
      final cached = _authority();
      await _putRecord(cache, cached);
      final refresh = Completer<DailyRitual>();
      final service = _ScriptedService(daily: [refresh.future]);
      final controller = _controller(service: service, cache: cache);

      await controller.load();
      await _waitForReads(service, 1);

      expect(controller.state.phase, LoadPhase.stale);
      expect(controller.state.value, cached);
      expect(service.dailyReads, 1);

      refresh.complete(
        _authority(state: DailyRitualState.revealed, version: 2),
      );
      await controller.authorityIdle;

      expect(controller.state.phase, LoadPhase.ready);
      expect(controller.state.value?.state, DailyRitualState.revealed);
      final retained = await cache.get<DailyRitualCacheRecord>(
        DailyRitualCacheRecord.cacheKey(DailyRitualMode.tarot),
      );
      expect(retained?.value.ritual.state, DailyRitualState.revealed);
    },
  );

  for (final state in DailyRitualState.values.where(
    (value) => value != DailyRitualState.unknown,
  )) {
    test(
      'fresh controller restores ${state.name} before revalidation',
      () async {
        final storage = MemoryReadCache();
        final authority = _authority(
          state: state,
          version: switch (state) {
            DailyRitualState.assigned => 1,
            DailyRitualState.revealed => 2,
            DailyRitualState.completed => 3,
            DailyRitualState.unknown => throw StateError('excluded'),
          },
        );
        final first = _controller(
          service: _ScriptedService(daily: [_async(authority)]),
          cache: ScopedReadCache(storage: storage, scope: scope),
        );
        await first.load();
        first.dispose();

        final refresh = Completer<DailyRitual>();
        final service = _ScriptedService(daily: [refresh.future]);
        final restored = _controller(
          service: service,
          cache: ScopedReadCache(storage: storage, scope: scope),
        );
        addTearDown(restored.dispose);

        await restored.load();
        expect(restored.state.phase, LoadPhase.stale);
        expect(restored.state.value?.state, state);
        expect(restored.state.value?.version, authority.version);
        await _waitForReads(service, 1);

        refresh.complete(authority);
        await restored.authorityIdle;
        expect(restored.state.phase, LoadPhase.ready);
        expect(restored.state.value?.state, state);
      },
    );
  }

  test(
    'fresh controller reconciles a server commit made before response delivery',
    () async {
      final storage = MemoryReadCache();
      final response = Completer<void>();
      final service = _CommitBeforeResponseService(response: response);
      final first = _controller(
        service: service,
        cache: ScopedReadCache(storage: storage, scope: scope),
      );
      addTearDown(first.dispose);
      await first.load();

      final transition = first.reveal(refreshHistory: false);
      await service.revealStarted.future;
      expect(service.current.state, DailyRitualState.revealed);

      final restored = _controller(
        service: service,
        cache: ScopedReadCache(storage: storage, scope: scope),
      );
      addTearDown(restored.dispose);
      await restored.load();
      await restored.authorityIdle;

      expect(restored.state.value?.state, DailyRitualState.revealed);
      expect(restored.state.value?.version, 2);
      expect(service.revealCalls, 1);

      response.complete();
      await transition;
    },
  );

  test(
    'fresh controller never replays a dispatched reveal before server commit',
    () async {
      final storage = MemoryReadCache();
      final commit = Completer<void>();
      final service = _DispatchBeforeCommitService(commit: commit);
      final first = _controller(
        service: service,
        cache: ScopedReadCache(storage: storage, scope: scope),
      );
      addTearDown(first.dispose);
      await first.load();

      final transition = first.reveal(refreshHistory: false);
      await service.revealStarted.future;
      expect(service.current.state, DailyRitualState.assigned);

      final restored = _controller(
        service: service,
        cache: ScopedReadCache(storage: storage, scope: scope),
      );
      addTearDown(restored.dispose);
      await restored.load();
      await restored.authorityIdle;

      expect(restored.state.value?.state, DailyRitualState.assigned);
      expect(service.revealCalls, 1);

      commit.complete();
      await transition;
      await restored.revalidate();
      expect(restored.state.value?.state, DailyRitualState.revealed);
      expect(service.revealCalls, 1);
    },
  );

  test(
    'retired account rejects a late authority read without leaking to B',
    () async {
      const scopeB = CacheScope(accountId: 'member-b', resetGeneration: 8);
      final storage = MemoryReadCache();
      final cacheA = ScopedReadCache(storage: storage, scope: scope);
      await _putRecord(cacheA, _authority());
      final lateRead = Completer<DailyRitual>();
      final serviceA = _ScriptedService(daily: [lateRead.future]);
      final controllerA = _controller(service: serviceA, cache: cacheA);
      addTearDown(controllerA.dispose);
      await controllerA.load();
      await _waitForReads(serviceA, 1);

      await cacheA.clear();
      final authorityB = _authority(
        userId: 'member-b',
        deletionEpoch: 8,
        assignmentId: 'assignment-b',
        contentIdentity: 'content-b',
      );
      final controllerB = DailyRitualController(
        repository: DailyRitualRepository(
          service: _ScriptedService(daily: [_async(authorityB)]),
          cache: ScopedReadCache(storage: storage, scope: scopeB),
          scope: scopeB,
          effectiveMode: DailyRitualMode.tarot,
          now: () => DateTime.utc(2026, 8, 25, 12),
          elapsed: () => Duration.zero,
        ),
      );
      addTearDown(controllerB.dispose);
      await controllerB.load();

      lateRead.complete(
        _authority(state: DailyRitualState.revealed, version: 2),
      );
      await controllerA.authorityIdle;

      expect(controllerB.state.value?.assignmentId, 'assignment-b');
      expect(controllerB.state.value?.state, DailyRitualState.assigned);
      final retiredRead = await ScopedReadCache(storage: storage, scope: scope)
          .get<DailyRitualCacheRecord>(
            DailyRitualCacheRecord.cacheKey(DailyRitualMode.tarot),
          );
      expect(retiredRead, isNull);
    },
  );

  test(
    'retired account rejects a late mutation write while B is active',
    () async {
      const scopeB = CacheScope(accountId: 'member-b', resetGeneration: 8);
      final storage = MemoryReadCache();
      final response = Completer<void>();
      final serviceA = _CommitBeforeResponseService(response: response);
      final cacheA = ScopedReadCache(storage: storage, scope: scope);
      final controllerA = _controller(service: serviceA, cache: cacheA);
      addTearDown(controllerA.dispose);
      await controllerA.load();
      final transition = controllerA.reveal(refreshHistory: false);
      await serviceA.revealStarted.future;

      await cacheA.clear();
      final authorityB = _authority(
        userId: 'member-b',
        deletionEpoch: 8,
        assignmentId: 'assignment-b',
        contentIdentity: 'content-b',
      );
      final controllerB = DailyRitualController(
        repository: DailyRitualRepository(
          service: _ScriptedService(daily: [_async(authorityB)]),
          cache: ScopedReadCache(storage: storage, scope: scopeB),
          scope: scopeB,
          effectiveMode: DailyRitualMode.tarot,
          now: () => DateTime.utc(2026, 8, 25, 12),
          elapsed: () => Duration.zero,
        ),
      );
      addTearDown(controllerB.dispose);
      await controllerB.load();

      response.complete();
      await transition;

      expect(controllerB.state.value?.assignmentId, 'assignment-b');
      expect(controllerB.state.value?.state, DailyRitualState.assigned);
      final retiredRead = await ScopedReadCache(storage: storage, scope: scope)
          .get<DailyRitualCacheRecord>(
            DailyRitualCacheRecord.cacheKey(DailyRitualMode.tarot),
          );
      expect(retiredRead, isNull);
    },
  );

  test(
    'serialized reads expose only the latest noninvalidated generation',
    () async {
      final first = Completer<DailyRitual>();
      final second = Completer<DailyRitual>();
      final service = _ScriptedService(daily: [first.future, second.future]);
      final controller = _controller(
        service: service,
        cache: MemoryReadCache(),
      );
      final observedAssignments = <String?>[];
      controller.addListener(
        () => observedAssignments.add(controller.state.value?.assignmentId),
      );

      final olderLoad = controller.load();
      await _waitForReads(service, 1);
      final latestLoad = controller.load();
      expect(service.dailyReads, 1);

      first.complete(_authority(assignmentId: 'obsolete-assignment'));
      await _waitForReads(service, 2);
      expect(
        service.dailyReads,
        2,
        reason: 'authority reads must be serialized',
      );
      second.complete(_authority(assignmentId: 'current-assignment'));
      await Future.wait([olderLoad, latestLoad]);
      await controller.authorityIdle;

      expect(controller.state.value?.assignmentId, 'current-assignment');
      expect(observedAssignments, isNot(contains('obsolete-assignment')));
    },
  );

  test('queued obsolete generations skip redundant authority reads', () async {
    final first = Completer<DailyRitual>();
    final latest = Completer<DailyRitual>();
    final service = _ScriptedService(daily: [first.future, latest.future]);
    final controller = _controller(service: service, cache: MemoryReadCache());

    final firstLoad = controller.load();
    await _waitForReads(service, 1);
    final obsoleteQueuedLoad = controller.load();
    final latestLoad = controller.load();

    first.complete(_authority(assignmentId: 'obsolete-assignment'));
    await _waitForReads(service, 2);
    latest.complete(_authority(assignmentId: 'current-assignment'));
    await Future.wait([firstLoad, obsoleteQueuedLoad, latestLoad]);
    await controller.authorityIdle;

    expect(service.dailyReads, 2);
    expect(controller.state.value?.assignmentId, 'current-assignment');
  });

  test(
    'one latest authority read performs one validated lineage switch',
    () async {
      final cache = MemoryReadCache();
      await _putRecord(cache, _authority(assignmentId: 'prior-assignment'));
      final refresh = Completer<DailyRitual>();
      final controller = _controller(
        service: _ScriptedService(daily: [refresh.future]),
        cache: cache,
      );

      await controller.load();
      refresh.complete(_authority(assignmentId: 'next-assignment'));
      await controller.authorityIdle;

      expect(controller.state.value?.assignmentId, 'next-assignment');
      expect(controller.lineageSwitches, 1);
    },
  );

  test(
    'same-lineage regression cannot replace the retained authority',
    () async {
      final cache = MemoryReadCache();
      final revealed = _authority(state: DailyRitualState.revealed, version: 2);
      await _putRecord(cache, revealed);
      final controller = _controller(
        service: _ScriptedService(daily: [_async(_authority())]),
        cache: cache,
      );

      await controller.load();
      await controller.authorityIdle;

      expect(controller.state.phase, LoadPhase.ready);
      expect(controller.state.value, revealed);
      expect(controller.mutationAuthorityEnabled, isTrue);
    },
  );

  test(
    'equal-version divergent payload fails closed and preserves display',
    () async {
      final cache = MemoryReadCache();
      final retained = _authority();
      await _putRecord(cache, retained);
      final service = _ScriptedService(
        daily: [
          _async(
            _authority(title: 'Changed title', contentIdentity: 'changed'),
          ),
        ],
      );
      final controller = _controller(service: service, cache: cache);

      await controller.load();
      await controller.authorityIdle;
      final outcome = await controller.reveal();

      expect(controller.state.phase, LoadPhase.conflict);
      expect(controller.state.value, retained);
      expect(controller.mutationAuthorityEnabled, isFalse);
      expect(outcome, isNull);
      expect(service.revealCalls, 0);
    },
  );

  test(
    'mode changes invalidate the retained lane before loading authority',
    () async {
      final cache = MemoryReadCache();
      await _putRecord(cache, _authority());
      final service = _ScriptedService(
        daily: [
          _async(
            _authority(
              assignmentId: 'astrology-assignment',
              mode: DailyRitualMode.astrology,
            ),
          ),
        ],
      );
      final repository = _repository(service: service, cache: cache);
      final controller = DailyRitualController(repository: repository);

      expect(controller.updateMode(DailyRitualMode.astrology), isTrue);
      expect(controller.state.value, isNull);
      await controller.load();

      expect(service.requestedModes, [DailyRitualMode.astrology]);
      expect(controller.state.value?.assignmentId, 'astrology-assignment');
    },
  );

  test(
    'committed transition is merged and written through before outcome',
    () async {
      final cache = MemoryReadCache();
      final service = _ScriptedService(
        daily: [_async(_authority())],
        revealResult: _authority(state: DailyRitualState.revealed, version: 2),
      );
      final controller = _controller(service: service, cache: cache);
      await controller.load();

      final outcome = await controller.reveal();
      final retained = await cache.get<DailyRitualCacheRecord>(
        DailyRitualCacheRecord.cacheKey(DailyRitualMode.tarot),
      );

      expect(outcome?.disposition, RitualOperationDisposition.committed);
      expect(controller.state.value?.state, DailyRitualState.revealed);
      expect(retained?.value.ritual.state, DailyRitualState.revealed);
    },
  );

  test(
    'late Evidence for a prior assignment cannot cross a lineage switch',
    () async {
      final firstEvidence = Completer<List<RitualEvidenceDetail>>();
      final service = _ScriptedService(
        daily: [
          _async(_authority(assignmentId: 'assignment-a')),
          _async(_authority(assignmentId: 'assignment-b')),
        ],
        evidence: {'assignment-a': firstEvidence.future},
      );
      final controller = _controller(
        service: service,
        cache: MemoryReadCache(),
      );
      await controller.load();
      final evidenceLoad = controller.loadEvidence(
        assignment: controller.state.value,
      );

      await controller.revalidate();
      firstEvidence.complete([_evidenceDetail]);
      await evidenceLoad;

      expect(controller.state.value?.assignmentId, 'assignment-b');
      expect(controller.evidenceState.phase, LoadPhase.idle);
      expect(controller.evidenceState.value, isNull);
    },
  );

  test('late Evidence cannot cross a same-assignment version change', () async {
    final firstEvidence = Completer<List<RitualEvidenceDetail>>();
    final service = _ScriptedService(
      daily: [
        _async(_authority()),
        _async(_authority(state: DailyRitualState.revealed, version: 2)),
      ],
      evidence: {'assignment-a': firstEvidence.future},
    );
    final controller = _controller(service: service, cache: MemoryReadCache());
    await controller.load();
    final evidenceLoad = controller.loadEvidence(
      assignment: controller.state.value,
    );

    await controller.revalidate();
    firstEvidence.complete([_evidenceDetail]);
    await evidenceLoad;

    expect(controller.state.value?.version, 2);
    expect(controller.evidenceState.phase, LoadPhase.idle);
    expect(controller.evidenceState.value, isNull);
  });

  test(
    'snapshot Evidence is immutable and detached from the shared evidence lane',
    () async {
      final service = _ScriptedService(
        daily: [
          _async(_authority(state: DailyRitualState.completed, version: 3)),
        ],
        evidence: {
          'assignment-a': Future.value([_evidenceDetail]),
        },
      );
      final controller = _controller(
        service: service,
        cache: MemoryReadCache(),
      );
      await controller.load();

      final result = await controller.loadEvidenceSnapshot(
        controller.state.value!,
      );

      expect(result.phase, LoadPhase.ready);
      expect(result.details, [_evidenceDetail]);
      expect(() => result.details.add(_evidenceDetail), throwsUnsupportedError);
      expect(controller.evidenceState.phase, LoadPhase.idle);
      expect(controller.evidenceState.value, isNull);
    },
  );

  test('snapshot Evidence fails closed across an authority switch', () async {
    final pendingEvidence = Completer<List<RitualEvidenceDetail>>();
    final service = _ScriptedService(
      daily: [
        _async(_authority(state: DailyRitualState.completed, version: 3)),
        _async(
          _authority(
            assignmentId: 'assignment-b',
            state: DailyRitualState.completed,
            version: 3,
          ),
        ),
      ],
      evidence: {'assignment-a': pendingEvidence.future},
    );
    final controller = _controller(service: service, cache: MemoryReadCache());
    await controller.load();
    final snapshot = controller.state.value!;
    final evidenceLoad = controller.loadEvidenceSnapshot(snapshot);

    await controller.revalidate();
    pendingEvidence.complete([_evidenceDetail]);
    final result = await evidenceLoad;

    expect(controller.state.value?.assignmentId, 'assignment-b');
    expect(result.phase, LoadPhase.conflict);
    expect(result.details, isEmpty);
    expect(controller.evidenceState.phase, LoadPhase.idle);
  });
}

Future<DailyRitual> _async(DailyRitual ritual) async => ritual;

Future<DailyRitual> _offlineAuthority() async {
  await Future<void>.delayed(Duration.zero);
  throw const OfflineException();
}

Future<void> _waitForReads(_ScriptedService service, int count) async {
  for (var attempt = 0; attempt < 20 && service.dailyReads < count; attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
}

DailyRitualRepository _repository({
  required DailyRitualService service,
  required ReadCache cache,
  DailyRitualMode mode = DailyRitualMode.tarot,
}) => DailyRitualRepository(
  service: service,
  cache: cache,
  scope: const CacheScope(accountId: 'member-a', resetGeneration: 3),
  effectiveMode: mode,
  now: () => DateTime.utc(2026, 8, 25, 12),
  elapsed: () => Duration.zero,
);

DailyRitualController _controller({
  required DailyRitualService service,
  required ReadCache cache,
}) => DailyRitualController(
  repository: _repository(service: service, cache: cache),
);

Future<void> _putRecord(
  ReadCache cache,
  DailyRitual ritual, {
  CacheScope recordScope = const CacheScope(
    accountId: 'member-a',
    resetGeneration: 3,
  ),
}) => cache.put(
  DailyRitualCacheRecord.cacheKey(ritual.mode),
  DailyRitualCacheRecord.fromAuthority(
    scope: recordScope,
    mode: ritual.mode,
    ritual: ritual,
    receivedAt: DateTime.utc(2026, 8, 25, 12),
    receivedAtElapsed: Duration.zero,
  ),
  DateTime.utc(2026, 8, 25, 12),
);

DailyRitual _authority({
  String userId = 'member-a',
  int deletionEpoch = 3,
  String assignmentId = 'assignment-a',
  DailyRitualMode mode = DailyRitualMode.tarot,
  DailyRitualState state = DailyRitualState.assigned,
  int version = 1,
  int revisionNumber = 3,
  String title = 'The Star',
  String artKey = 'the_star',
  String contentIdentity = 'content-a',
  RitualMediaAvailability? mediaAvailability,
  DateTime? serverEvaluatedAt,
  DateTime? validUntil,
}) => DailyRitual(
  userId: userId,
  deletionEpoch: deletionEpoch,
  scheduleId: 'schedule-a',
  serverEvaluatedAt: serverEvaluatedAt ?? DateTime.utc(2026, 8, 25, 12),
  validUntil: validUntil ?? DateTime.utc(2026, 8, 26, 12),
  contentIdentity: contentIdentity,
  mediaAvailability: mediaAvailability,
  assignmentId: assignmentId,
  date: DateTime.utc(2026, 8, 25),
  mode: mode,
  revision: RitualRevision(id: 'revision-a', number: revisionNumber),
  title: title,
  art: RitualArt(key: artKey, alt: 'The Star'),
  interpretation: 'Pause before deciding what deserves attention.',
  guidance: 'Inspect the evidence before choosing what to research.',
  marketLabel: 'Market-informed',
  ideas: const [],
  evidence: const [],
  rowan: const RitualCounsel(
    scriptRevisionId: 'rowan-a',
    surface: 'daily_ritual',
    body: 'Notice what changed.',
    riskFooter: 'Educational context only.',
  ),
  version: version,
  state: state,
  revealedAt:
      state == DailyRitualState.assigned || state == DailyRitualState.unknown
      ? null
      : DateTime.utc(2026, 8, 25, 12, 1),
  completedAt: state == DailyRitualState.completed
      ? DateTime.utc(2026, 8, 25, 12, 2)
      : null,
  demo: RitualDisclosure(
    isDemo: false,
    observedAt: DateTime.utc(2026, 8, 25, 11),
    sourceLabel: 'Argus editorial',
    limitations: const ['Educational context only.'],
  ),
);

class _ScriptedService implements DailyRitualService {
  _ScriptedService({
    required this.daily,
    this.evidence = const {},
    this.revealResult,
  });

  final List<Future<DailyRitual>> daily;
  final Map<String, Future<List<RitualEvidenceDetail>>> evidence;
  final DailyRitual? revealResult;
  final List<DailyRitualMode?> requestedModes = [];
  int dailyReads = 0;
  int revealCalls = 0;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) {
    requestedModes.add(mode);
    return daily[dailyReads++];
  }

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) =>
      Future.error(const OfflineException());

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) =>
      evidence[assignmentId] ?? Future.value(const []);

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      RitualHistoryPage(items: const [], nextCursor: null, hasMore: false);

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) {
    revealCalls += 1;
    final result = revealResult;
    if (result != null) return Future.value(result);
    return Future.error(const OfflineException());
  }

  @override
  Future<DailyRitual> complete(String assignmentId, int version) =>
      Future.error(const OfflineException());
}

class _CommitBeforeResponseService implements DailyRitualService {
  _CommitBeforeResponseService({required this.response});

  final Completer<void> response;
  final Completer<void> revealStarted = Completer<void>();
  DailyRitual current = _authority();
  int revealCalls = 0;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async => current;

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async => current;

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async =>
      const [];

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      RitualHistoryPage(items: const [], nextCursor: null, hasMore: false);

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) async {
    revealCalls += 1;
    current = _authority(
      state: DailyRitualState.revealed,
      version: version + 1,
    );
    if (!revealStarted.isCompleted) revealStarted.complete();
    await response.future;
    return current;
  }

  @override
  Future<DailyRitual> complete(String assignmentId, int version) =>
      Future.error(const OfflineException());
}

class _DispatchBeforeCommitService implements DailyRitualService {
  _DispatchBeforeCommitService({required this.commit});

  final Completer<void> commit;
  final Completer<void> revealStarted = Completer<void>();
  DailyRitual current = _authority();
  int revealCalls = 0;

  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async => current;

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async => current;

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async =>
      const [];

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async =>
      RitualHistoryPage(items: const [], nextCursor: null, hasMore: false);

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) async {
    revealCalls += 1;
    if (!revealStarted.isCompleted) revealStarted.complete();
    await commit.future;
    current = _authority(
      state: DailyRitualState.revealed,
      version: version + 1,
    );
    return current;
  }

  @override
  Future<DailyRitual> complete(String assignmentId, int version) =>
      Future.error(const OfflineException());
}

final _evidenceDetail = RitualEvidenceDetail(
  claimId: 'claim-a',
  factorLabel: 'Durability',
  observedAt: DateTime.utc(2026, 8, 25, 11),
  summary: 'The observed range held.',
  uncertainty: 'The range can change.',
  source: RitualEvidenceSource(
    publisher: 'Argus Research',
    title: 'Daily context',
    url: Uri.parse('https://example.invalid/context'),
    publishedAt: DateTime.utc(2026, 8, 25, 10),
  ),
);
