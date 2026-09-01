import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/notifications/application/notification_controller.dart';
import 'package:ritual_investing_app/features/notifications/data/repository.dart';
import 'package:ritual_investing_app/features/notifications/domain/model.dart';

void main() {
  test(
    'loads in-app feed and server-owned preferences without push state',
    () async {
      final repository = _NotificationRepository();
      final controller = _controller(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.phase, NotificationPhase.ready);
      expect(
        controller.items.single.destination?.location,
        '/gospel/briefings',
      );
      expect(controller.preferences?.version, 3);
      expect(controller.externalDeliveryAvailable, isFalse);
    },
  );

  test('read and preference changes require authoritative echoes', () async {
    final repository = _NotificationRepository();
    final controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.setRead(_notificationId, true);
    expect(controller.items.single.isRead, isTrue);

    controller.editPreferences(
      controller.preferences!.copyWith(dailyRitual: false),
    );
    await controller.savePreferences();
    expect(controller.preferences?.dailyRitual, isFalse);
    expect(repository.preferenceVersions, [3]);
  });

  test(
    'ambiguous read-all never auto-submits and reuses one protected key',
    () async {
      final repository = _NotificationRepository()..ambiguousReadAll = true;
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      controller.prepareReadAll();

      await controller.confirmReadAll();

      expect(controller.phase, NotificationPhase.restoredReview);
      expect(repository.readAllKeys, ['read-all-key']);
      expect(repository.readAllCalls, 1);

      repository.ambiguousReadAll = false;
      controller.reviewRestoredReadAll();
      await controller.confirmReadAll();

      expect(repository.readAllKeys, ['read-all-key', 'read-all-key']);
      expect(controller.phase, NotificationPhase.ready);
    },
  );

  test(
    'authority outage after lost read-all requires reconciliation',
    () async {
      final repository = _NotificationRepository()
        ..ambiguousReadAll = true
        ..reconciliationUnavailable = true;
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      controller.prepareReadAll();

      await controller.confirmReadAll();

      expect(controller.phase, NotificationPhase.reconciliationRequired);
      expect(repository.readAllCalls, 1);
      await controller.retryReconciliation();
      expect(repository.readAllCalls, 1, reason: 'reconciliation is read-only');
    },
  );

  for (final failure in [
    const LoadFailure(LoadPhase.retryableFailure),
    const LoadFailure(LoadPhase.throttled),
  ]) {
    test(
      'protected read-all remains reviewable after ${failure.phase.name}',
      () async {
        final repository = _NotificationRepository()
          ..emptyFeed = true
          ..readAllFailure = failure;
        final controller = _controller(repository);
        addTearDown(controller.dispose);
        await controller.load();
        controller.prepareReadAll();

        await controller.confirmReadAll();

        expect(controller.hasProtectedReadAll, isTrue);
        expect(controller.canReviewProtectedReadAll, isTrue);
        controller.reviewRestoredReadAll();
        expect(controller.phase, NotificationPhase.readAllReview);

        await controller.discardPendingReadAll();
        expect(controller.hasProtectedReadAll, isFalse);
      },
    );
  }

  test(
    'read-all scans every authoritative unread page before claiming success',
    () async {
      final repository = _NotificationRepository()
        ..ambiguousReadAll = true
        ..unreadPages = [
          const NotificationPage(
            items: [],
            hasMore: true,
            nextCursor: 'page-2',
          ),
          NotificationPage(
            items: [_noticeAt(_now.subtract(const Duration(minutes: 1)))],
            hasMore: false,
          ),
        ];
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      controller.prepareReadAll();

      await controller.confirmReadAll();

      expect(controller.phase, NotificationPhase.restoredReview);
      expect(repository.unreadLoadCalls, 2);
    },
  );

  test(
    'unread notices after the protected cutoff do not block exact recovery',
    () async {
      final repository = _NotificationRepository()
        ..ambiguousReadAll = true
        ..unreadPages = [
          NotificationPage(
            items: [_noticeAt(_now.add(const Duration(minutes: 1)))],
            hasMore: false,
          ),
        ];
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      controller.prepareReadAll();

      await controller.confirmReadAll();

      expect(controller.phase, NotificationPhase.ready);
      expect(controller.hasProtectedReadAll, isFalse);
    },
  );

  test(
    'preference conflict refreshes authority and preserves local edits',
    () async {
      final repository = _NotificationRepository()..preferenceConflict = true;
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      controller.editPreferences(
        controller.preferences!.copyWith(dailyRitual: false),
      );

      await controller.savePreferences();

      expect(controller.phase, NotificationPhase.preferenceConflict);
      expect(controller.preferences?.weeklyRecap, isFalse);
      expect(controller.preferenceDraft?.dailyRitual, isFalse);
      controller.reviewPreferenceConflict();
      expect(controller.phase, NotificationPhase.preferencesReview);
    },
  );

  test(
    'preference ambiguity outage retries only read-only reconciliation',
    () async {
      final repository = _NotificationRepository();
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      repository.preferenceAmbiguous = true;
      repository.ambiguousAppliesDraft = true;
      controller.editPreferences(
        controller.preferences!.copyWith(dailyRitual: false),
      );

      await controller.savePreferences();
      expect(controller.phase, NotificationPhase.reconciliationRequired);
      expect(repository.preferencePatchCalls, 1);

      await controller.retryReconciliation();
      expect(repository.preferencePatchCalls, 1, reason: 'retry is GET-only');
      expect(controller.phase, NotificationPhase.ready);
      expect(controller.preferences?.dailyRitual, isFalse);
    },
  );

  test(
    'preference ambiguity mismatch becomes preserved conflict review',
    () async {
      final repository = _NotificationRepository();
      final controller = _controller(repository);
      addTearDown(controller.dispose);
      await controller.load();
      repository.preferenceAmbiguous = true;
      repository.ambiguousAppliesDraft = false;
      controller.editPreferences(
        controller.preferences!.copyWith(dailyRitual: false),
      );

      await controller.savePreferences();
      expect(controller.phase, NotificationPhase.reconciliationRequired);
      await controller.retryReconciliation();

      expect(controller.phase, NotificationPhase.preferenceConflict);
      expect(controller.preferenceDraft?.dailyRitual, isFalse);
      expect(repository.preferencePatchCalls, 1);
    },
  );

  test('unknown and external notification routes fail closed', () {
    expect(
      NotificationDestination.tryParse('/briefings')?.location,
      '/gospel/briefings',
    );
    expect(
      NotificationDestination.tryParse('/briefings/$_briefingId')?.location,
      '/gospel/briefings/$_briefingId',
    );
    expect(NotificationDestination.tryParse('https://example.com'), isNull);
    expect(NotificationDestination.tryParse('/admin/jobs'), isNull);
    expect(NotificationDestination.tryParse('/briefings/not-a-uuid'), isNull);
  });

  test('protected read-all recovery is account/reset scoped', () async {
    final storage = _Storage();
    final repositoryA = _NotificationRepository()..ambiguousReadAll = true;
    final controllerA = _controller(repositoryA, storage: storage);
    await controllerA.load();
    controllerA.prepareReadAll();
    await controllerA.confirmReadAll();
    controllerA.dispose();

    final controllerB = _controller(
      _NotificationRepository(),
      storage: storage,
      scope: const CacheScope(accountId: 'account-b', resetGeneration: 2),
    );
    addTearDown(controllerB.dispose);
    await controllerB.load();

    expect(controllerB.phase, NotificationPhase.ready);
    expect(controllerB.hasProtectedReadAll, isFalse);
  });
}

