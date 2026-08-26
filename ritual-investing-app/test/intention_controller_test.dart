import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/intentions/application/intention_controller.dart';
import 'package:ritual_investing_app/features/intentions/data/repository.dart';
import 'package:ritual_investing_app/features/intentions/domain/model.dart';
import 'package:ritual_investing_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:ritual_investing_app/features/profile/domain/model.dart';

void main() {
  test(
    'profile goal and horizon visibly shape only new intention drafts',
    () async {
      final fixture = _Fixture()..service.value = _existingIntention();
      fixture.controller.updateProfile(_investor);

      final first = fixture.controller.newDraft(targetMinor: 250000);
      expect(first.title, 'Build a calm fund');
      expect(first.targetDate, DateTime.utc(2027, 8, 25));
      expect(fixture.controller.defaults.sourceLabel, contains('Calm fund'));

      fixture.controller.updateProfile(
        _investor.copyWith(
          goal: InvestmentGoal.longTermGrowth,
          horizon: InvestmentHorizon.long,
        ),
      );
      expect(fixture.controller.createDraft, first);
      expect(
        fixture.controller.newDraft(targetMinor: 250000).targetDate,
        DateTime.utc(2036, 8, 25),
      );
    },
  );

  test('create edit and archive reconcile authoritative versions', () async {
    final fixture = _Fixture();
    await fixture.controller.openPortfolio('portfolio-a');
    final draft = fixture.controller.newDraft(targetMinor: 250000);
    expect(await fixture.controller.prepareCreate(draft), isTrue);
    await fixture.controller.confirmCreate();
    expect(fixture.controller.selected?.version, 1);

    fixture.service.conflictNextPatch = true;
    fixture.controller.prepareEdit(
      fixture.controller.selected!.copyAsDraft(title: 'Preserved moon fund'),
    );
    await fixture.controller.confirmEdit();
    expect(fixture.controller.phase, IntentionPhase.conflictReview);
    expect(fixture.controller.editDraft?.title, 'Preserved moon fund');
    expect(fixture.controller.selected?.version, 2);

    fixture.controller.reviewEditAgainstAuthority();
    await fixture.controller.confirmEdit();
    expect(fixture.controller.selected?.title, 'Preserved moon fund');
    expect(fixture.controller.selected?.version, 3);

    fixture.controller.prepareArchive();
    await fixture.controller.confirmArchive();
    expect(fixture.controller.selected?.status, IntentionStatus.archived);
    expect(fixture.controller.selected?.version, 4);
  });

  test(
    'ambiguous create resolves exact authority without a second submit',
    () async {
      final fixture = _Fixture()..service.ambiguousCreate = true;
      await fixture.controller.openPortfolio('portfolio-a');
      await fixture.controller.prepareCreate(
        fixture.controller.newDraft(targetMinor: 250000),
      );
      await fixture.controller.confirmCreate();
      expect(fixture.controller.phase, IntentionPhase.detailReady);
      expect(fixture.service.createKeys, ['intention-key']);
      expect(
        await fixture.store.restore(_scope, fixture.controller.operation),
        isNull,
      );
    },
  );

  test(
    'unresolved create restores review and deliberately reuses one key',
    () async {
      final fixture = _Fixture()
        ..service.ambiguousCreate = true
        ..service.persistAmbiguousCreate = false;
      await fixture.controller.openPortfolio('portfolio-a');
      await fixture.controller.prepareCreate(
        fixture.controller.newDraft(targetMinor: 250000),
      );
      await fixture.controller.confirmCreate();
      expect(fixture.controller.phase, IntentionPhase.retryableFailure);
      expect(fixture.service.createKeys, ['intention-key']);

      final restarted = fixture.restart();
      await restarted.openPortfolio('portfolio-a');
      expect(restarted.phase, IntentionPhase.restoredReview);
      expect(fixture.service.createKeys, ['intention-key']);

      fixture.service.ambiguousCreate = false;
      restarted.reviewRestoredCreate();
      await restarted.confirmCreate();
      expect(fixture.service.createKeys, ['intention-key', 'intention-key']);
    },
  );

  test(
    'ledger invalidation refreshes only the open portfolio progress',
    () async {
      final fixture = _Fixture()..service.value = _existingIntention();
      await fixture.controller.openPortfolio('portfolio-a');
      fixture.service.progressMinor = 72000;
      fixture.bus.publish(
        const InvalidationEvent(
          scope: _scope,
          resource: InvalidationResource.ledger,
          ledgerWatermark: 18,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(fixture.controller.intentions.single.progressMinor, 72000);
      expect(fixture.service.listCalls, 2);
    },
  );

  test('global pages auto-scan past foreign portfolios before empty', () async {
    final fixture = _Fixture()
      ..service.value = _existingIntention()
      ..service.foreignFirstPage = true;

    await fixture.controller.openPortfolio('portfolio-a');

    expect(fixture.controller.phase, IntentionPhase.ready);
    expect(fixture.controller.intentions.single.id, 'intention-a');
    expect(fixture.service.listCalls, 2);
  });

  test(
    'unresolved create blocks discard until fresh authority returns',
    () async {
      final fixture = _Fixture()
        ..service.ambiguousCreate = true
        ..service.persistAmbiguousCreate = false;
      await fixture.controller.openPortfolio('portfolio-a');
      await fixture.controller.prepareCreate(
        fixture.controller.newDraft(targetMinor: 250000),
      );
      fixture.service.failList = true;
      await fixture.controller.confirmCreate();

      expect(fixture.controller.phase, IntentionPhase.reconciliationRequired);
      await fixture.controller.discardPendingCreate();
      expect(
        await fixture.store.restore(_scope, fixture.controller.operation),
        isNotNull,
      );

      fixture.service.failList = false;
      await fixture.controller.retryReconciliation();
      expect(fixture.controller.phase, IntentionPhase.restoredReview);
      await fixture.controller.discardPendingCreate();
      expect(
        await fixture.store.restore(_scope, fixture.controller.operation),
        isNull,
      );
    },
  );
}

class _Fixture {
  _Fixture() {
    controller = _controller();
  }

  final _Service service = _Service();
  final PendingCommandStore store = PendingCommandStore(storage: _Storage());
  final InvalidationBus bus = InvalidationBus();
  late final IntentionController controller;

  IntentionController _controller() => IntentionController(
    repository: CachedIntentionRepository(
      service: service,
      cache: MemoryReadCache(),
    ),
    pendingStore: store,
    invalidationBus: bus,
    scope: _scope,
    createKey: () => 'intention-key',
    now: () => DateTime.utc(2026, 8, 25),
  );

  IntentionController restart() => _controller();
}

class _Service implements IntentionService {
  Intention? value;
  bool ambiguousCreate = false;
  bool persistAmbiguousCreate = true;
  bool conflictNextPatch = false;
  bool failList = false;
  bool foreignFirstPage = false;
  int progressMinor = 50000;
  int listCalls = 0;
  final List<String> createKeys = [];

  @override
  Future<IntentionPage> list({String? cursor, IntentionStatus? status}) async {
    listCalls += 1;
    if (failList) throw const OfflineException();
    if (foreignFirstPage && cursor == null) {
      return IntentionPage(
        items: [_existingIntention().copyWith(portfolioId: 'portfolio-b')],
        hasMore: true,
        nextCursor: 'page-two',
      );
    }
    final item = value;
    return IntentionPage(
      items: item == null
          ? const []
          : [item.copyWith(progressMinor: progressMinor)],
      hasMore: false,
    );
  }

  @override
  Future<Intention> create(IntentionCreate command) async {
    createKeys.add(command.idempotencyKey);
    final created = Intention(
      id: 'intention-a',
      portfolioId: command.draft.portfolioId,
      title: command.draft.title,
      targetMinor: command.draft.targetMinor,
      targetDate: command.draft.targetDate,
      status: IntentionStatus.active,
      progressMinor: progressMinor,
      progressBps: 2000,
      version: 1,
      demo: _demo,
    );
    if (!ambiguousCreate || persistAmbiguousCreate) value ??= created;
    if (ambiguousCreate) throw const AmbiguousIntentionCreate();
    return value ??= created;
  }

  @override
  Future<Intention> get(String intentionId) async {
    final item = value;
    if (item == null) throw LoadFailure(LoadPhase.empty);
    return item.copyWith(progressMinor: progressMinor);
  }

  @override
  Future<Intention> patch(IntentionPatch command) async {
    if (conflictNextPatch) {
      conflictNextPatch = false;
      value = value!.copyWith(version: value!.version + 1);
      throw LoadFailure(LoadPhase.conflict);
    }
    value = value!.copyWith(
      title: command.draft.title,
      targetMinor: command.draft.targetMinor,
      targetDate: command.draft.targetDate,
      status: command.draft.status,
      version: value!.version + 1,
    );
    return value!;
  }

  @override
  Future<void> archive(String intentionId, int expectedVersion) async {
    value = value!.copyWith(
      status: IntentionStatus.archived,
      version: value!.version + 1,
    );
  }
}

const _scope = CacheScope(accountId: 'account-a', resetGeneration: 4);

const _investor = SavedInvestorProfile(
  goal: InvestmentGoal.calmFund,
  horizon: InvestmentHorizon.short,
  risk: RiskComfort.low,
  isDemo: true,
  version: 1,
  contributionRhythm: ContributionRhythm.monthly,
);

final _demo = IntentionDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25),
  sourceLabel: 'Deterministic Demo ledger',
  limitations: const ['No real money moves.'],
);

Intention _existingIntention() => Intention(
  id: 'intention-a',
  portfolioId: 'portfolio-a',
  title: 'Build a calm fund',
  targetMinor: 250000,
  targetDate: DateTime.utc(2027, 8, 25),
  status: IntentionStatus.active,
  progressMinor: 50000,
  progressBps: 2000,
  version: 1,
  demo: _demo,
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

extension on SavedInvestorProfile {
  SavedInvestorProfile copyWith({
    InvestmentGoal? goal,
    InvestmentHorizon? horizon,
  }) => SavedInvestorProfile(
    experience: experience,
    goal: goal ?? this.goal,
    horizon: horizon ?? this.horizon,
    risk: risk,
    contributionRhythm: contributionRhythm,
    isDemo: isDemo,
    version: version,
  );
}
