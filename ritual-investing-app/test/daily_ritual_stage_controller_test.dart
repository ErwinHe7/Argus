import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/view_state.dart' show LoadPhase;
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ritual/application/leonidas_voice.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/data/leonidas_voice_preference_store.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';
import 'package:ritual_investing_app/features/ritual/presentation/daily_ritual_stage_controller.dart';

void main() {
  group('DailyRitualStageController hold arbiter', () {
    test('unavailable content cannot start or reveal', () async {
      final harness = _StageHarness(
        initial: _ritual(
          contentAvailability: RitualContentAvailability.unavailable,
        ),
      );
      addTearDown(harness.dispose);

      expect(harness.stage.start(), isFalse);
      expect(harness.stage.beginPointerHold(7), isFalse);
      await _flush();

      expect(harness.stage.phase, DailyRitualStagePhase.resting);
      expect(harness.authority.revealCalls, 0);
    });

    test('disabled mutation authority cannot enter the ceremony', () {
      final harness = _StageHarness();
      addTearDown(harness.dispose);
      harness.authority.canMutate = false;

      expect(harness.stage.canStart, isFalse);
      expect(harness.stage.start(), isFalse);
      expect(harness.stage.beginPointerHold(7), isFalse);
      expect(harness.authority.revealCalls, 0);
    });

    for (final boundary in <Duration>[
      const Duration(milliseconds: 100),
      const Duration(milliseconds: 4900),
      const Duration(milliseconds: 4999),
    ]) {
      test('pointer release at ${boundary.inMicroseconds}us cancels', () async {
        final harness = _StageHarness();
        addTearDown(harness.dispose);

        expect(harness.stage.start(), isTrue);
        expect(harness.stage.beginPointerHold(7), isTrue);
        harness.clock.elapseWithoutRunning(boundary);
        harness.stage.pointerUp(7);
        harness.clock.runDue();
        await _flush();

        expect(harness.stage.phase, DailyRitualStagePhase.ready);
        expect(harness.stage.cancellation, HoldCancellation.pointerUp);
        expect(harness.authority.revealCalls, 0);
        expect(harness.haptics.touchDownCount, 1);
        expect(harness.haptics.acceptanceCount, 0);
      });
    }

    test('pointer release at exactly five seconds accepts once', () async {
      final harness = _StageHarness();
      addTearDown(harness.dispose);

      harness.stage.start();
      harness.stage.beginPointerHold(7);
      harness.clock.elapseWithoutRunning(const Duration(seconds: 5));
      harness.stage.pointerUp(7);
      harness.clock.runDue();
      await _flush();

      expect(harness.authority.revealCalls, 1);
      expect(harness.haptics.acceptanceCount, 1);
      expect(harness.stage.phase, DailyRitualStagePhase.revealed);
    });

    test(
      '5.001 seconds accepts once and later release cannot roll it back',
      () async {
        final harness = _StageHarness();
        addTearDown(harness.dispose);

        harness.stage.start();
        harness.stage.beginPointerHold(1);
        harness.clock.advance(const Duration(milliseconds: 5001));
        await _flush();
        harness.stage.pointerUp(1);
        await _flush();

        expect(harness.authority.revealCalls, 1);
        expect(harness.haptics.acceptanceCount, 1);
        expect(harness.stage.phase, DailyRitualStagePhase.revealed);
      },
    );

    test(
      'slow matching preparation keeps acceptance concealed and POST-free',
      () async {
        final preparation = Completer<bool>();
        final harness = _StageHarness(prepareResult: preparation.future);
        addTearDown(harness.dispose);

        harness.stage.start();
        harness.stage.beginPointerHold(1);
        harness.clock.advance(const Duration(seconds: 5));
        await _flush();

        expect(harness.stage.phase, DailyRitualStagePhase.acceptedWaiting);
        expect(harness.authority.revealCalls, 0);

        preparation.complete(true);
        await _flush();

        expect(harness.authority.revealCalls, 1);
        expect(harness.stage.phase, DailyRitualStagePhase.revealed);
      },
    );

    test('late preparation after release can warm but never reveals', () async {
      final preparation = Completer<bool>();
      final harness = _StageHarness(prepareResult: preparation.future);
      addTearDown(harness.dispose);

      harness.stage.start();
      harness.stage.beginPointerHold(1);
      harness.clock.advance(const Duration(milliseconds: 4900));
      harness.stage.pointerUp(1);
      preparation.complete(true);
      await _flush();

      expect(harness.stage.phase, DailyRitualStagePhase.ready);
      expect(harness.authority.revealCalls, 0);
      expect(harness.voice.lines, isEmpty);
    });

    test('changed preflight lineage fails concealed without a POST', () async {
      final harness = _StageHarness();
      addTearDown(harness.dispose);
      harness.authority.afterRevalidate = () {
        harness.authority.current = _ritual(
          state: DailyRitualState.assigned,
          assignmentId: 'assignment-b',
        );
      };

      harness.stage.start();
      harness.stage.beginPointerHold(1);
      harness.clock.advance(const Duration(seconds: 5));
      await _flush();

      expect(harness.authority.revealCalls, 0);
      expect(harness.stage.phase, DailyRitualStagePhase.revealFailure);
    });

    test('first pointer owns the attempt and exit cannot resume', () async {
      final harness = _StageHarness();
      addTearDown(harness.dispose);

      harness.stage.start();
      expect(harness.stage.beginPointerHold(11), isTrue);
      expect(harness.stage.beginPointerHold(12), isFalse);
      harness.clock.advance(const Duration(milliseconds: 700));
      harness.stage.pointerExit(12);
      expect(harness.stage.phase, DailyRitualStagePhase.holding);
      harness.stage.pointerExit(11);
      expect(harness.stage.phase, DailyRitualStagePhase.ready);
      expect(harness.stage.beginPointerHold(12), isTrue);
      expect(harness.haptics.touchDownCount, 2);
    });

    for (final cancellation in <HoldCancellation>[
      HoldCancellation.pointerCancel,
      HoldCancellation.pointerExit,
      HoldCancellation.tabHidden,
      HoldCancellation.routeHidden,
      HoldCancellation.appInactive,
      HoldCancellation.dateChanged,
      HoldCancellation.identityChanged,
      HoldCancellation.semanticCancel,
      HoldCancellation.navigation,
    ]) {
      for (final boundary in <Duration>[
        const Duration(milliseconds: 4999),
        const Duration(seconds: 5),
        const Duration(milliseconds: 5001),
      ]) {
        test(
          '$cancellation arbitrates at ${boundary.inMicroseconds}us',
          () async {
            final harness = _StageHarness();
            addTearDown(harness.dispose);

            harness.stage.start();
            _beginForCancellation(harness, cancellation);
            if (boundary > const Duration(seconds: 5)) {
              harness.clock.advance(boundary);
              await _flush();
            } else {
              harness.clock.elapseWithoutRunning(boundary);
            }
            _triggerCancellation(harness, cancellation);
            harness.clock.runDue();
            await _flush();

            final cancellationUsesElapsedArbiter =
                cancellation == HoldCancellation.pointerCancel ||
                cancellation == HoldCancellation.pointerExit ||
                cancellation == HoldCancellation.semanticCancel ||
                cancellation == HoldCancellation.navigation;
            final accepted =
                boundary > const Duration(seconds: 5) ||
                (boundary == const Duration(seconds: 5) &&
                    cancellationUsesElapsedArbiter);
            expect(harness.authority.revealCalls, accepted ? 1 : 0);
            expect(harness.stage.hasActiveHold, isFalse);
          },
        );
      }
    }

    test('semantic activation is coalesced and progress is whole-second', () {
      final harness = _StageHarness();
      addTearDown(harness.dispose);
      final secondsUpdates = <int>[];
      harness.stage.holdProgressSecondsListenable.addListener(
        () => secondsUpdates.add(
          harness.stage.holdProgressSecondsListenable.value,
        ),
      );

      harness.stage.start();
      expect(harness.stage.beginSemanticHold(), isTrue);
      expect(harness.stage.beginSemanticHold(), isFalse);
      harness.clock.advance(const Duration(milliseconds: 1999));
      expect(harness.stage.semanticProgressSeconds, 1);
      expect(secondsUpdates, [1]);
      harness.clock.advance(const Duration(milliseconds: 1));
      expect(harness.stage.semanticProgressSeconds, 2);
      expect(secondsUpdates, [1, 2]);
      harness.stage.cancel(HoldCancellation.semanticCancel);
    });
  });

  test('unavailable revealed content cannot finish', () async {
    final harness = _StageHarness(
      initial: _ritual(
        state: DailyRitualState.revealed,
        contentAvailability: RitualContentAvailability.unavailable,
      ),
    );
    addTearDown(harness.dispose);

    expect(harness.stage.finish(), isFalse);
    await _flush();

    expect(harness.stage.phase, DailyRitualStagePhase.revealed);
    expect(harness.authority.completeCalls, 0);
  });

  group('completion provenance and voice run', () {
    test('only visible local Finish enters C2 once', () async {
      final harness = _StageHarness(
        initial: _ritual(state: DailyRitualState.revealed, version: 2),
      );
      addTearDown(harness.dispose);
      await harness.stage.restoreVoicePreference();

      expect(harness.stage.finish(), isTrue);
      expect(harness.stage.finish(), isFalse);
      await _flush();

      expect(harness.authority.completeCalls, 1);
      expect(harness.stage.phase, DailyRitualStagePhase.closing);
      expect(harness.stage.closingCaptionVisible, isTrue);
      expect(harness.voice.lines, hasLength(1));
      expect(
        harness.voice.lines.single,
        'Carry the signal with you. I’ll meet you here tomorrow.',
      );

      harness.voice.complete(true);
      await _flush();
      expect(harness.stage.phase, DailyRitualStagePhase.completed);
    });

    test('failed Finish preserves the reading and permits one retry', () async {
      final revealed = _ritual(state: DailyRitualState.revealed, version: 2);
      final harness = _StageHarness(
        initial: revealed,
        completeResult: Future.value(
          RitualTransitionResult(
            operation: RitualOperation.complete,
            lineage: revealed.lineage,
            target: DailyRitualState.completed,
            disposition: RitualOperationDisposition.provenNotReached,
            authoritative: revealed,
            failurePhase: LoadPhase.retryableFailure,
          ),
        ),
      );
      addTearDown(harness.dispose);

      expect(harness.stage.finish(), isTrue);
      await _flush();
      expect(harness.stage.phase, DailyRitualStagePhase.finishFailure);
      expect(harness.authority.current, same(revealed));
      expect(harness.voice.lines, isEmpty);

      harness.authority.completeResult = null;
      expect(harness.stage.finish(), isTrue);
      expect(harness.stage.finish(), isFalse);
      await _flush();
      expect(harness.authority.completeCalls, 2);
      expect(harness.stage.phase, DailyRitualStagePhase.closing);
    });

    test(
      'leaving during closing stops speech and settles without replay',
      () async {
        final harness = _StageHarness(
          initial: _ritual(state: DailyRitualState.revealed, version: 2),
        );
        addTearDown(harness.dispose);
        await harness.stage.restoreVoicePreference();

        harness.stage.finish();
        await _flush();
        expect(harness.stage.phase, DailyRitualStagePhase.closing);
        expect(harness.voice.lines, hasLength(1));

        harness.stage.setVisible(false, reason: HoldCancellation.tabHidden);
        expect(harness.voice.stopCount, 1);
        expect(harness.stage.phase, DailyRitualStagePhase.completed);

        harness.stage.setVisible(true, reason: HoldCancellation.tabHidden);
        await _flush();
        expect(harness.stage.phase, DailyRitualStagePhase.completed);
        expect(harness.voice.lines, hasLength(1));
      },
    );

    test('restored and offscreen completion bypass C2 and speech', () async {
      final restored = _StageHarness(
        initial: _ritual(state: DailyRitualState.completed, version: 3),
      );
      addTearDown(restored.dispose);
      expect(restored.stage.phase, DailyRitualStagePhase.completed);
      expect(restored.voice.lines, isEmpty);

      final response = Completer<RitualTransitionResult?>();
      final offscreen = _StageHarness(
        initial: _ritual(state: DailyRitualState.revealed, version: 2),
        completeResult: response.future,
      );
      addTearDown(offscreen.dispose);
      offscreen.stage.finish();
      offscreen.stage.setVisible(false, reason: HoldCancellation.tabHidden);
      offscreen.authority.current = _ritual(
        state: DailyRitualState.completed,
        version: 3,
      );
      response.complete(
        _result(
          operation: RitualOperation.complete,
          from: _ritual(state: DailyRitualState.revealed, version: 2),
          to: offscreen.authority.current!,
        ),
      );
      await _flush();
      offscreen.stage.synchronizeAuthority();

      expect(offscreen.stage.phase, DailyRitualStagePhase.completed);
      expect(offscreen.voice.lines, isEmpty);
    });

    test(
      'late reveal settles authority but cannot revive hidden choreography',
      () async {
        final reveal = Completer<RitualTransitionResult?>();
        final harness = _StageHarness(revealResult: reveal.future);
        addTearDown(harness.dispose);

        harness.stage.start();
        harness.stage.beginPointerHold(1);
        harness.clock.advance(const Duration(seconds: 5));
        await _flush();
        expect(harness.authority.revealCalls, 1);

        harness.stage.setVisible(false, reason: HoldCancellation.tabHidden);
        final revealed = _ritual(state: DailyRitualState.revealed, version: 2);
        harness.authority.current = revealed;
        reveal.complete(
          _result(
            operation: RitualOperation.reveal,
            from: _ritual(),
            to: revealed,
          ),
        );
        await _flush();

        expect(harness.stage.isVisible, isFalse);
        expect(harness.stage.phase, DailyRitualStagePhase.resting);
        expect(harness.voice.lines, isEmpty);

        harness.stage.setVisible(true, reason: HoldCancellation.tabHidden);
        await _flush();
        expect(harness.stage.phase, DailyRitualStagePhase.revealed);
        expect(harness.authority.revealCalls, 1);
      },
    );

    test(
      'Skip before, during, and after speech completion is idempotent',
      () async {
        for (final point in <String>['before', 'during', 'after']) {
          final harness = _StageHarness(
            initial: _ritual(state: DailyRitualState.revealed, version: 2),
          );
          await harness.stage.restoreVoicePreference();
          harness.stage.finish();
          if (point == 'before') harness.stage.skipClosing();
          await _flush();
          if (point == 'during') harness.stage.skipClosing();
          if (point == 'after') {
            harness.voice.complete(true);
            await _flush();
            harness.stage.skipClosing();
          }
          await _flush();

          expect(harness.stage.phase, DailyRitualStagePhase.completed);
          expect(harness.voice.stopCount, lessThanOrEqualTo(1));
          harness.dispose();
        }
      },
    );
  });

  group('scope-versioned voice preference', () {
    test(
      'absence enables while corrupt, mismatch, and read failure disable',
      () async {
        const scope = CacheScope(accountId: 'account-a', resetGeneration: 7);
        final storage = _MemoryStorage();
        final store = LeonidasVoicePreferenceStore(storage);

        expect(await store.read(scope), LeonidasVoicePreference.enabled);
        storage.values[store.storageKeyFor(scope)] = '{not json';
        expect(await store.read(scope), LeonidasVoicePreference.disabled);
        storage.values[store.storageKeyFor(scope)] = '{"schema_version":1,"account_id":"account-a","reset_generation":8,"enabled":true}';
        expect(await store.read(scope), LeonidasVoicePreference.disabled);
        storage.failReads = true;
        expect(await store.read(scope), LeonidasVoicePreference.disabled);
      },
    );

    test(
      'late restore cannot overwrite a newer toggle or start current C2',
      () async {
        final read = Completer<Map<String, String>>();
        final storage = _MemoryStorage(readResult: read.future);
        final store = LeonidasVoicePreferenceStore(storage);
        final harness = _StageHarness(
          initial: _ritual(state: DailyRitualState.revealed, version: 2),
          preferenceStore: store,
        );
        addTearDown(harness.dispose);

        final restore = harness.stage.restoreVoicePreference();
        await harness.stage.setVoiceEnabled(false);
        harness.stage.finish();
        await _flush();
        read.complete({});
        await restore;
        await _flush();

        expect(harness.stage.voicePreference, LeonidasVoicePreference.disabled);
        expect(harness.voice.lines, isEmpty);
        harness.clock.advance(const Duration(milliseconds: 1200));
        expect(harness.stage.phase, DailyRitualStagePhase.completed);
      },
    );

    test(
      'failed enable write stays captions-only and toggle-off stops once',
      () async {
        final storage = _MemoryStorage()..failWrites = true;
        final harness = _StageHarness(
          initial: _ritual(state: DailyRitualState.revealed, version: 2),
          preferenceStore: LeonidasVoicePreferenceStore(storage),
        );
        addTearDown(harness.dispose);

        await harness.stage.setVoiceEnabled(true);
        expect(harness.stage.voicePreference, LeonidasVoicePreference.disabled);

        storage.failWrites = false;
        await harness.stage.setVoiceEnabled(true);
        harness.stage.finish();
        await _flush();
        await harness.stage.setVoiceEnabled(false);
        await harness.stage.setVoiceEnabled(false);
        expect(harness.voice.stopCount, 1);
        harness.clock.advance(const Duration(milliseconds: 1200));
        expect(harness.stage.phase, DailyRitualStagePhase.completed);
      },
    );

    test('clearScope deletes only the exact account generation', () async {
      final storage = _MemoryStorage();
      final store = LeonidasVoicePreferenceStore(storage);
      const oldScope = CacheScope(accountId: 'account-a', resetGeneration: 2);
      const newScope = CacheScope(accountId: 'account-a', resetGeneration: 3);
      await store.write(oldScope, enabled: false);
      await store.write(newScope, enabled: true);

      await store.clearScope(oldScope);

      expect(
        storage.values.containsKey(store.storageKeyFor(oldScope)),
        isFalse,
      );
      expect(await store.read(newScope), LeonidasVoicePreference.enabled);
    });
  });
}

