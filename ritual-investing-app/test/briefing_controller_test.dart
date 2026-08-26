import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/briefings/application/briefing_controller.dart';
import 'package:ritual_investing_app/features/briefings/data/repository.dart';
import 'package:ritual_investing_app/features/briefings/domain/model.dart';

void main() {
  test('loads all recap cadences, detail authority, and read state', () async {
    final repository = _BriefingRepository();
    final controller = BriefingController(
      repository: repository,
      invalidationBus: InvalidationBus(),
      scope: _scope,
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.phase, BriefingPhase.ready);
    expect(controller.items.map((item) => item.type), [
      BriefingType.daily,
      BriefingType.weekly,
      BriefingType.moonCycle,
    ]);

    await controller.open(_dailyId);
    expect(controller.phase, BriefingPhase.detailReady);
    expect(controller.selected?.sections.single.disclosure, contains('Demo'));
    expect(
      controller.selected?.formatLabel,
      'Reviewed local parser · summary v1',
    );

    await controller.setSelectedRead(true);
    expect(controller.selected?.isRead, isTrue);
    expect(repository.setReadCalls, [(_dailyId, true)]);
  });

  test('daily pending is honest and never invokes a generation path', () async {
    final repository = _BriefingRepository()
      ..dailyResult = DailyBriefingResult.pending(DateTime.utc(2026, 8, 25));
    final controller = BriefingController(
      repository: repository,
      invalidationBus: InvalidationBus(),
      scope: _scope,
    );
    addTearDown(controller.dispose);

    await controller.loadDaily(DateTime.utc(2026, 8, 25));

    expect(controller.phase, BriefingPhase.pending);
    expect(controller.pendingDate, DateTime.utc(2026, 8, 25));
    expect(repository.dailyCalls, 1);
  });

  test(
    'new ledger watermark marks source stale and refreshes feature-owned reads',
    () async {
      final bus = InvalidationBus();
      final repository = _BriefingRepository();
      final controller = BriefingController(
        repository: repository,
        invalidationBus: bus,
        scope: _scope,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(repository.loadCalls, 1);

      await controller.open(_dailyId);
      expect(repository.getCalls, 1);

      repository.sourceSequence = 14;
      bus.publish(
        const InvalidationEvent(
          scope: _scope,
          resource: InvalidationResource.ledger,
          ledgerWatermark: 14,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.loadCalls, 2);
      expect(controller.items.first.sourceSequence, 14);
      expect(repository.getCalls, 2);
      expect(controller.selected?.sourceSequence, 14);
      expect(controller.isStale, isFalse);
    },
  );

  test('offline cached list keeps read-state uncertainty visible', () async {
    final repository = _BriefingRepository()..stale = true;
    final controller = BriefingController(
      repository: repository,
      invalidationBus: InvalidationBus(),
      scope: _scope,
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.phase, BriefingPhase.stale);
    expect(controller.message, contains('Read state'));
  });

  test('cache scope prevents account A recap leakage into account B', () async {
    final storage = MemoryReadCache();
    final accountA = CachedBriefingRepository(
      service: _BriefingService(sourceSequence: 9),
      cache: ScopedReadCache(storage: storage, scope: _scope),
    );
    final accountBService = _BriefingService(sourceSequence: 20, offline: true);
    final accountB = CachedBriefingRepository(
      service: accountBService,
      cache: ScopedReadCache(
        storage: storage,
        scope: const CacheScope(accountId: 'account-b', resetGeneration: 2),
      ),
    );

    await accountA.load();
    await expectLater(accountB.load(), throwsA(isA<OfflineException>()));
  });
}

class _BriefingRepository implements BriefingRepository {
  int sourceSequence = 9;
  bool stale = false;
  int loadCalls = 0;
  int dailyCalls = 0;
  int getCalls = 0;
  DailyBriefingResult? dailyResult;
  final List<(String, bool)> setReadCalls = [];

  List<BriefingSummary> get _items => [
    _summary(_dailyId, BriefingType.daily, sourceSequence),
    _summary(_weeklyId, BriefingType.weekly, sourceSequence),
    _summary(_moonId, BriefingType.moonCycle, sourceSequence),
  ];

  @override
  Future<RepositoryRead<BriefingPage>> load({
    BriefingType? type,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? cursor,
  }) async {
    loadCalls++;
    return RepositoryRead(
      value: BriefingPage(items: _items, hasMore: false),
      isStale: stale,
      committedAt: _now,
    );
  }

  @override
  Future<RepositoryRead<BriefingDetail>> get(String briefingId) async {
    getCalls++;
    return RepositoryRead(
      value: _detail(briefingId, sourceSequence),
      isStale: stale,
      committedAt: _now,
    );
  }

  @override
  Future<DailyBriefingResult> daily(DateTime localDate) async {
    dailyCalls++;
    return dailyResult ??
        DailyBriefingResult.available(_detail(_dailyId, sourceSequence));
  }

  @override
  Future<BriefingSummary> setRead(String briefingId, bool read) async {
    setReadCalls.add((briefingId, read));
    return _summary(
      briefingId,
      BriefingType.daily,
      sourceSequence,
      readAt: read ? _now : null,
    );
  }
}

class _BriefingService implements BriefingService {
  _BriefingService({required this.sourceSequence, this.offline = false});

  final int sourceSequence;
  final bool offline;

  @override
  Future<BriefingPage> list({
    BriefingType? type,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? cursor,
  }) async {
    if (offline) throw const OfflineException();
    return BriefingPage(
      items: [_summary(_dailyId, BriefingType.daily, sourceSequence)],
      hasMore: false,
    );
  }

  @override
  Future<BriefingDetail> get(String briefingId) async {
    if (offline) throw const OfflineException();
    return _detail(briefingId, sourceSequence);
  }

  @override
  Future<DailyBriefingResult> daily(DateTime localDate) async {
    if (offline) throw const OfflineException();
    return DailyBriefingResult.available(_detail(_dailyId, sourceSequence));
  }

  @override
  Future<BriefingSummary> setRead(String briefingId, bool read) async =>
      _summary(briefingId, BriefingType.daily, sourceSequence);
}

BriefingSummary _summary(
  String id,
  BriefingType type,
  int sourceSequence, {
  DateTime? readAt,
}) => BriefingSummary(
  id: id,
  type: type,
  periodStart: DateTime.utc(2026, 8, 25),
  periodEnd: DateTime.utc(2026, 8, 25),
  generatedAt: _now,
  generation: 1,
  sourceSequence: sourceSequence,
  readAt: readAt,
);

BriefingDetail _detail(String id, int sourceSequence) => BriefingDetail(
  summary: _summary(id, BriefingType.daily, sourceSequence),
  sections: [
    BriefingSummarySection(
      ordinal: 1,
      sourceSequence: sourceSequence,
      disclosure: 'Generated from committed Demo activity.',
    ),
  ],
);

const _scope = CacheScope(accountId: 'account-a', resetGeneration: 2);
final _now = DateTime.utc(2026, 8, 25, 12);
const _dailyId = '018f3c2a-4b67-4a89-8abc-123456789001';
const _weeklyId = '018f3c2a-4b67-4a89-8abc-123456789002';
const _moonId = '018f3c2a-4b67-4a89-8abc-123456789003';
