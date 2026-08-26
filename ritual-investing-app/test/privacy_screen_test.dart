import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/privacy/application/privacy_controller.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/privacy/domain/model.dart';
import 'package:ritual_investing_app/features/privacy/presentation/privacy_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('privacy controls stay usable at 2x in ${brightness.name}', (
      tester,
    ) async {
      final controller = _controller(_UiRepository());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: PrivacySettingsScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy and data'), findsOneWidget);
      expect(find.textContaining('one-time'), findsOneWidget);
      expect(find.textContaining('token'), findsNothing);
      expect(find.textContaining('http'), findsNothing);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Demo reset requires review before the generated command', (
    tester,
  ) async {
    final repository = _UiRepository();
    final controller = _controller(repository);
    await tester.pumpWidget(
      MaterialApp(home: DemoResetScreen(controller: controller)),
    );

    await tester.tap(find.byKey(const Key('demo-reset-review')));
    await tester.pump();
    expect(repository.resetCalls, 0);
    expect(find.textContaining('cannot be undone'), findsOneWidget);

    await tester.tap(find.byKey(const Key('demo-reset-confirm')));
    await tester.pumpAndSettle();
    expect(repository.resetCalls, 1);
  });

  testWidgets('completed export without a fresh grant is never called ready', (
    tester,
  ) async {
    final repository = _UiRepository(
      restoredExport: PrivacyExport(
        id: '018f3c2a-4b67-7a89-8abc-123456789020',
        status: PrivacyExportStatus.completed,
        format: PrivacyExportFormat.zip,
        hasDownloadGrant: false,
        expiresAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySettingsScreen(controller: _controller(repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Export status: completed · download unavailable'),
      findsOneWidget,
    );
    expect(find.text('Export status: ready'), findsNothing);
    expect(find.byKey(const Key('privacy-export-share')), findsNothing);
    expect(find.byKey(const Key('privacy-export-refresh')), findsOneWidget);
  });

  testWidgets('unsupported export fails closed with saved-command review', (
    tester,
  ) async {
    final repository = _UiRepository(
      requestError: const PrivacyFailure(PrivacyFailureKind.terminal),
    );
    final controller = _controller(repository);
    await tester.pumpWidget(
      MaterialApp(home: PrivacySettingsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('privacy-export-request')));
    await tester.pumpAndSettle();

    expect(controller.phase, PrivacyPhase.terminalFailure);
    expect(find.byKey(const Key('privacy-export-request')), findsNothing);
    expect(find.text('Review saved export request'), findsOneWidget);
    expect(find.byKey(const Key('privacy-deletion-review')), findsNothing);
  });

  testWidgets('terminal export stops polling and never offers a stale share', (
    tester,
  ) async {
    final repository = _UiRepository(
      restoredExport: PrivacyExport(
        id: '018f3c2a-4b67-7a89-8abc-123456789020',
        status: PrivacyExportStatus.failed,
        format: PrivacyExportFormat.zip,
        hasDownloadGrant: false,
        expiresAt: DateTime.utc(2026, 9, 1),
        failureCode: 'archive_failed',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySettingsScreen(controller: _controller(repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Export status: failed'), findsOneWidget);
    expect(find.byKey(const Key('privacy-export-request')), findsOneWidget);
    expect(find.byKey(const Key('privacy-export-refresh')), findsNothing);
    expect(find.byKey(const Key('privacy-export-share')), findsNothing);
  });

  testWidgets('local share failure requires refresh and hides stale share', (
    tester,
  ) async {
    final repository = _UiRepository(
      restoredExport: PrivacyExport(
        id: '018f3c2a-4b67-7a89-8abc-123456789020',
        status: PrivacyExportStatus.completed,
        format: PrivacyExportFormat.zip,
        hasDownloadGrant: true,
        expiresAt: DateTime.utc(2026, 9, 1),
      ),
      shareError: const PrivacyFailure(PrivacyFailureKind.retryable),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySettingsScreen(controller: _controller(repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('privacy-export-share')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('privacy-export-refresh')), findsOneWidget);
    expect(find.byKey(const Key('privacy-export-share')), findsNothing);
    expect(find.textContaining('temporarily unavailable'), findsOneWidget);
  });

  testWidgets('direct reset route restores the same command for review', (
    tester,
  ) async {
    final storage = _Storage();
    final interrupted = _UiRepository(
      resetError: const AmbiguousPrivacyMutation(),
    );
    final first = _controller(interrupted, storage: storage);
    first.prepareDemoReset();
    await first.confirmDemoReset(seedVersion: 1);
    expect(first.hasProtectedReset, isTrue);

    final resumed = _UiRepository();
    final second = _controller(resumed, storage: storage);
    await tester.pumpWidget(
      MaterialApp(home: DemoResetScreen(controller: second)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review saved Demo reset'), findsOneWidget);
    expect(find.byKey(const Key('demo-reset-confirm')), findsNothing);
    expect(resumed.resetCalls, 0);
    await tester.tap(find.byKey(const Key('demo-reset-restored-review')));
    await tester.pump();
    expect(find.byKey(const Key('demo-reset-confirm')), findsOneWidget);
    expect(resumed.resetCalls, 0);
  });

  testWidgets('reset route redirects a saved export back to Privacy', (
    tester,
  ) async {
    final repository = _UiRepository(
      requestError: const PrivacyFailure(PrivacyFailureKind.terminal),
    );
    final controller = _controller(repository);
    await controller.requestExport();
    var openedPrivacy = false;

    await tester.pumpWidget(
      MaterialApp(
        home: DemoResetScreen(
          controller: controller,
          onOpenPrivacy: () => openedPrivacy = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('different privacy action'), findsOneWidget);
    expect(find.byKey(const Key('demo-reset-restored-review')), findsNothing);
    expect(find.byKey(const Key('demo-reset-review')), findsNothing);
    await tester.tap(find.byKey(const Key('demo-reset-open-privacy')));
    expect(openedPrivacy, isTrue);
  });

  testWidgets('protected deletion recovery never renders export controls', (
    tester,
  ) async {
    final repository = _UiRepository(
      restoredExport: PrivacyExport(
        id: '018f3c2a-4b67-7a89-8abc-123456789020',
        status: PrivacyExportStatus.completed,
        format: PrivacyExportFormat.zip,
        hasDownloadGrant: true,
      ),
      deletionError: const PrivacyFailure(PrivacyFailureKind.retryable),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySettingsScreen(controller: _controller(repository)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('privacy-deletion-review')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('privacy-deletion-review')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('privacy-deletion-confirm')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byKey(const Key('privacy-deletion-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Review saved account deletion'), findsOneWidget);
    expect(find.byKey(const Key('privacy-export-refresh')), findsNothing);
    expect(find.byKey(const Key('privacy-export-share')), findsNothing);
  });

  testWidgets('privacy route sends a saved reset to the reset screen', (
    tester,
  ) async {
    final storage = _Storage();
    final first = _controller(
      _UiRepository(resetError: const AmbiguousPrivacyMutation()),
      storage: storage,
    );
    first.prepareDemoReset();
    await first.confirmDemoReset(seedVersion: 1);
    final resumed = _controller(_UiRepository(), storage: storage);
    var openedReset = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PrivacySettingsScreen(
          controller: resumed,
          onOpenDemoReset: () => openedReset = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open saved Demo reset'), findsOneWidget);
    expect(find.byKey(const Key('privacy-restored-review')), findsNothing);
    await tester.tap(find.byKey(const Key('privacy-open-demo-reset')));
    expect(openedReset, isTrue);
  });
}

PrivacyController _controller(
  _UiRepository repository, {
  ProtectedStorage? storage,
}) => PrivacyController(
  repository: repository,
  pendingStore: PendingCommandStore(storage: storage ?? _Storage()),
  scope: const CacheScope(accountId: 'account-a', resetGeneration: 4),
  createKey: () => 'privacy-ui-command-00001',
  reauthenticate: () async {},
  onDeletionAccepted: () async {},
  onResetAccepted: (_) async {},
);

class _UiRepository implements PrivacyRepository {
  _UiRepository({
    this.restoredExport,
    this.requestError,
    this.shareError,
    this.resetError,
    this.deletionError,
  });

  final PrivacyExport? restoredExport;
  final Object? requestError;
  final Object? shareError;
  final Object? resetError;
  final Object? deletionError;
  int resetCalls = 0;

  @override
  Future<void> clearStaleLocalFiles() async {}

  @override
  Future<String?> restoreExportId() async => restoredExport?.id;
  @override
  Future<void> rememberExportId(String requestId) async {}
  @override
  Future<void> forgetExportId(String requestId) async {}
  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) async {
    if (requestError case final error?) throw error;
    return PrivacyExport(
      id: '018f3c2a-4b67-7a89-8abc-123456789020',
      status: PrivacyExportStatus.queued,
      format: PrivacyExportFormat.zip,
      hasDownloadGrant: false,
      expiresAt: DateTime.utc(2026, 9, 1),
    );
  }

  @override
  Future<PrivacyExport> getExport(String requestId) async =>
      restoredExport ?? (throw UnimplementedError());
  @override
  Future<void> downloadAndShare(String requestId) async {
    if (shareError case final error?) throw error;
  }

  @override
  Future<PrivacyDeletionReceipt> requestDeletion(String idempotencyKey) async {
    if (deletionError case final error?) throw error;
    throw UnimplementedError();
  }

  @override
  Future<bool> accountInactive() async => false;
  @override
  Future<DemoResetReceipt> resetDemo(
    int seedVersion,
    String idempotencyKey,
  ) async {
    resetCalls += 1;
    if (resetError case final error?) throw error;
    return const DemoResetReceipt(
      resetGeneration: 5,
      defaultPortfolioId: '018f3c2a-4b67-7a89-8abc-123456789099',
    );
  }

  @override
  Future<void> cancelAndClearLocal() async {}
}

class _Storage implements ProtectedStorage {
  final Map<String, String> values = {};
  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}