class _StageHarness {
  _StageHarness({
    DailyRitual? initial,
    Future<bool>? prepareResult,
    Future<RitualTransitionResult?>? revealResult,
    Future<RitualTransitionResult?>? completeResult,
    LeonidasVoicePreferenceStore? preferenceStore,
  }) : clock = _ManualClock(),
       authority = _AuthorityFake(initial ?? _ritual()),
       haptics = _HapticsFake(),
       voice = _VoiceFake(),
       storage = _MemoryStorage() {
    if (revealResult != null) authority.revealResult = revealResult;
    if (completeResult != null) authority.completeResult = completeResult;
    stage = DailyRitualStageController(
      authority: authority,
      scope: const CacheScope(accountId: 'account-a', resetGeneration: 7),
      preferenceStore: preferenceStore ?? LeonidasVoicePreferenceStore(storage),
      voice: voice,
      haptics: haptics,
      prepareExactMedia: (_) => prepareResult ?? Future<bool>.value(true),
      monotonicNow: () => clock.now,
      schedule: clock.schedule,
    );
  }

  final _ManualClock clock;
  final _AuthorityFake authority;
  final _HapticsFake haptics;
  final _VoiceFake voice;
  final _MemoryStorage storage;
  late final DailyRitualStageController stage;

  void dispose() => stage.dispose();
}

