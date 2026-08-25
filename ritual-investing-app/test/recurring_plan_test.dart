import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/recurring/application/recurring_plan_controller.dart';
import 'package:ritual_investing_app/features/recurring/data/repository.dart';
import 'package:ritual_investing_app/features/recurring/domain/model.dart';

void main() {
  test(
    'rhythm is an editable suggestion and create uses one protected key',
    () async {
      final service = _RecurringService()..ambiguousCreate = true;
      final storage = _Storage();
      final controller = _controller(service, storage);
      expect(controller.defaults.frequency, RecurringFrequency.weekly);

      await controller.prepareCreate(
        RecurringPlanDraft(
          portfolioId: 'portfolio-a',
          sourceId: 'source-a',
          type: RecurringType.contribution,
          amountMinor: 2500,
          frequency: RecurringFrequency.monthly,
          firstRunAt: DateTime.utc(2026, 9, 1),
          allocations: const [
            RecurringAllocation(assetId: 'asset-a', weightBps: 10000),
          ],
        ),
        sourceIsActive: true,
      );
      await controller.confirmCreate();
      expect(controller.phase, RecurringCommandPhase.retryableFailure);

      final restarted = _controller(service, storage);
      await restarted.openPortfolio('portfolio-a');
      expect(restarted.phase, RecurringCommandPhase.restoredReview);
      expect(service.createKeys, ['recurring-key']);
      restarted.reviewRestoredCreate();
      service.ambiguousCreate = false;
      await restarted.confirmCreate();
      expect(service.createKeys, ['recurring-key', 'recurring-key']);
      expect(service.createEffects, 1);
    },
  );

  test('create rejects inactive fictional source before API traffic', () async {
    final service = _RecurringService();
    final controller = _controller(service, _Storage());
    final accepted = await controller.prepareCreate(
      RecurringPlanDraft(
        portfolioId: 'portfolio-a',
        sourceId: 'inactive-source',
        type: RecurringType.contribution,
        amountMinor: 2500,
        frequency: RecurringFrequency.weekly,
        firstRunAt: DateTime.utc(2026, 9, 1),
        allocations: const [
          RecurringAllocation(assetId: 'asset-a', weightBps: 10000),
        ],
      ),
      sourceIsActive: false,
    );
    expect(accepted, isFalse);
    expect(service.createKeys, isEmpty);
  });

  test(
    'ambiguous pause reconciles authoritative target and never repeats blindly',
    () async {
      final service = _RecurringService()..pauseAmbiguousAfterCommit = true;
      final controller = _controller(service, _Storage());
      await controller.openPortfolio('portfolio-a');
      await controller.openPlan('plan-a');

      await controller.pause();

      expect(service.pauseVersions, [4]);
      expect(controller.selected?.status, RecurringStatus.paused);
      expect(controller.phase, RecurringCommandPhase.detailReady);
    },
  );

  test(
    'version conflict refresh preserves edit draft and requires reconfirmation',
    () async {
      final service = _RecurringService()
        ..editFailure = const RecurringFailure.conflict();
      final controller = _controller(service, _Storage());
      await controller.openPortfolio('portfolio-a');
      await controller.openPlan('plan-a');
      controller.prepareEdit(
        amountMinor: 5000,
        frequency: RecurringFrequency.monthly,
      );
      await controller.confirmEdit();

      expect(controller.phase, RecurringCommandPhase.conflictReview);
      expect(controller.editDraft?.amountMinor, 5000);
      expect(service.editVersions, [4]);
      service.editFailure = null;
      controller.reviewEditAgainstAuthority();
      await controller.confirmEdit();
      expect(service.editVersions, [4, 5]);
    },
  );

  test(
    'create rechecks current source immediately before any API traffic',
    () async {
      var active = true;
      final service = _RecurringService();
      final controller = _controller(
        service,
        _Storage(),
        isFundingSourceActive: (_) async => active,
      );
      await controller.prepareCreate(_draft(), sourceIsActive: true);
      active = false;
      await controller.confirmCreate();
      expect(service.createKeys, isEmpty);
      expect(controller.phase, RecurringCommandPhase.reconciliationRequired);
    },
  );

  test(
    'restored create requires the saved fictional source to remain active',
    () async {
      var active = true;
      final service = _RecurringService()..ambiguousCreate = true;
      final storage = _Storage();
      final controller = _controller(
        service,
        storage,
        isFundingSourceActive: (_) async => active,
      );
      await controller.prepareCreate(_draft(), sourceIsActive: true);
      await controller.confirmCreate();
      active = false;

      final restarted = _controller(
        service,
        storage,
        isFundingSourceActive: (_) async => active,
      );
      await restarted.openPortfolio('portfolio-a');
      expect(restarted.phase, RecurringCommandPhase.reconciliationRequired);
      restarted.reviewRestoredCreate();
      await restarted.confirmCreate();
      expect(service.createKeys, ['recurring-key']);
      expect(service.createEffects, 1);
    },
  );

  test(
    'failed conflict refetch preserves edit and blocks stale retry',
    () async {
      final service = _RecurringService()
        ..editFailure = const RecurringFailure.conflict()
        ..failGetAfterEdit = true;
      final controller = _controller(service, _Storage());
      await controller.openPortfolio('portfolio-a');
      await controller.openPlan('plan-a');
      controller.prepareEdit(amountMinor: 5000);
      await controller.confirmEdit();
      expect(controller.phase, RecurringCommandPhase.reconciliationRequired);
      expect(controller.editDraft?.amountMinor, 5000);
      controller.reviewEditAgainstAuthority();
      await controller.confirmEdit();
      expect(service.editVersions, [4]);
    },
  );

  test('ambiguous edit compares allocations canonically by asset ID', () async {
    final service = _RecurringService()
      ..value = _plan(
        allocations: const [
          RecurringAllocation(assetId: 'asset-a', weightBps: 6000),
          RecurringAllocation(assetId: 'asset-b', weightBps: 4000),
        ],
      )
      ..ambiguousEditAfterCommit = true;
    final controller = _controller(service, _Storage());
    await controller.openPortfolio('portfolio-a');
    await controller.openPlan('plan-a');
    controller.prepareEdit(
      allocations: const [
        RecurringAllocation(assetId: 'asset-b', weightBps: 3000),
        RecurringAllocation(assetId: 'asset-a', weightBps: 7000),
      ],
    );
    await controller.confirmEdit();
    expect(controller.phase, RecurringCommandPhase.detailReady);
    expect(service.editVersions, [4]);
  });

  test(
    'throttled create retains exact review while terminal create clears it',
    () async {
      final throttledStorage = _Storage();
      final throttledService = _RecurringService()
        ..createFailure = const LoadFailure(LoadPhase.throttled);
      final throttled = _controller(throttledService, throttledStorage);
      await throttled.prepareCreate(_draft(), sourceIsActive: true);
      await throttled.confirmCreate();
      expect(throttled.phase, RecurringCommandPhase.throttled);
      expect(throttledStorage.values, isNotEmpty);
      throttled.reviewRestoredCreate();
      expect(throttled.phase, RecurringCommandPhase.createReview);

      final terminalStorage = _Storage();
      final terminalService = _RecurringService()
        ..createFailure = const LoadFailure(LoadPhase.terminalFailure);
      final terminal = _controller(terminalService, terminalStorage);
      await terminal.prepareCreate(_draft(), sourceIsActive: true);
      await terminal.confirmCreate();
      expect(terminal.phase, RecurringCommandPhase.terminalFailure);
      expect(terminalStorage.values, isEmpty);
    },
  );
}

