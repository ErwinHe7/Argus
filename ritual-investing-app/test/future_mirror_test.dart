import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/future_mirror/application/future_mirror_controller.dart';
import 'package:ritual_investing_app/features/future_mirror/data/repository.dart';
import 'package:ritual_investing_app/features/future_mirror/domain/model.dart';

void main() {
  test(
    'risk and contribution personalization are visible editable defaults',
    () {
      final fixture = _Fixture();
      fixture.controller.updatePersonalization(
        const MemberPersonalization(
          riskFraming: MemberRiskFraming.high,
          contributionRhythm: MemberContributionRhythm.weekly,
        ),
      );

      expect(fixture.controller.defaults.monthlyContributionMinor, 10000);
      expect(fixture.controller.defaults.lowReturnBps, -2500);
      expect(fixture.controller.defaults.highReturnBps, 4500);
      expect(
        fixture.controller.defaults.sourceLabel,
        contains('starting range'),
      );
      expect(
        fixture.controller.defaults.sourceLabel,
        contains('never a predicted return'),
      );
    },
  );

  test('structured server fields map only to allowlisted controls', () async {
    final fixture = _Fixture()
      ..service.failure = const FutureMirrorValidationFailure({
        FutureMirrorField.monthlyContribution: 'too_big',
        FutureMirrorField.highReturn: 'out_of_range',
      });
    await fixture.controller.openIntention(
      intentionId: 'intention-a',
      portfolioId: 'portfolio-a',
      ledgerWatermark: 12,
    );
    fixture.controller.prepare(fixture.controller.newDraft());
    await fixture.controller.confirm();

    expect(
      fixture.controller.fieldErrors[FutureMirrorField.monthlyContribution],
      isNotNull,
    );
    expect(
      fixture.controller.fieldErrors[FutureMirrorField.highReturn],
      isNotNull,
    );
  });

  test(
    'ambiguous generation resolves exact latest without a second submit',
    () async {
      final fixture = _Fixture()..service.ambiguous = true;
      await fixture.controller.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      final draft = fixture.controller.newDraft();
      fixture.controller.prepare(draft);
      await fixture.controller.confirm();

      expect(fixture.controller.phase, FutureMirrorPhase.complete);
      expect(fixture.service.keys, ['mirror-key']);
      expect(
        await fixture.store.restore(_scope, fixture.controller.operation),
        isNull,
      );
    },
  );

  test(
    'unresolved generation restores review and deliberately reuses one key',
    () async {
      final fixture = _Fixture()
        ..service.ambiguous = true
        ..service.persistAmbiguous = false;
      await fixture.controller.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      fixture.controller.prepare(fixture.controller.newDraft());
      await fixture.controller.confirm();
      expect(fixture.controller.phase, FutureMirrorPhase.retryableFailure);
      expect(fixture.service.keys, ['mirror-key']);

      final restarted = fixture.restart();
      await restarted.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      expect(restarted.phase, FutureMirrorPhase.restoredReview);
      expect(fixture.service.keys, ['mirror-key']);

      fixture.service.ambiguous = false;
      restarted.reviewRestoredGeneration();
      await restarted.confirm();
      expect(fixture.service.keys, ['mirror-key', 'mirror-key']);
      expect(restarted.current?.ledgerWatermark, 12);
    },
  );

  test(
    'watermark marks preserved result stale and compare uses fetched history',
    () async {
      final fixture = _Fixture();
      await fixture.controller.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      fixture.controller.prepare(fixture.controller.newDraft());
      await fixture.controller.confirm();
      final original = fixture.controller.current;

      fixture.bus.publish(
        const InvalidationEvent(
          scope: _scope,
          resource: 'ledger',
          ledgerWatermark: 18,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(fixture.controller.isStale, isTrue);
      expect(fixture.controller.current, same(original));

      fixture.service.historical = _mirror(id: 'mirror-old', watermark: 7);
      fixture.service.getCalls.clear();
      await fixture.controller.compareWith('mirror-old');
      expect(fixture.controller.comparison?.id, 'mirror-old');
      expect(fixture.service.getCalls, ['mirror-old']);
      expect(fixture.controller.historyLabel, contains('seen on this device'));
    },
  );

  test('recovery blocks discard until latest authority is fresh', () async {
    final fixture = _Fixture()
      ..service.ambiguous = true
      ..service.persistAmbiguous = false;
    await fixture.controller.openIntention(
      intentionId: 'intention-a',
      portfolioId: 'portfolio-a',
      ledgerWatermark: 12,
    );
    fixture.controller.prepare(fixture.controller.newDraft());
    fixture.service.failLatest = true;
    await fixture.controller.confirm();
    expect(fixture.controller.phase, FutureMirrorPhase.reconciliationRequired);

    await fixture.controller.discardPendingGeneration();
    expect(
      await fixture.store.restore(_scope, fixture.controller.operation),
      isNotNull,
    );

    fixture.service.failLatest = false;
    await fixture.controller.retryReconciliation();
    expect(fixture.controller.phase, FutureMirrorPhase.restoredReview);
    await fixture.controller.discardPendingGeneration();
    expect(
      await fixture.store.restore(_scope, fixture.controller.operation),
      isNull,
    );
  });

  test(
    'throttling retains protected review and terminal rejection clears it',
    () async {
      final throttled = _Fixture()
        ..service.failure = LoadFailure(LoadPhase.throttled);
      await throttled.controller.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      throttled.controller.prepare(throttled.controller.newDraft());
      await throttled.controller.confirm();
      expect(throttled.controller.phase, FutureMirrorPhase.throttled);
      expect(
        await throttled.store.restore(_scope, throttled.controller.operation),
        isNotNull,
      );

      final terminal = _Fixture()
        ..service.failure = LoadFailure(LoadPhase.terminalFailure);
      await terminal.controller.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      terminal.controller.prepare(terminal.controller.newDraft());
      await terminal.controller.confirm();
      expect(terminal.controller.phase, FutureMirrorPhase.terminalFailure);
      expect(
        await terminal.store.restore(_scope, terminal.controller.operation),
        isNull,
      );
    },
  );

  test('cross-intention comparison fails closed', () async {
    final fixture = _Fixture();
    await fixture.controller.openIntention(
      intentionId: 'intention-a',
      portfolioId: 'portfolio-a',
      ledgerWatermark: 12,
    );
    fixture.service.historical = _mirror(
      id: 'foreign-run',
      intentionId: 'intention-b',
    );
    await fixture.controller.compareWith('foreign-run');
    expect(fixture.controller.comparison, isNull);
    expect(fixture.controller.phase, FutureMirrorPhase.forbidden);
  });

  test(
    'altered protected projection watermark fails closed after restart',
    () async {
      final fixture = _Fixture()
        ..service.ambiguous = true
        ..service.persistAmbiguous = false;
      await fixture.controller.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      fixture.controller.prepare(fixture.controller.newDraft());
      await fixture.controller.confirm();
      final storageKey = fixture.storage.values.keys.single;
      final outer = jsonDecode(
        fixture.storage.values[storageKey]!,
      ) as Map<String, dynamic>;
      final protected =
          jsonDecode(outer['precondition'] as String) as Map<String, dynamic>;
      final data = protected['data'] as Map<String, dynamic>;
      data['ledger_watermark'] = 99;
      outer['precondition'] = jsonEncode(protected);
      fixture.storage.values[storageKey] = jsonEncode(outer);

      final restarted = fixture.restart();
      await restarted.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      expect(await fixture.store.restore(_scope, restarted.operation), isNull);
      expect(fixture.service.keys, ['mirror-key']);
    },
  );

  test(
    'altered protected projection assumptions fail closed after restart',
    () async {
      final fixture = _Fixture()
        ..service.ambiguous = true
        ..service.persistAmbiguous = false;
      await fixture.controller.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      fixture.controller.prepare(fixture.controller.newDraft());
      await fixture.controller.confirm();
      final storageKey = fixture.storage.values.keys.single;
      final outer = jsonDecode(
        fixture.storage.values[storageKey]!,
      ) as Map<String, dynamic>;
      final protected =
          jsonDecode(outer['precondition'] as String) as Map<String, dynamic>;
      final data = protected['data'] as Map<String, dynamic>;
      final assumptions = data['assumptions'] as Map<String, dynamic>;
      assumptions['monthly_contribution_minor'] = 999999;
      outer['precondition'] = jsonEncode(protected);
      fixture.storage.values[storageKey] = jsonEncode(outer);

      final restarted = fixture.restart();
      await restarted.openIntention(
        intentionId: 'intention-a',
        portfolioId: 'portfolio-a',
        ledgerWatermark: 12,
      );
      expect(await fixture.store.restore(_scope, restarted.operation), isNull);
      expect(fixture.service.keys, ['mirror-key']);
    },
  );
}

class _Fixture {
  _Fixture() {
    storage = _Storage();
    store = PendingCommandStore(storage: storage);
    controller = _controller();
  }

  final _Service service = _Service();
  late final _Storage storage;
  late final PendingCommandStore store;
  final InvalidationBus bus = InvalidationBus();
  final MemoryReadCache cache = MemoryReadCache();
  late final FutureMirrorController controller;

  FutureMirrorController _controller() => FutureMirrorController(
    repository: CachedFutureMirrorRepository(service: service, cache: cache),
    pendingStore: store,
    invalidationBus: bus,
    scope: _scope,
    createKey: () => 'mirror-key',
    now: () => DateTime.utc(2026, 8, 25),
    personalization: const MemberPersonalization(),
  );

  FutureMirrorController restart() => _controller();
}

class _Service implements FutureMirrorService {
  Object? failure;
  bool ambiguous = false;
  bool persistAmbiguous = true;
  bool failLatest = false;
  FutureMirror? latest;
  FutureMirror? historical;
  final List<String> keys = [];
  final List<String> getCalls = [];

  @override
  Future<FutureMirror> generate(FutureMirrorGenerate command) async {
    keys.add(command.idempotencyKey);
    final configuredFailure = failure;
    if (configuredFailure != null) throw configuredFailure;
    final generated = _mirror(assumptions: command.draft);
    if (!ambiguous || persistAmbiguous) latest ??= generated;
    if (ambiguous) throw const AmbiguousFutureMirrorGeneration();
    return latest ??= generated;
  }

  @override
  Future<FutureMirror?> getLatest(String intentionId) async {
    if (failLatest) throw const OfflineException();
    return latest;
  }

  @override
  Future<FutureMirror> get(String intentionId, String runId) async {
    getCalls.add(runId);
    return historical ?? _mirror(id: runId);
  }
}

const _scope = CacheScope(accountId: 'account-a', resetGeneration: 4);

FutureMirror _mirror({
  String id = 'mirror-a',
  String intentionId = 'intention-a',
  int watermark = 12,
  FutureMirrorDraft? assumptions,
}) => FutureMirror(
  id: id,
  intentionId: intentionId,
  assumptions:
      assumptions ??
      const FutureMirrorDraft(
        name: 'Illustrative path',
        monthlyContributionMinor: 2500,
        lowReturnBps: -1000,
        midReturnBps: 400,
        highReturnBps: 2200,
      ),
  points: [
    FutureMirrorPoint(
      date: DateTime.utc(2027, 8, 25),
      lowMinor: 250000,
      midMinor: 275000,
      highMinor: 310000,
    ),
  ],
  generatedAt: DateTime.utc(2026, 8, 25, 12),
  modelVersion: 'ritual-demo-v1',
  inputHash: 'a' * 64,
  ledgerWatermark: watermark,
  uncertainty:
      'Illustrative Demo ranges only; not advice and never a guarantee.',
  demo: FutureMirrorDemoDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25, 12),
    sourceLabel: 'Deterministic Demo ledger',
    limitations: const ['No real money moves.'],
  ),
);

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