class _AuthorityFake implements DailyRitualStageAuthority {
  _AuthorityFake(this.current);

  @override
  DailyRitual? current;
  bool canMutate = true;
  int revalidateCalls = 0;
  int revealCalls = 0;
  int completeCalls = 0;
  int resumeInvalidations = 0;
  void Function()? afterRevalidate;
  Future<RitualTransitionResult?>? completeResult;
  Future<RitualTransitionResult?>? revealResult;

  @override
  bool get mutationAuthorityEnabled => canMutate;

  @override
  Future<void> revalidate() async {
    revalidateCalls += 1;
    afterRevalidate?.call();
  }

  @override
  Future<RitualTransitionResult?> reveal() async {
    revealCalls += 1;
    final provided = revealResult;
    if (provided != null) return provided;
    final before = current!;
    final after = _ritual(state: DailyRitualState.revealed, version: 2);
    current = after;
    return _result(operation: RitualOperation.reveal, from: before, to: after);
  }

  @override
  Future<RitualTransitionResult?> complete() async {
    completeCalls += 1;
    final provided = completeResult;
    if (provided != null) return provided;
    final before = current!;
    final after = _ritual(state: DailyRitualState.completed, version: 3);
    current = after;
    return _result(
      operation: RitualOperation.complete,
      from: before,
      to: after,
    );
  }

