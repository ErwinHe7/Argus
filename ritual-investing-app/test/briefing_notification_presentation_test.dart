import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/briefings/application/briefing_controller.dart';
import 'package:ritual_investing_app/features/briefings/data/repository.dart';
import 'package:ritual_investing_app/features/briefings/domain/model.dart';
import 'package:ritual_investing_app/features/briefings/presentation/briefing_screen.dart';
import 'package:ritual_investing_app/features/notifications/application/notification_controller.dart';
import 'package:ritual_investing_app/features/notifications/data/repository.dart';
import 'package:ritual_investing_app/features/notifications/domain/model.dart';
import 'package:ritual_investing_app/features/notifications/presentation/notification_screen.dart';

void main() {
  testWidgets('briefing detail is usable at 2x with authority adjacent', (
    tester,
  ) async {
    final controller = BriefingController(
      repository: _Briefings(),
      invalidationBus: InvalidationBus(),
      scope: _scope,
      personalization: const MemberPersonalization(
        ritualVoice: MemberRitualVoice.mystical,
      ),
    );
    addTearDown(controller.dispose);
    await controller.open(_briefingId);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: BriefingDetailScreen(
          briefingId: _briefingId,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Symbolic reflection'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('summary v1'),
      280,
      scrollable: _verticalScrollable,
    );
    expect(find.textContaining('summary v1'), findsOneWidget);
    expect(find.textContaining('Source sequence 14'), findsOneWidget);
    expect(find.textContaining('Recorded at'), findsOneWidget);
    expect(find.textContaining('Demo'), findsWidgets);
    expect(find.textContaining('not financial advice'), findsOneWidget);
    expect(find.text(_briefingId), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('briefing-read-toggle')),
      280,
      scrollable: _verticalScrollable,
    );
    expect(
      tester.getSize(find.byKey(const Key('briefing-read-toggle'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dark in-app feed has preferences, read-all review, and no device UI',
    (tester) async {
      final controller = NotificationController(
        repository: _Notifications(),
        pendingStore: PendingCommandStore(storage: _Storage()),
        invalidationBus: InvalidationBus(),
        scope: _scope,
        createKey: () => 'read-all-key',
        now: () => _now,
        personalization: const MemberPersonalization(
          ritualVoice: MemberRitualVoice.practical,
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      String? opened;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: NotificationsScreen(
            controller: controller,
            onOpenDestination: (destination) => opened = destination.location,
            onOpenPreferences: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Practical inbox'), findsOneWidget);
      expect(find.textContaining('In-app only'), findsOneWidget);
      expect(find.textContaining('device registration'), findsNothing);
      expect(find.textContaining('push token'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('notification-open-$_notificationId')),
        220,
        scrollable: _verticalScrollable,
      );
      await tester.drag(_verticalScrollable, const Offset(0, -160));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('notification-open-$_notificationId')),
      );
      await tester.pumpAndSettle();
      expect(opened, '/gospel/briefings');
      await controller.load();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('notifications-read-all')),
        280,
        scrollable: _verticalScrollable,
      );
      await tester.drag(_verticalScrollable, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('notifications-read-all'))).height,
        greaterThanOrEqualTo(48),
      );
      controller.prepareReadAll();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('notifications-confirm-read-all')),
        220,
        scrollable: _verticalScrollable,
      );
      expect(
        find.byKey(const Key('notifications-confirm-read-all')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('direct preference entry loads and failure offers retry', (
    tester,
  ) async {
    final controller = NotificationController(
      repository: _Notifications(),
      pendingStore: PendingCommandStore(storage: _Storage()),
      invalidationBus: InvalidationBus(),
      scope: _scope,
      createKey: () => 'read-all-key',
      now: () => _now,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationPreferencesScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preference-daily')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final failed = NotificationController(
      repository: _FailingNotifications(),
      pendingStore: PendingCommandStore(storage: _Storage()),
      invalidationBus: InvalidationBus(),
      scope: _scope,
      createKey: () => 'other-key',
      now: () => _now,
    );
    addTearDown(failed.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationPreferencesScreen(controller: failed),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notification-preferences-retry')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('failed briefing detail replaces spinner with recovery actions', (
    tester,
  ) async {
    final controller = BriefingController(
      repository: _FailingBriefings(),
      invalidationBus: InvalidationBus(),
      scope: _scope,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BriefingDetailScreen(
          briefingId: _briefingId,
          controller: controller,
          onOpenBriefings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('briefing-detail-retry')), findsOneWidget);
    expect(find.byKey(const Key('briefing-detail-list')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('protected read-all failure renders review and safe discard', (
    tester,
  ) async {
    final controller = NotificationController(
      repository: _RetryingNotifications(),
      pendingStore: PendingCommandStore(storage: _Storage()),
      invalidationBus: InvalidationBus(),
      scope: _scope,
      createKey: () => 'protected-read-all-key',
      now: () => _now,
    );
    addTearDown(controller.dispose);
    await controller.load();
    controller.prepareReadAll();
    await controller.confirmReadAll();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NotificationsScreen(
          controller: controller,
          onOpenDestination: (_) {},
          onOpenPreferences: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('notifications-review-protected')),
      250,
      scrollable: _verticalScrollable,
    );

    expect(
      find.byKey(const Key('notifications-review-protected')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notifications-discard-protected')),
      findsOneWidget,
    );
  });
}

final _verticalScrollable = find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

class _Briefings implements BriefingRepository {
  @override
  Future<RepositoryRead<BriefingPage>> load({
    BriefingType? type,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? cursor,
  }) async => RepositoryRead(
    value: BriefingPage(items: [_summary], hasMore: false),
    isStale: false,
    committedAt: _now,
  );

  @override
  Future<RepositoryRead<BriefingDetail>> get(String briefingId) async =>
      RepositoryRead(value: _detail, isStale: false, committedAt: _now);

  @override
  Future<DailyBriefingResult> daily(DateTime localDate) async =>
      DailyBriefingResult.available(_detail);

  @override
  Future<BriefingSummary> setRead(String briefingId, bool read) async =>
      _summary.copyWith(readAt: read ? _now : null, clearReadAt: !read);
}

class _FailingBriefings extends _Briefings {
  @override
  Future<RepositoryRead<BriefingDetail>> get(String briefingId) async =>
      throw const LoadFailure(LoadPhase.terminalFailure);
}

class _Notifications implements NotificationRepository {
  NotificationItem get item => NotificationItem(
    id: _notificationId,
    kind: NotificationKind.briefingReady,
    title: 'Your Ritual briefing is ready',
    body: 'Open Ritual to view your latest reflection.',
    destination: NotificationDestination.tryParse('/briefings'),
    scheduledAt: _now,
    readAt: null,
  );

  @override
  Future<RepositoryRead<NotificationPage>> load({
    NotificationReadFilter filter = NotificationReadFilter.all,
    String? cursor,
  }) async => RepositoryRead(
    value: NotificationPage(items: [item], hasMore: false),
    isStale: false,
    committedAt: _now,
  );

  @override
  Future<RepositoryRead<NotificationPreferences>> getPreferences() async =>
      RepositoryRead(value: _preferences, isStale: false, committedAt: _now);

  @override
  Future<NotificationPreferences> patchPreferences(
    NotificationPreferencesDraft draft,
    int expectedVersion,
  ) async => draft.toPreferences(version: expectedVersion + 1);

  @override
  Future<int> readAll(NotificationReadAll command) async => 1;

  @override
  Future<NotificationItem> setRead(String notificationId, bool read) async =>
      item;
}

class _FailingNotifications extends _Notifications {
  @override
  Future<RepositoryRead<NotificationPage>> load({
    NotificationReadFilter filter = NotificationReadFilter.all,
    String? cursor,
  }) async => throw const OfflineException();
}

class _RetryingNotifications extends _Notifications {
  @override
  Future<RepositoryRead<NotificationPage>> load({
    NotificationReadFilter filter = NotificationReadFilter.all,
    String? cursor,
  }) async => RepositoryRead(
    value: const NotificationPage(items: [], hasMore: false),
    isStale: false,
    committedAt: _now,
  );

  @override
  Future<int> readAll(NotificationReadAll command) async =>
      throw const LoadFailure(LoadPhase.retryableFailure);
}

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
const _briefingId = '018f3c2a-4b67-4a89-8abc-123456789001';
const _notificationId = '018f3c2a-4b67-4a89-8abc-123456789011';
const _preferences = NotificationPreferences(
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
final _summary = BriefingSummary(
  id: _briefingId,
  type: BriefingType.daily,
  periodStart: DateTime.utc(2026, 8, 25),
  periodEnd: DateTime.utc(2026, 8, 25),
  generatedAt: _now,
  generation: 1,
  sourceSequence: 14,
  readAt: null,
);
final _detail = BriefingDetail(
  summary: _summary,
  sections: const [
    BriefingSummarySection(
      ordinal: 1,
      sourceSequence: 14,
      disclosure:
          'Generated from recorded Demo activity; not financial advice.',
    ),
  ],
);