RecurringPlanController _controller(
  _RecurringService service,
  _Storage storage, {
  Future<bool> Function(String sourceId)? isFundingSourceActive,
}) => RecurringPlanController(
  repository: RecurringPlanRepository(service: service),
  pendingStore: PendingCommandStore(storage: storage),
  scope: const CacheScope(accountId: 'account-a', resetGeneration: 3),
  createKey: () => 'recurring-key',
  now: () => DateTime.utc(2026, 8, 25),
  rhythm: MemberContributionRhythm.weekly,
  isFundingSourceActive: isFundingSourceActive ?? (_) async => true,
);

RecurringPlanDraft _draft() => RecurringPlanDraft(
  portfolioId: 'portfolio-a',
  sourceId: 'source-a',
  type: RecurringType.contribution,
  amountMinor: 2500,
  frequency: RecurringFrequency.monthly,
  firstRunAt: DateTime.utc(2026, 9, 1),
  allocations: const [
    RecurringAllocation(assetId: 'asset-a', weightBps: 10000),
  ],
);

class _RecurringService implements RecurringPlanService {
  bool ambiguousCreate = false;
  bool pauseAmbiguousAfterCommit = false;
  bool ambiguousEditAfterCommit = false;
  bool failGetAfterEdit = false;
  Object? editFailure;
  Object? createFailure;
  final List<String> createKeys = [];
  final Map<String, RecurringPlan> _creates = {};
  int createEffects = 0;
  final List<int> pauseVersions = [];
  final List<int> editVersions = [];
  RecurringPlan value = _plan();