  @override
  void invalidateForResume() => resumeInvalidations += 1;
}

void _beginForCancellation(
  _StageHarness harness,
  HoldCancellation cancellation,
) {
  if (cancellation == HoldCancellation.pointerCancel ||
      cancellation == HoldCancellation.pointerExit) {
    expect(harness.stage.beginPointerHold(41), isTrue);
  } else {
    expect(harness.stage.beginSemanticHold(), isTrue);
  }
}

void _triggerCancellation(
  _StageHarness harness,
  HoldCancellation cancellation,
) {
  switch (cancellation) {
    case HoldCancellation.pointerCancel:
      harness.stage.pointerCancel(41);
    case HoldCancellation.pointerExit:
      harness.stage.pointerExit(41);
    case HoldCancellation.tabHidden ||
        HoldCancellation.routeHidden ||
        HoldCancellation.appInactive:
      harness.stage.setVisible(false, reason: cancellation);
    case HoldCancellation.dateChanged:
      harness.authority.current = _ritual(
        assignmentId: 'assignment-next-day',
        date: DateTime.utc(2026, 9, 3),
      );
      harness.stage.synchronizeAuthority();
    case HoldCancellation.identityChanged:
      harness.authority.current = _ritual(assignmentId: 'assignment-b');
      harness.stage.synchronizeAuthority();
    case HoldCancellation.semanticCancel || HoldCancellation.navigation:
      harness.stage.cancel(cancellation);
    case HoldCancellation.pointerUp || HoldCancellation.disposed:
      throw ArgumentError.value(cancellation);
  }
}