NotificationController _controller(
  _NotificationRepository repository, {
  _Storage? storage,
  CacheScope scope = _scope,
}) => NotificationController(
  repository: repository,
  pendingStore: PendingCommandStore(storage: storage ?? _Storage()),
  invalidationBus: InvalidationBus(),
  scope: scope,
  createKey: () => 'read-all-key',
  now: () => _now,
);

class _NotificationRepository implements NotificationRepository {
  bool ambiguousReadAll = false;
  bool reconciliationUnavailable = false;
  bool emptyFeed = false;
  LoadFailure? readAllFailure;
  bool preferenceConflict = false;
  bool preferenceAmbiguous = false;
  bool ambiguousAppliesDraft = false;
  List<NotificationPage>? unreadPages;
  int unreadLoadCalls = 0;
  int readAllCalls = 0;
  int preferencePatchCalls = 0;
  int preferenceGetFailures = 0;
  final List<String> readAllKeys = [];
  final List<int> preferenceVersions = [];
  bool _read = false;
  NotificationPreferences _preferences = _initialPreferences;

  NotificationItem get _item => NotificationItem(
    id: _notificationId,
    kind: NotificationKind.briefingReady,
    title: 'Your briefing is ready',
    body: 'Open Ritual to reflect.',
    destination: NotificationDestination.tryParse('/briefings'),
    scheduledAt: _now.subtract(const Duration(minutes: 5)),
    readAt: _read ? _now : null,
  );