  @override
  Future<List<RecurringPlan>> list(String portfolioId) async => [value];
  @override
  Future<RecurringPlan> get(String planId) async {
    if (failGetAfterEdit && editVersions.isNotEmpty) {
      throw const OfflineException();
    }
    return value;
  }

  @override
  Future<RecurringPlan> create(RecurringPlanCreate command) async {
    createKeys.add(command.idempotencyKey);
    if (createFailure case final failure?) throw failure;
    final existing = _creates[command.idempotencyKey];
    if (existing != null) return existing;
    _creates[command.idempotencyKey] = value;
    createEffects += 1;
    if (ambiguousCreate) throw const AmbiguousRecurringCreateFailure();
    return value;
  }

  @override
  Future<RecurringPlan> edit(RecurringPlanEdit command) async {
    editVersions.add(command.expectedVersion);
    if (editFailure case final failure?) {
      value = _plan(version: 5);
      throw failure;
    }
    value = _plan(
      version: command.expectedVersion + 1,
      amountMinor: command.amountMinor ?? value.amountMinor,
      frequency: command.frequency ?? value.frequency,
      allocations: command.allocations == null
          ? value.allocations
          : command.allocations!.reversed.toList(growable: false),
    );
    if (ambiguousEditAfterCommit) {
      throw const AmbiguousRecurringMutationFailure();
    }
    return value;
  }

  @override
  Future<RecurringPlan> pause(String planId, int expectedVersion) async {
    pauseVersions.add(expectedVersion);
    value = _plan(status: RecurringStatus.paused, version: expectedVersion + 1);
    if (pauseAmbiguousAfterCommit) {
      throw const AmbiguousRecurringMutationFailure();
    }
    return value;
  }

  @override
  Future<RecurringPlan> resume(String planId, int expectedVersion) async =>
      value = _plan(
        status: RecurringStatus.active,
        version: expectedVersion + 1,
      );
  @override
  Future<void> cancel(String planId, int expectedVersion) async {
    value = _plan(
      status: RecurringStatus.cancelled,
      version: expectedVersion + 1,
    );
  }
}

RecurringPlan _plan({
  RecurringStatus status = RecurringStatus.active,
  int version = 4,
  int amountMinor = 2500,
  RecurringFrequency frequency = RecurringFrequency.weekly,
  List<RecurringAllocation> allocations = const [
    RecurringAllocation(assetId: 'asset-a', weightBps: 10000),
  ],
}) => RecurringPlan(
  id: 'plan-a',
  portfolioId: 'portfolio-a',
  type: RecurringType.contribution,
  amountMinor: amountMinor,
  frequency: frequency,
  nextRunAt: DateTime.utc(2026, 9, 1),
  status: status,
  allocations: allocations,
  recentRuns: const [],
  version: version,
  demo: RecurringDemoDisclosure(
    isDemo: true,
    observedAt: DateTime.utc(2026, 8, 25),
    sourceLabel: 'Demo scheduler',
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