class _ManualClock {
  Duration now = Duration.zero;
  final List<_Scheduled> _scheduled = [];

  DailyRitualStageScheduled schedule(Duration delay, void Function() callback) {
    final task = _Scheduled(now + delay, callback);
    _scheduled.add(task);
    return task;
  }

  void elapseWithoutRunning(Duration duration) => now += duration;

  void runDue() {
    while (true) {
      _scheduled.sort((a, b) => a.at.compareTo(b.at));
      final due = _scheduled.where((task) => !task.cancelled && task.at <= now);
      if (due.isEmpty) return;
      final task = due.first;
      _scheduled.remove(task);
      task.callback();
    }
  }

  void advance(Duration duration) {
    final target = now + duration;
    while (true) {
      _scheduled.sort((a, b) => a.at.compareTo(b.at));
      final next = _scheduled
          .where((task) => !task.cancelled && task.at <= target)
          .firstOrNull;
      if (next == null) break;
      now = next.at;
      _scheduled.remove(next);
      next.callback();
    }
    now = target;
  }
}

class _Scheduled implements DailyRitualStageScheduled {
  _Scheduled(this.at, this.callback);

  final Duration at;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

class _HapticsFake implements DailyRitualStageHaptics {
  int touchDownCount = 0;
  int acceptanceCount = 0;