  @override
  Future<RepositoryRead<NotificationPage>> load({
    NotificationReadFilter filter = NotificationReadFilter.all,
    String? cursor,
  }) async {
    if (reconciliationUnavailable && filter == NotificationReadFilter.unread) {
      throw const OfflineException();
    }
    if (filter == NotificationReadFilter.unread && unreadPages != null) {
      final index = unreadLoadCalls++;
      final page =
          unreadPages![index >= unreadPages!.length
              ? unreadPages!.length - 1
              : index];
      return RepositoryRead(value: page, isStale: false, committedAt: _now);
    }
    final items =
        emptyFeed || (filter == NotificationReadFilter.unread && _read)
        ? <NotificationItem>[]
        : [_item];
    return RepositoryRead(
      value: NotificationPage(items: items, hasMore: false),
      isStale: false,
      committedAt: _now,
    );
  }

  @override
  Future<RepositoryRead<NotificationPreferences>> getPreferences() async {
    if (preferenceGetFailures > 0) {
      preferenceGetFailures--;
      throw const OfflineException();
    }
    return RepositoryRead(
      value: _preferences,
      isStale: false,
      committedAt: _now,
    );
  }

  @override
  Future<NotificationItem> setRead(String notificationId, bool read) async {
    _read = read;
    return _item;
  }

  @override
  Future<NotificationPreferences> patchPreferences(
    NotificationPreferencesDraft draft,
    int expectedVersion,
  ) async {
    preferencePatchCalls++;
    preferenceVersions.add(expectedVersion);
    if (preferenceAmbiguous) {
      preferenceAmbiguous = false;
      _preferences = ambiguousAppliesDraft
          ? draft.toPreferences(version: expectedVersion + 1)
          : _preferences.copyWith(
              weeklyRecap: false,
              version: expectedVersion + 1,
            );
      preferenceGetFailures = 1;
      throw const AmbiguousNotificationPreferences();
    }
    if (preferenceConflict) {
      preferenceConflict = false;
      _preferences = _preferences.copyWith(
        weeklyRecap: false,
        version: expectedVersion + 1,
      );
      throw const LoadFailure(LoadPhase.conflict);
    }
    _preferences = draft.toPreferences(version: expectedVersion + 1);
    return _preferences;
  }

  @override
  Future<int> readAll(NotificationReadAll command) async {
    readAllCalls++;
    readAllKeys.add(command.idempotencyKey);
    if (readAllFailure case final failure?) throw failure;
    if (ambiguousReadAll) {
      ambiguousReadAll = false;
      throw const AmbiguousNotificationReadAll();
    }
    _read = true;
    return 1;
  }
}

NotificationItem _noticeAt(DateTime scheduledAt) => NotificationItem(
  id: _notificationId,
  kind: NotificationKind.briefingReady,
  title: 'Your briefing is ready',
  body: 'Open Ritual to reflect.',
  destination: NotificationDestination.tryParse('/briefings'),
  scheduledAt: scheduledAt,
  readAt: null,
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

const _scope = CacheScope(accountId: 'account-a', resetGeneration: 2);
final _now = DateTime.utc(2026, 8, 25, 12);
const _notificationId = '018f3c2a-4b67-4a89-8abc-123456789011';
const _briefingId = '018f3c2a-4b67-4a89-8abc-123456789001';
const _initialPreferences = NotificationPreferences(
  dailyRitual: true,
  weeklyRecap: true,
  moonCycle: true,
  quietHours: NotificationQuietHours(
    enabled: false,
    start: '22:00',
    end: '07:00',
    timezone: 'UTC',
  ),
  version: 3,
);
