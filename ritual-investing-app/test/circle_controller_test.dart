import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/circles/application/controller.dart';
import 'package:ritual_investing_app/features/circles/data/repository.dart';
import 'package:ritual_investing_app/features/circles/domain/model.dart';
import 'package:ritual_investing_app/features/circles/presentation/circle_template_screen.dart';
import 'package:ritual_investing_app/features/circles/presentation/private_circle_detail_screen.dart';
import 'package:ritual_investing_app/features/circles/presentation/private_circles_screen.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';

void main() {
  test(
    'lost copy response retries one key and creates one private Circle',
    () async {
      final service = _CircleService(loseFirstCopyResponse: true);
      final controller = CircleListController(
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
        createKey: () => 'copy-command-key',
      );

      await controller.copyTemplate(_templateId, title: 'My Soft Power Circle');
      expect(controller.mutationPhase, CircleMutationPhase.retryableFailure);
      expect(controller.pendingCommandKey, 'copy-command-key');

      await controller.retryPending();

      expect(service.copyKeys, ['copy-command-key', 'copy-command-key']);
      expect(service.createdCircles, 1);
      expect(controller.mutationPhase, CircleMutationPhase.committed);
      expect(controller.lastCreated!.private, isTrue);
      expect(controller.lastCreated!.sourceTemplateId, _templateId);
    },
  );

  test(
    'concurrent create taps share one command and one idempotency key',
    () async {
      final service = _CircleService(delayCreateResponse: true);
      var keyCounter = 0;
      final controller = CircleListController(
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
        createKey: () => 'create-command-${++keyCounter}',
      );

      final first = controller.create(title: 'Private research');
      final second = controller.create(title: 'Private research');
      await Future.wait([first, second]);

      expect(service.createKeys, ['create-command-1']);
      expect(service.createdCircles, 1);
      expect(keyCounter, 1);
    },
  );

  test(
    'stale edit preserves draft, reloads authority, and requests review',
    () async {
      final service = _CircleService(conflictFirstPatch: true);
      final controller = CircleDetailController(
        circleId: _circleId,
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();
      controller.updateDraft(
        title: 'My patient research',
        description: 'Private notes',
      );

      await controller.saveDraft();

      expect(controller.state.phase, LoadPhase.conflict);
      expect(controller.state.value!.version, 3);
      expect(controller.state.value!.title, 'Changed on another device');
      expect(controller.draft.title, 'My patient research');
      expect(controller.draft.description, 'Private notes');
      expect(controller.requiresConflictReview, isTrue);

      await controller.reviewAndRetry();

      expect(controller.state.phase, LoadPhase.ready);
      expect(controller.state.value!.version, 4);
      expect(controller.state.value!.title, 'My patient research');
      expect(controller.requiresConflictReview, isFalse);
    },
  );

  test(
    'failed conflict authority reload preserves draft and conflict intent',
    () async {
      final service = _CircleService(
        conflictFirstPatch: true,
        conflictRefetchFailure: const OfflineException(),
      );
      final controller = CircleDetailController(
        circleId: _circleId,
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();
      controller.updateDraft(title: 'Keep my patient draft');

      await controller.saveDraft();

      expect(controller.state.phase, LoadPhase.retryableFailure);
      expect(controller.draft.title, 'Keep my patient draft');
      expect(controller.hasPendingConflictResolution, isTrue);
      expect(controller.requiresConflictReview, isFalse);

      await controller.retryLoad();

      expect(controller.state.phase, LoadPhase.conflict);
      expect(controller.state.value!.title, 'Changed on another device');
      expect(controller.draft.title, 'Keep my patient draft');
      expect(controller.requiresConflictReview, isTrue);
    },
  );

  test(
    'terminal conflict refetch failure is contained without losing intent',
    () async {
      final service = _CircleService(
        conflictFirstArchive: true,
        conflictRefetchFailure: const LoadFailure(LoadPhase.terminalFailure),
      );
      final controller = CircleDetailController(
        circleId: _circleId,
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();

      await controller.archive();

      expect(controller.state.phase, LoadPhase.terminalFailure);
      expect(controller.state.value!.isArchived, isFalse);
      expect(controller.hasPendingConflictResolution, isTrue);
    },
  );

  test('stale reorder preserves requested order until review', () async {
    final service = _CircleService(conflictFirstReorder: true);
    final controller = CircleDetailController(
      circleId: _circleId,
      repository: CircleRepository(service: service, cache: MemoryReadCache()),
    );
    await controller.load();
    controller.reorderDraft([_assetB, _assetA]);

    await controller.saveAssetOrder();

    expect(controller.state.phase, LoadPhase.conflict);
    expect(controller.draft.assets.map((asset) => asset.assetId), [
      _assetB,
      _assetA,
    ]);
    expect(controller.state.value!.assets.first.assetId, _assetA);
    expect(controller.requiresConflictReview, isTrue);
  });

  test('archive refreshes authoritative private state', () async {
    final service = _CircleService();
    final controller = CircleDetailController(
      circleId: _circleId,
      repository: CircleRepository(service: service, cache: MemoryReadCache()),
    );
    await controller.load();

    await controller.archive();

    expect(service.archiveVersions, [2]);
    expect(controller.state.value!.archivedAt, DateTime.utc(2026, 8, 25, 15));
    expect(controller.state.value!.version, 3);
  });

  test('ambiguous asset add/update and removal reconcile authority', () async {
    final service = _CircleService(
      loseFirstPutResponse: true,
      loseFirstRemoveResponse: true,
    );
    final controller = CircleDetailController(
      circleId: _circleId,
      repository: CircleRepository(service: service, cache: MemoryReadCache()),
    );
    await controller.load();

    await controller.putAsset(
      const CircleAsset(
        assetId: _assetA,
        ordinal: 1,
        note: 'Review quarterly',
        weightBps: 5500,
      ),
    );

    expect(controller.state.value!.assets.first.note, 'Review quarterly');
    expect(controller.state.value!.version, 3);

    await controller.removeAsset(_assetB);

    expect(controller.state.value!.assets.map((asset) => asset.assetId), [
      _assetA,
    ]);
    expect(controller.state.value!.version, 4);
  });

  test(
    'archive conflict reloads authority and can retry after review',
    () async {
      final service = _CircleService(conflictFirstArchive: true);
      final controller = CircleDetailController(
        circleId: _circleId,
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();

      await controller.archive();

      expect(controller.state.phase, LoadPhase.conflict);
      expect(controller.state.value!.version, 3);
      expect(controller.requiresConflictReview, isTrue);

      await controller.reviewAndRetry();

      expect(controller.state.value!.isArchived, isTrue);
      expect(controller.state.value!.version, 4);
      expect(controller.requiresConflictReview, isFalse);
    },
  );

  test('invalid Circle input never reaches the mutation service', () async {
    final service = _CircleService();
    final list = CircleListController(
      repository: CircleRepository(service: service, cache: MemoryReadCache()),
      createKey: () => 'unused-key',
    );

    await list.create(title: '   ');

    expect(list.validationMessage, 'Give your private Circle a title.');
    expect(service.createKeys, isEmpty);
    final detail = CircleDetailController(
      circleId: _circleId,
      repository: CircleRepository(service: service, cache: MemoryReadCache()),
    );
    await detail.load();
    await detail.putAsset(
      const CircleAsset(
        assetId: _assetA,
        ordinal: 1,
        note: null,
        weightBps: 10001,
      ),
    );
    expect(detail.validationMessage, 'Weight must be from 0% to 100%.');
    expect(service.putCalls, 0);
  });

  test(
    'direct asset mutations reject a 51st asset and duplicate ordinal',
    () async {
      final fullAssets = [
        for (var index = 0; index < 50; index++)
          CircleAsset(
            assetId: _uuidFor(index + 1000),
            ordinal: index + 1,
            note: null,
            weightBps: null,
          ),
      ];
      final fullService = _CircleService(initialAssets: fullAssets);
      final full = CircleDetailController(
        circleId: _circleId,
        repository: CircleRepository(
          service: fullService,
          cache: MemoryReadCache(),
        ),
      );
      await full.load();

      await full.putAsset(
        CircleAsset(
          assetId: _uuidFor(2000),
          ordinal: 50,
          note: null,
          weightBps: null,
        ),
      );

      expect(full.validationMessage, 'A Circle can contain up to 50 assets.');
      expect(fullService.putCalls, 0);

      final service = _CircleService();
      final detail = CircleDetailController(
        circleId: _circleId,
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await detail.load();
      await detail.putAsset(
        CircleAsset(
          assetId: _uuidFor(2001),
          ordinal: 2,
          note: null,
          weightBps: null,
        ),
      );
      expect(detail.validationMessage, 'Each asset needs a unique position.');
      expect(service.putCalls, 0);

      await detail.putAsset(
        const CircleAsset(
          assetId: _assetA,
          ordinal: 1,
          note: 'An existing asset remains editable.',
          weightBps: 6000,
        ),
      );
      expect(service.putCalls, 1);
      expect(detail.state.value!.assets.first.note, isNotNull);
    },
  );

  test('rapid Circle detail saves share one in-flight mutation', () async {
    final patchGate = Completer<void>();
    final service = _CircleService(patchGate: patchGate);
    final controller = CircleDetailController(
      circleId: _circleId,
      repository: CircleRepository(service: service, cache: MemoryReadCache()),
    );
    await controller.load();
    controller.updateDraft(title: 'One serialized edit');

    final first = controller.saveDraft();
    final second = controller.saveDraft();

    expect(controller.isMutating, isTrue);
    expect(service.patchCalls, 1);
    patchGate.complete();
    await Future.wait([first, second]);
    expect(service.patchCalls, 1);
    expect(controller.isMutating, isFalse);
  });

  test(
    'ambiguous Circle-template save reconciles from authoritative detail',
    () async {
      final service = _CircleService(loseFirstTemplateSaveResponse: true);
      final controller = CircleTemplateController(
        templateId: _templateId,
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await controller.load();

      await controller.toggleSaved();

      expect(service.templateSaveCalls, 1);
      expect(service.templateSaved, isTrue);
      expect(controller.state.value!.saved, isTrue);
      expect(controller.savePhase, CircleTemplateSavePhase.reconciled);
    },
  );

  test(
    'Circle-template save hydrates in a fresh controller and cache',
    () async {
      final service = _CircleService();
      final first = CircleTemplateController(
        templateId: _templateId,
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await first.load();
      await first.toggleSaved();

      final anotherSession = CircleTemplateController(
        templateId: _templateId,
        repository: CircleRepository(
          service: service,
          cache: MemoryReadCache(),
        ),
      );
      await anotherSession.load();

      expect(first.state.value!.saved, isTrue);
      expect(anotherSession.state.value!.saved, isTrue);
      expect(anotherSession.state.value!.revisionId, isNotEmpty);
    },
  );

  testWidgets('seeded template stays usable at 2x text in light mode', (
    tester,
  ) async {
    final controller = CircleTemplateController(
      templateId: _templateId,
      repository: CircleRepository(
        service: _CircleService(),
        cache: MemoryReadCache(),
      ),
    );
    await controller.load();
    String? openedAsset;
    String? copiedTemplate;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: _doubleTextBuilder,
        home: CircleTemplateScreen(
          controller: controller,
          onOpenAsset: (id) => openedAsset = id,
          onCopy: (id) => copiedTemplate = id,
        ),
      ),
    );

    expect(find.text('Fictional research profile'), findsWidgets);
    expect(find.textContaining('read-only'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('template-copy')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('private copy'), findsWidgets);
    await tester.tap(find.byKey(const Key('template-copy')));
    expect(copiedTemplate, _templateId);
    await tester.scrollUntilVisible(
      find.byKey(const Key('template-asset-$_assetA')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('template-asset-$_assetA')));
    expect(openedAsset, _assetA);
  });

  testWidgets('private Circle list stays usable at 2x text in dark mode', (
    tester,
  ) async {
    final service = _CircleService();
    final controller = CircleListController(
      repository: CircleRepository(service: service, cache: MemoryReadCache()),
      createKey: () => 'ui-create-key',
    );
    await controller.load();
    String? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: _doubleTextBuilder,
        home: PrivateCirclesScreen(
          controller: controller,
          onOpenCircle: (id) => opened = id,
        ),
      ),
    );

    expect(find.text('Your private Circles'), findsOneWidget);
    expect(find.textContaining('Editable only by you'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('private-circle-$_circleId')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('v2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('private-circle-$_circleId')));
    expect(opened, _circleId);
  });

  testWidgets('private Circle detail and conflict review work at 2x text', (
    tester,
  ) async {
    final service = _CircleService(conflictFirstPatch: true);
    final controller = CircleDetailController(
      circleId: _circleId,
      repository: CircleRepository(service: service, cache: MemoryReadCache()),
    );
    await controller.load();
    controller.updateDraft(title: 'My preserved research');
    await controller.saveDraft();
    String? openedAsset;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: _doubleTextBuilder,
        home: PrivateCircleDetailScreen(
          controller: controller,
          onOpenAsset: (id) => openedAsset = id,
        ),
      ),
    );

    expect(find.text('Private · editable'), findsOneWidget);
    expect(find.textContaining('Version 3'), findsOneWidget);
    expect(find.textContaining('follower'), findsNothing);
    expect(find.textContaining('comment'), findsNothing);
    expect(find.textContaining('message'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('private-conflict-retry')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('private-conflict-retry')), findsOneWidget);
    expect(find.byKey(const Key('private-conflict-authority')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('private-asset-open-$_assetA')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('private-asset-open-$_assetA')));
    expect(openedAsset, _assetA);
    expect(
      find.byKey(const Key('private-asset-edit-$_assetA')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('private-asset-remove-$_assetA')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('private-circle-archive')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('private-circle-archive')), findsOneWidget);
  });

  testWidgets(
    'full Circle hides Add and in-flight mutation disables controls',
    (tester) async {
      final fullAssets = [
        for (var index = 0; index < 50; index++)
          CircleAsset(
            assetId: _uuidFor(index + 3000),
            ordinal: index + 1,
            note: null,
            weightBps: null,
          ),
      ];
      final full = CircleDetailController(
        circleId: _circleId,
        repository: CircleRepository(
          service: _CircleService(initialAssets: fullAssets),
          cache: MemoryReadCache(),
        ),
      );
      await full.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PrivateCircleDetailScreen(
            controller: full,
            onOpenAsset: (_) {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Research assets'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('private-asset-add')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      final patchGate = Completer<void>();
      addTearDown(() {
        if (!patchGate.isCompleted) patchGate.complete();
      });
      final mutating = CircleDetailController(
        circleId: _circleId,
        repository: CircleRepository(
          service: _CircleService(patchGate: patchGate),
          cache: MemoryReadCache(),
        ),
      );
      await mutating.load();
      mutating.updateDraft(title: 'Pending serialized edit');
      final operation = mutating.saveDraft();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PrivateCircleDetailScreen(
            controller: mutating,
            onOpenAsset: (_) {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('private-circle-save')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('private-circle-save')))
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('private-asset-add')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('private-asset-add')))
            .onPressed,
        isNull,
      );
      patchGate.complete();
      await operation;
      await tester.pump();
      expect(mutating.isMutating, isFalse);
    },
  );
}

Widget _doubleTextBuilder(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
  child: child!,
);

String _uuidFor(int value) =>
    '00000000-0000-4000-8000-${value.toRadixString(16).padLeft(12, '0')}';

const _circleId = '00000000-0000-4000-8000-000000000741';
const _templateId = '00000000-0000-4000-8000-000000000742';
const _assetA = '00000000-0000-4000-8000-000000000743';
const _assetB = '00000000-0000-4000-8000-000000000744';

class _CircleService implements CircleService {
  _CircleService({
    this.loseFirstCopyResponse = false,
    this.conflictFirstPatch = false,
    this.conflictFirstReorder = false,
    this.loseFirstTemplateSaveResponse = false,
    this.delayCreateResponse = false,
    this.loseFirstPutResponse = false,
    this.loseFirstRemoveResponse = false,
    this.conflictFirstArchive = false,
    this.conflictRefetchFailure,
    this.patchGate,
    List<CircleAsset>? initialAssets,
  }) : current = _circle(assets: initialAssets);

  final bool loseFirstCopyResponse;
  final bool conflictFirstPatch;
  final bool conflictFirstReorder;
  final bool loseFirstTemplateSaveResponse;
  final bool delayCreateResponse;
  final bool loseFirstPutResponse;
  final bool loseFirstRemoveResponse;
  final bool conflictFirstArchive;
  final Object? conflictRefetchFailure;
  final Completer<void>? patchGate;
  final List<String> copyKeys = [];
  final List<String> createKeys = [];
  final List<int> archiveVersions = [];
  int createdCircles = 0;
  int templateSaveCalls = 0;
  int putCalls = 0;
  int patchCalls = 0;
  int fetchDetailCalls = 0;
  bool templateSaved = false;
  bool _copyLost = false;
  bool _patchConflicted = false;
  bool _reorderConflicted = false;
  bool _templateSaveLost = false;
  bool _putResponseLost = false;
  bool _removeResponseLost = false;
  bool _archiveConflicted = false;
  bool _conflictRefetchFailed = false;
  PrivateCircle current;

  @override
  Future<CircleCollection> fetchList({required bool includeArchived}) async =>
      CircleCollection(items: [current], nextCursor: null, hasMore: false);

  @override
  Future<PrivateCircle> fetchDetail(String circleId) async {
    fetchDetailCalls += 1;
    final conflictStarted =
        _patchConflicted || _reorderConflicted || _archiveConflicted;
    final failure = conflictRefetchFailure;
    if (conflictStarted && failure != null && !_conflictRefetchFailed) {
      _conflictRefetchFailed = true;
      throw failure;
    }
    return current;
  }

  @override
  Future<PrivateCircle> create(CircleCreateCommand command) async {
    createKeys.add(command.idempotencyKey);
    if (delayCreateResponse) await Future<void>.delayed(Duration.zero);
    createdCircles += 1;
    current = _circle(title: command.title, version: 1);
    return current;
  }

  @override
  Future<PrivateCircle> copy(CircleCopyCommand command) async {
    copyKeys.add(command.idempotencyKey);
    if (createdCircles == 0) {
      createdCircles = 1;
      current = _circle(
        title: command.title ?? 'Soft Power Circle',
        version: 1,
        sourceTemplateId: command.templateId,
      );
    }
    if (loseFirstCopyResponse && !_copyLost) {
      _copyLost = true;
      throw const CircleAmbiguousMutation();
    }
    return current;
  }

  @override
  Future<PrivateCircle> patch(
    String circleId,
    int expectedVersion,
    CircleDraft draft,
  ) async {
    patchCalls += 1;
    if (conflictFirstPatch && !_patchConflicted) {
      _patchConflicted = true;
      current = _circle(title: 'Changed on another device', version: 3);
      throw const LoadFailure(LoadPhase.conflict);
    }
    final gate = patchGate;
    if (gate != null) await gate.future;
    current = _circle(
      title: draft.title,
      description: draft.description,
      version: expectedVersion + 1,
      assets: current.assets,
    );
    return current;
  }

  @override
  Future<PrivateCircle> replaceAssets(
    String circleId,
    int expectedVersion,
    List<CircleAsset> assets,
  ) async {
    if (conflictFirstReorder && !_reorderConflicted) {
      _reorderConflicted = true;
      current = _circle(version: 3);
      throw const LoadFailure(LoadPhase.conflict);
    }
    current = _circle(version: expectedVersion + 1, assets: assets);
    return current;
  }

  @override
  Future<PrivateCircle> putAsset(
    String circleId,
    int expectedVersion,
    CircleAsset asset,
  ) async {
    putCalls += 1;
    final assets = [
      for (final existing in current.assets)
        if (existing.assetId == asset.assetId) asset else existing,
      if (!current.assets.any((existing) => existing.assetId == asset.assetId))
        asset,
    ];
    current = _circle(version: expectedVersion + 1, assets: assets);
    if (loseFirstPutResponse && !_putResponseLost) {
      _putResponseLost = true;
      throw const CircleAmbiguousMutation();
    }
    return current;
  }

  @override
  Future<PrivateCircle> removeAsset(
    String circleId,
    int expectedVersion,
    String assetId,
  ) async {
    current = _circle(
      version: expectedVersion + 1,
      assets: current.assets
          .where((asset) => asset.assetId != assetId)
          .toList(growable: false),
    );
    if (loseFirstRemoveResponse && !_removeResponseLost) {
      _removeResponseLost = true;
      throw const CircleAmbiguousMutation();
    }
    return current;
  }

  @override
  Future<void> archive(String circleId, int expectedVersion) async {
    archiveVersions.add(expectedVersion);
    if (conflictFirstArchive && !_archiveConflicted) {
      _archiveConflicted = true;
      current = _circle(version: 3);
      throw const LoadFailure(LoadPhase.conflict);
    }
    current = _circle(
      version: expectedVersion + 1,
      archivedAt: DateTime.utc(2026, 8, 25, 15),
    );
  }

  @override
  Future<CircleTemplateDetail> fetchTemplate(String templateId) =>
      Future.value(_template(saved: templateSaved));

  @override
  Future<void> saveTemplate(String templateId) async {
    templateSaveCalls += 1;
    templateSaved = true;
    if (loseFirstTemplateSaveResponse && !_templateSaveLost) {
      _templateSaveLost = true;
      throw const CircleAmbiguousMutation();
    }
  }

  @override
  Future<void> unsaveTemplate(String templateId) async => templateSaved = false;
}

PrivateCircle _circle({
  String title = 'Private research',
  String description = 'Only visible to this member.',
  int version = 2,
  List<CircleAsset>? assets,
  String? sourceTemplateId,
  DateTime? archivedAt,
}) => PrivateCircle(
  id: _circleId,
  title: title,
  description: description,
  private: true,
  version: version,
  assets:
      assets ??
      const [
        CircleAsset(assetId: _assetA, ordinal: 1, note: null, weightBps: 6000),
        CircleAsset(assetId: _assetB, ordinal: 2, note: null, weightBps: 4000),
      ],
  sourceTemplateId: sourceTemplateId,
  sourceRevisionId: sourceTemplateId == null
      ? null
      : '00000000-0000-4000-8000-000000000745',
  archivedAt: archivedAt,
);

CircleTemplateDetail _template({required bool saved}) => CircleTemplateDetail(
  id: _templateId,
  revisionId: '00000000-0000-4000-8000-000000000745',
  slug: 'soft-power-circle',
  title: 'Soft Power Circle',
  description: 'A fictional read-only seeded research example.',
  theme: 'leadership',
  creator: SeededCreatorView(
    id: '00000000-0000-4000-8000-000000000746',
    slug: 'mira-vale',
    displayName: 'Mira Vale',
    bio: 'Fictional Demo creator',
    isFictional: true,
    demo: _demo,
  ),
  assets: [
    CircleTemplateAsset(
      id: _assetA,
      revisionId: '00000000-0000-4000-8000-000000000747',
      slug: 'quiet-power-etf',
      symbol: 'QPW',
      name: 'Quiet Power ETF',
      appearanceReason: 'Fictional durability scenario.',
      note: 'Research the uncertainty.',
      ordinal: 1,
      weightBps: 6000,
      demo: _demo,
    ),
  ],
  saved: saved,
  demo: _demo,
);

final _demo = ResearchDemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25, 12),
  sourceLabel: 'Deterministic Circle fixture',
  limitations: const ['Fictional scenario; not investment advice.'],
);