  @override
  Future<void> touchDown() async => touchDownCount += 1;

  @override
  Future<void> accepted() async => acceptanceCount += 1;
}

class _VoiceFake implements LeonidasVoice {
  final List<String> lines = [];
  final List<Completer<bool>> _completions = [];
  int stopCount = 0;

  @override
  Future<bool> speak(String text) {
    lines.add(text);
    final completion = Completer<bool>();
    _completions.add(completion);
    return completion.future;
  }

  void complete(bool value) {
    final pending = _completions.where((value) => !value.isCompleted);
    if (pending.isNotEmpty) pending.first.complete(value);
  }

  @override
  Future<void> stop() async => stopCount += 1;
}

class _MemoryStorage implements ProtectedStorage {
  _MemoryStorage({this.readResult});

  final Future<Map<String, String>>? readResult;
  final Map<String, String> values = {};
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async {
    if (failReads) throw StateError('locked');
    return readResult ?? Map.of(values);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

RitualTransitionResult _result({
  required RitualOperation operation,
  required DailyRitual from,
  required DailyRitual to,
}) => RitualTransitionResult(
  operation: operation,
  lineage: from.lineage,
  target: operation == RitualOperation.reveal
      ? DailyRitualState.revealed
      : DailyRitualState.completed,
  disposition: RitualOperationDisposition.committed,
  authoritative: to,
);

DailyRitual _ritual({
  DailyRitualState state = DailyRitualState.assigned,
  int version = 1,
  String assignmentId = 'assignment-a',
  DateTime? date,
  RitualContentAvailability contentAvailability =
      RitualContentAvailability.available,
}) => DailyRitual(
  assignmentId: assignmentId,
  date: date ?? DateTime.utc(2026, 9, 2),
  mode: DailyRitualMode.tarot,
  revision: const RitualRevision(id: 'revision-a', number: 1),
  title: 'Strength',
  art: const RitualArt(key: 'strength', alt: 'Strength tarot card'),
  interpretation: 'Patience is the stronger path.',
  guidance: 'Inspect the evidence.',
  marketLabel: 'Market-informed',
  ideas: const [],
  evidence: const [],
  rowan: const RitualCounsel(
    scriptRevisionId: 'script-a',
    surface: 'daily_ritual',
    body: 'The choice remains yours.',
    riskFooter: 'Not investment advice.',
  ),
  version: version,
  state: state,
  revealedAt: state == DailyRitualState.assigned
      ? null
      : DateTime.utc(2026, 9, 2, 12, 1),
  completedAt: state == DailyRitualState.completed
      ? DateTime.utc(2026, 9, 2, 12, 2)
      : null,
  demo: RitualDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 9, 2, 12),
    sourceLabel: 'fixture',
    limitations: const ['fixture'],
  ),
  userId: 'account-a',
  deletionEpoch: 7,
  scheduleId: 'schedule-a',
  serverEvaluatedAt: DateTime.utc(2026, 9, 2),
  validUntil: DateTime.utc(2026, 9, 3),
  contentIdentity: 'content-a',
  contentAvailability: contentAvailability,
);
