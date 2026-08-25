import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/privacy/application/privacy_controller.dart';
import 'package:ritual_investing_app/features/privacy/data/repository.dart';
import 'package:ritual_investing_app/features/privacy/domain/model.dart';

void main() {
  test('relaunch resumes the exact export, steps up, and shares only after a fresh status', () async {
    final repository = _FakePrivacyRepository()
      ..restoredExportId = _exportId
      ..getResults.addAll([
        const RecentAuthRequired(),
        _export(PrivacyExportStatus.completed),
        _export(PrivacyExportStatus.completed),
      ]);
    var recentAuthCount = 0;
    final controller = _controller(
      repository,
      reauthenticate: () async {
        recentAuthCount += 1;
      },
    );

    await controller.load();
    expect(controller.phase, PrivacyPhase.downloadReady);
    expect(recentAuthCount, 1);
    expect(repository.requestIds, [_exportId, _exportId]);

    await controller.downloadAndShare();
    expect(controller.phase, PrivacyPhase.shared);
    expect(repository.requestIds, [_exportId, _exportId, _exportId]);
    expect(repository.sharedIds, [_exportId]);
    expect(repository.forgottenExportIds, [_exportId]);
    expect(repository.staleFileClearCount, 1);
  });

  test(
    'relaunch removes orphaned files without forgetting the export',
    () async {
      final repository = _FakePrivacyRepository()
        ..restoredExportId = _exportId
        ..getResults.add(_export(PrivacyExportStatus.processing));
      final controller = _controller(repository);

      await controller.load();

      expect(repository.staleFileClearCount, 1);
      expect(repository.restoredExportId, _exportId);
      expect(repository.forgottenExportIds, isEmpty);
      expect(controller.phase, PrivacyPhase.exportPending);
    },
  );

  test(
    'recent-auth cancellation is recoverable and never a schema error',
    () async {
      final repository = _FakePrivacyRepository()
        ..exportError = const RecentAuthRequired();
      final controller = _controller(
        repository,
        reauthenticate: () async => throw const RecentAuthCancelled(),
      );

      await controller.requestExport();

      expect(controller.phase, PrivacyPhase.forbidden);
      expect(controller.message, contains('authentication was cancelled'));
      expect(controller.message, isNot(contains('not supported')));
      expect(controller.hasProtectedCommand, isTrue);
      expect(repository.exportKeys, hasLength(1));
    },
  );

  test(
    'cancelled status step-up keeps the restored export resumable',
    () async {
      final repository = _FakePrivacyRepository()
        ..restoredExportId = _exportId
        ..getResults.add(const RecentAuthRequired());
      final controller = _controller(
        repository,
        reauthenticate: () async => throw const RecentAuthCancelled(),
      );

      await controller.load();

      expect(controller.phase, PrivacyPhase.forbidden);
      expect(controller.export, isNull);
      expect(controller.canRefreshExport, isTrue);
    },
  );

  test(
    'download resumes the exact action after recent authentication',
    () async {
      final repository = _FakePrivacyRepository()
        ..restoredExportId = _exportId
        ..getResults.addAll([
          _export(PrivacyExportStatus.completed),
          _export(PrivacyExportStatus.completed),
        ])
        ..shareResults.addAll([const RecentAuthRequired(), null]);
      var recentAuthCount = 0;
      final controller = _controller(
        repository,
        reauthenticate: () async => recentAuthCount += 1,
      );

      await controller.load();
      await controller.downloadAndShare();

      expect(controller.phase, PrivacyPhase.shared);
      expect(recentAuthCount, 1);
      expect(repository.sharedIds, [_exportId, _exportId]);
      expect(repository.forgottenExportIds, [_exportId]);
    },
  );

  test('local share failure keeps request and requires fresh status', () async {
    final repository = _FakePrivacyRepository()
      ..restoredExportId = _exportId
      ..getResults.addAll([
        _export(PrivacyExportStatus.completed),
        _export(PrivacyExportStatus.completed),
      ])
      ..shareResults.add(const PrivacyFailure(PrivacyFailureKind.retryable));
    final controller = _controller(repository);

    await controller.load();
    await controller.downloadAndShare();

    expect(controller.phase, PrivacyPhase.retryableFailure);
    expect(controller.export?.id, _exportId);
    expect(repository.restoredExportId, _exportId);
    expect(repository.forgottenExportIds, isEmpty);
  });

  test(
    'terminal export state survives relaunch without polling or download',
    () async {
      final repository = _FakePrivacyRepository()
        ..restoredExportId = _exportId
        ..getResults.add(
          _export(PrivacyExportStatus.failed, failureCode: 'archive_failed'),
        );
      final controller = _controller(repository);

      await controller.load();

      expect(controller.phase, PrivacyPhase.exportFailed);
      expect(controller.export?.failureCode, 'archive_failed');
      expect(repository.sharedIds, isEmpty);
    },
  );

  test(
    'ambiguous deletion followed by account_inactive is terminal accepted once',
    () async {
      final repository = _FakePrivacyRepository()
        ..deletionError = const AmbiguousPrivacyMutation()
        ..inactive = true;
      var accepted = 0;
      final controller = _controller(
        repository,
        onDeletionAccepted: () async {
          accepted += 1;
        },
      );

      controller.prepareDeletion();
      await controller.confirmDeletion();

      expect(controller.phase, PrivacyPhase.deletionAccepted);
      expect(repository.deletionKeys, hasLength(1));
      expect(repository.inactiveChecks, 1);
      expect(accepted, 1);
      await controller.confirmDeletion();
      expect(repository.deletionKeys, hasLength(1));
      expect(accepted, 1);
    },
  );

  test(
    'protected deletion failure never exposes export refresh authority',
    () async {
      final repository = _FakePrivacyRepository()
        ..restoredExportId = _exportId
        ..getResults.add(_export(PrivacyExportStatus.completed))
        ..deletionError = const PrivacyFailure(PrivacyFailureKind.retryable);
      final controller = _controller(repository);
      await controller.load();

      controller.prepareDeletion();
      await controller.confirmDeletion();

      expect(controller.phase, PrivacyPhase.retryableFailure);
      expect(controller.hasProtectedDeletion, isTrue);
      expect(controller.canRefreshExport, isFalse);
    },
  );

  test(
    'protected replacement export hides refresh for an older terminal ID',
    () async {
      final repository = _FakePrivacyRepository()
        ..restoredExportId = _exportId
        ..getResults.add(
          _export(PrivacyExportStatus.failed, failureCode: 'archive_failed'),
        )
        ..exportError = const PrivacyFailure(PrivacyFailureKind.retryable);
      final controller = _controller(repository);
      await controller.load();

      await controller.requestExport();

      expect(controller.phase, PrivacyPhase.retryableFailure);
      expect(controller.hasProtectedExport, isTrue);
      expect(controller.canRefreshExport, isFalse);
    },
  );

  test(
    'Demo reset accepts only a newer generation and transfers authority',
    () async {
      final repository = _FakePrivacyRepository()
        ..resetReceipt = const DemoResetReceipt(
          resetGeneration: 8,
          defaultPortfolioId: '018f3c2a-4b67-7a89-8abc-123456789099',
        );
      final transferred = <int>[];
      final controller = _controller(
        repository,
        scope: const CacheScope(accountId: 'account-a', resetGeneration: 7),
        onResetAccepted: (generation) async => transferred.add(generation),
      );

      controller.prepareDemoReset();
      await controller.confirmDemoReset(seedVersion: 1);

      expect(controller.phase, PrivacyPhase.resetAccepted);
      expect(repository.resetSeedVersions, [1]);
      expect(transferred, [8]);
    },
  );

  test(
    'deactivation cancels old-account work and clears local privacy state',
    () async {
      final repository = _FakePrivacyRepository();
      final controller = _controller(repository);

      await controller.deactivate();

      expect(repository.cancelled, isTrue);
      expect(repository.localClearCount, 1);
      await controller.requestExport();
      expect(repository.exportKeys, isEmpty);
    },
  );

  test(
    'active personalization changes explanation framing, never authority',
    () {
      final controller = _controller(
        _FakePrivacyRepository(),
        personalization: const MemberPersonalization(
          explanationDepth: MemberExplanationDepth.beginner,
          ritualVoice: MemberRitualVoice.practical,
        ),
      );

      expect(controller.framingLabel, 'Practical · step-by-step explanation');
    },
  );

  test(
    'deactivation fences delayed export deletion and reset responses',
    () async {
      final exportRepository = _FakePrivacyRepository()
        ..exportCompleter = Completer<PrivacyExport>();
      final exportController = _controller(exportRepository);
      final exportCall = exportController.requestExport();
      await _waitFor(() => exportRepository.exportKeys.isNotEmpty);
      await exportController.deactivate();
      exportRepository.exportCompleter!.complete(
        _export(PrivacyExportStatus.queued),
      );
      await exportCall;
      expect(exportRepository.rememberedExportIds, isEmpty);
      expect(exportController.export, isNull);

      final deletionRepository = _FakePrivacyRepository()
        ..deletionCompleter = Completer<PrivacyDeletionReceipt>();
      var deletionCallbacks = 0;
      final deletionController = _controller(
        deletionRepository,
        onDeletionAccepted: () async => deletionCallbacks += 1,
      );
      deletionController.prepareDeletion();
      final deletionCall = deletionController.confirmDeletion();
      await _waitFor(() => deletionRepository.deletionKeys.isNotEmpty);
      await deletionController.deactivate();
      deletionRepository.deletionCompleter!.complete(_deletionReceipt());
      await deletionCall;
      expect(deletionCallbacks, 0);

      final resetRepository = _FakePrivacyRepository()
        ..resetCompleter = Completer<DemoResetReceipt>();
      final resetCallbacks = <int>[];
      final resetController = _controller(
        resetRepository,
        onResetAccepted: (generation) async => resetCallbacks.add(generation),
      );
      resetController.prepareDemoReset();
      final resetCall = resetController.confirmDemoReset(seedVersion: 1);
      await _waitFor(() => resetRepository.resetSeedVersions.isNotEmpty);
      await resetController.deactivate();
      resetRepository.resetCompleter!.complete(
        const DemoResetReceipt(
          resetGeneration: 5,
          defaultPortfolioId: '018f3c2a-4b67-7a89-8abc-123456789099',
        ),
      );
      await resetCall;
      expect(resetCallbacks, isEmpty);
    },
  );

  test(
    'deactivation fences a delayed restored-export status response',
    () async {
      final repository = _FakePrivacyRepository()
        ..restoredExportId = _exportId
        ..getCompleter = Completer<PrivacyExport>();
      final controller = _controller(repository);

      final load = controller.load();
      await _waitFor(() => repository.requestIds.isNotEmpty);
      await controller.deactivate();
      repository.getCompleter!.complete(_export(PrivacyExportStatus.completed));
      await load;

      expect(controller.export, isNull);
      expect(repository.rememberedExportIds, isEmpty);
    },
  );

  test(
    'deactivation during journal clear cannot invoke deletion logout',
    () async {
      final storage = _MemoryStorage()..delayDeletes = true;
      final repository = _FakePrivacyRepository();
      var deletionCallbacks = 0;
      final controller = _controller(
        repository,
        storage: storage,
        onDeletionAccepted: () async => deletionCallbacks += 1,
      );
      controller.prepareDeletion();

      final confirmation = controller.confirmDeletion();
      await storage.deleteStarted.future;
      final deactivation = controller.deactivate();
      storage.releaseDeletes.complete();
      await Future.wait([confirmation, deactivation]);

      expect(deletionCallbacks, 0);
      expect(controller.deletionReceipt, isNull);
    },
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

PrivacyDeletionReceipt _deletionReceipt() => PrivacyDeletionReceipt(
  requestId: '018f3c2a-4b67-7a89-8abc-123456789021',
  tombstoneId: '018f3c2a-4b67-7a89-8abc-123456789022',
  effectiveAt: DateTime.utc(2026, 8, 25),
  purgeBy: DateTime.utc(2026, 9, 24),
  purgeGeneration: 1,
);

PrivacyController _controller(
  _FakePrivacyRepository repository, {
  CacheScope scope = const CacheScope(
    accountId: 'account-a',
    resetGeneration: 4,
  ),
  Future<void> Function()? reauthenticate,
  Future<void> Function()? onDeletionAccepted,
  Future<void> Function(int generation)? onResetAccepted,
  MemberPersonalization personalization = const MemberPersonalization(),
  ProtectedStorage? storage,
}) => PrivacyController(
  repository: repository,
  pendingStore: PendingCommandStore(storage: storage ?? _MemoryStorage()),
  scope: scope,
  createKey: () => 'privacy-command-key-00000001',
  reauthenticate: reauthenticate ?? () async {},
  onDeletionAccepted: onDeletionAccepted ?? () async {},
  onResetAccepted: onResetAccepted ?? (_) async {},
  personalization: personalization,
);

PrivacyExport _export(PrivacyExportStatus status, {String? failureCode}) =>
    PrivacyExport(
      id: _exportId,
      status: status,
      format: PrivacyExportFormat.zip,
      failureCode: failureCode,
      snapshotAt: DateTime.utc(2026, 8, 25),
      completedAt: status == PrivacyExportStatus.completed
          ? DateTime.utc(2026, 8, 25, 0, 1)
          : null,
      expiresAt: DateTime.utc(2026, 9, 1),
      hasDownloadGrant: status == PrivacyExportStatus.completed,
    );

class _FakePrivacyRepository implements PrivacyRepository {
  String? restoredExportId;
  final List<Object> getResults = [];
  final List<String> requestIds = [];
  final List<String> sharedIds = [];
  final List<Object?> shareResults = [];
  final List<String> forgottenExportIds = [];
  final List<String> rememberedExportIds = [];
  final List<String> exportKeys = [];
  final List<String> deletionKeys = [];
  final List<int> resetSeedVersions = [];
  Object? deletionError;
  bool inactive = false;
  int inactiveChecks = 0;
  DemoResetReceipt? resetReceipt;
  Object? exportError;
  Completer<PrivacyExport>? exportCompleter;
  Completer<PrivacyExport>? getCompleter;
  Completer<PrivacyDeletionReceipt>? deletionCompleter;
  Completer<DemoResetReceipt>? resetCompleter;
  bool cancelled = false;
  int localClearCount = 0;
  int staleFileClearCount = 0;

  @override
  Future<void> clearStaleLocalFiles() async {
    staleFileClearCount += 1;
  }

  @override
  Future<String?> restoreExportId() async => restoredExportId;

  @override
  Future<void> rememberExportId(String requestId) async {
    rememberedExportIds.add(requestId);
    restoredExportId = requestId;
  }

  @override
  Future<void> forgetExportId(String requestId) async {
    forgottenExportIds.add(requestId);
    if (restoredExportId == requestId) restoredExportId = null;
  }

  @override
  Future<PrivacyExport> requestExport(String idempotencyKey) async {
    exportKeys.add(idempotencyKey);
    if (exportError case final error?) throw error;
    if (exportCompleter case final completer?) return completer.future;
    return _export(PrivacyExportStatus.queued);
  }

  @override
  Future<PrivacyExport> getExport(String requestId) async {
    requestIds.add(requestId);
    if (getCompleter case final completer?) return completer.future;
    final result = getResults.removeAt(0);
    if (result is Exception) throw result;
    return result as PrivacyExport;
  }

  @override
  Future<void> downloadAndShare(String requestId) async {
    sharedIds.add(requestId);
    if (shareResults.isNotEmpty) {
      final result = shareResults.removeAt(0);
      if (result case final error?) throw error;
    }
  }

  @override
  Future<PrivacyDeletionReceipt> requestDeletion(String idempotencyKey) async {
    deletionKeys.add(idempotencyKey);
    if (deletionError case final error?) throw error;
    if (deletionCompleter case final completer?) return completer.future;
    return _deletionReceipt();
  }

  @override
  Future<bool> accountInactive() async {
    inactiveChecks += 1;
    return inactive;
  }

  @override
  Future<DemoResetReceipt> resetDemo(
    int seedVersion,
    String idempotencyKey,
  ) async {
    resetSeedVersions.add(seedVersion);
    if (resetCompleter case final completer?) return completer.future;
    return resetReceipt!;
  }

  @override
  Future<void> cancelAndClearLocal() async {
    cancelled = true;
    localClearCount += 1;
  }
}

class _MemoryStorage implements ProtectedStorage {
  final Map<String, String> values = {};
  bool delayDeletes = false;
  final Completer<void> deleteStarted = Completer<void>();
  final Completer<void> releaseDeletes = Completer<void>();

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async {
    if (delayDeletes) {
      if (!deleteStarted.isCompleted) deleteStarted.complete();
      await releaseDeletes.future;
    }
    values.remove(key);
  }
}

const _exportId = '018f3c2a-4b67-7a89-8abc-123456789020';
