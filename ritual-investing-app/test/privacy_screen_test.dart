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
  authorizeDeletion: () async => 'delete_step_up_receipt_000000000001',
  onDeletionAccepted: () async {},
);

class _UiRepository implements PrivacyRepository {
  _UiRepository({
    this.restoredExport,
    this.requestError,
    this.shareError,
    this.deletionError,
  });

  final PrivacyExport? restoredExport;
  final Object? requestError;
  final Object? shareError;
  final Object? deletionError;

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
  Future<PrivacyDeletionReceipt> requestDeletion(
    String idempotencyKey,
    String stepUpReceipt,
  ) async {
    if (deletionError case final error?) throw error;
    throw UnimplementedError();
  }

  @override
  Future<bool> accountInactive() async => false;
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
