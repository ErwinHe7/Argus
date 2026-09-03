import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/ritual_api.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/asset_codex/application/controller.dart';
import 'package:ritual_investing_app/features/asset_codex/presentation/asset_codex_screen.dart';
import 'package:ritual_investing_app/features/circles/application/controller.dart';
import 'package:ritual_investing_app/features/circles/data/generated_circle_api_service.dart';
import 'package:ritual_investing_app/features/circles/data/repository.dart';
import 'package:ritual_investing_app/features/circles/presentation/circle_template_screen.dart';
import 'package:ritual_investing_app/features/circles/presentation/private_circle_detail_screen.dart';
import 'package:ritual_investing_app/features/coven/application/controller.dart';
import 'package:ritual_investing_app/features/coven/data/repository.dart';
import 'package:ritual_investing_app/features/coven/presentation/coven_detail_screen.dart';
import 'package:ritual_investing_app/features/discover/application/controller.dart';
import 'package:ritual_investing_app/features/discover/data/repository.dart';
import 'package:ritual_investing_app/features/discover/domain/model.dart';
import 'package:ritual_investing_app/features/discover/presentation/discover_screen.dart';
import 'package:ritual_investing_app/features/grimoires/application/controller.dart';
import 'package:ritual_investing_app/features/grimoires/data/generated_grimoire_api_service.dart';
import 'package:ritual_investing_app/features/grimoires/data/repository.dart';
import 'package:ritual_investing_app/features/grimoires/presentation/grimoire_detail_screen.dart';

import 'support/u4_http_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'loopback member journey discovers, copies, resolves conflict, archives, and asks Coven Rowan',
    (tester) async {
      late U4HttpHarness harness;
      await tester.runAsync(() async {
        harness = await U4HttpHarness.start();
      });
      addTearDown(harness.close);

      await tester.pumpWidget(_U5FlowApp(harness: harness));
      await _pumpUntil(
        tester,
        () => find.text('Patient Compounding').evaluate().isNotEmpty,
      );

      expect(find.text('A wider research lens'), findsOneWidget);
      expect(find.text('Patient Compounding'), findsOneWidget);
      await tester.tap(find.byKey(const Key('discover-lead')));
      await _pumpUntil(
        tester,
        () => find.byKey(const Key('grimoire-save')).evaluate().isNotEmpty,
      );

      expect(find.text('Patient Compounding'), findsOneWidget);
      await tester.tap(find.byKey(const Key('grimoire-save')));
      await _pumpUntil(tester, () => find.text('Saved').evaluate().isNotEmpty);
      expect(find.text('Saved'), findsOneWidget);
      await tester.tap(find.byKey(const Key('grimoire-asset-$u4AssetId')));
      await _pumpUntil(
        tester,
        () => find.byKey(const Key('asset-codex-screen')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('asset-codex-screen')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Soft Power Circle'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Soft Power Circle'));
      await _pumpUntil(
        tester,
        () => find.byKey(const Key('template-copy')).evaluate().isNotEmpty,
      );
      expect(find.text('Fictional seeded example · read-only'), findsOneWidget);
      await tester.tap(find.byKey(const Key('template-copy')));
      await _pumpUntil(
        tester,
        () =>
            find.byKey(const Key('private-circle-save')).evaluate().isNotEmpty,
      );

      expect(find.text('Private · editable'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('private-title-$u5CircleId')),
        'My preserved private draft',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('private-circle-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('private-circle-save')));
      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('private-conflict-retry'))
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Review changes from another device'), findsOneWidget);
      expect(find.textContaining('pending edit is preserved'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('private-conflict-retry')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('private-conflict-retry')));
      await _pumpUntil(
        tester,
        () => find.text('Version 4').evaluate().isNotEmpty,
      );
      expect(find.text('Version 4'), findsOneWidget);
      expect(find.text('My preserved private draft'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('private-circle-archive')),
        450,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('private-circle-archive')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive').last);
      await _pumpUntil(
        tester,
        () => find.text('Archived · read-only').evaluate().isNotEmpty,
      );
      expect(find.text('Archived · read-only'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Aurora Healthworks'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Aurora Healthworks'));
      await _pumpUntil(
        tester,
        () => find.byKey(const Key('rowan-explain')).evaluate().isNotEmpty,
      );
      expect(find.text('Woman founder'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('rowan-explain')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('rowan-explain')));
      await _pumpUntil(
        tester,
        () => find
            .text('Qualification evidence is dated, not assumed.')
            .evaluate()
            .isNotEmpty,
      );
      expect(
        find.text('Qualification evidence is dated, not assumed.'),
        findsOneWidget,
      );

      _expectSocketBoundary(harness);
    },
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) break;
    final delay = remaining < pollInterval ? remaining : pollInterval;
    await tester.runAsync<void>(() => Future<void>.delayed(delay));
    await tester.pump();
  }
  stopwatch.stop();
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for loopback UI state.',
  );
  await tester.pump();
}

void _expectSocketBoundary(U4HttpHarness harness) {
  expect(harness.requests, isNotEmpty);
  expect(
    harness.requests.every(
      (request) => request.authorization == 'Bearer u4-local-member-token',
    ),
    isTrue,
  );
  final copy = harness.requests.singleWhere(
    (request) => request.uri.path.endsWith('/copies'),
  );
  expect(copy.idempotencyKey, isNotEmpty);
  expect(jsonDecode(copy.body), <String, Object?>{});
  expect(
    harness.requests
        .where((request) => request.method == 'PATCH')
        .map((request) => request.ifMatch),
    ['"v2"', '"v3"'],
  );
  expect(
    harness.requests
        .singleWhere(
          (request) =>
              request.method == 'DELETE' &&
              request.uri.path == '/v1/circles/$u5CircleId',
        )
        .ifMatch,
    '"v4"',
  );
  final covenRowan = harness.requests.singleWhere(
    (request) => request.uri.path == '/v1/rowan/coven/coven',
  );
  expect(covenRowan.uri.queryParameters, isEmpty);
  final serialized = harness.requests
      .map((request) => '${request.uri} ${request.body}')
      .join(' ')
      .toLowerCase();
  expect(serialized, isNot(matches(RegExp(r'plaid|brokerage|banking'))));
}

const _personalization = MemberPersonalization(
  explanationDepth: MemberExplanationDepth.advanced,
  ritualVoice: MemberRitualVoice.practical,
  riskFraming: MemberRiskFraming.high,
);

class _U5FlowApp extends StatefulWidget {
  const _U5FlowApp({required this.harness});

  final U4HttpHarness harness;

  @override
  State<_U5FlowApp> createState() => _U5FlowAppState();
}

class _U5FlowAppState extends State<_U5FlowApp> {
  late final DiscoverController _discover = DiscoverController(
    repository: CachedDiscoverRepository(
      service: GeneratedDiscoverApiService(widget.harness.client),
      cache: MemoryReadCache(),
    ),
    personalization: _personalization,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_discover.load());
  }

  @override
  void dispose() {
    _discover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Builder(
      builder: (context) => Scaffold(
        body: DiscoverScreen(
          controller: _discover,
          onOpenItem: (item) => _openItem(context, item),
        ),
      ),
    ),
  );

  void _openItem(BuildContext context, DiscoverItemView item) {
    final route = switch (item.kind) {
      DiscoverItemKind.grimoire => MaterialPageRoute<void>(
        builder: (_) => _GrimoireFlow(harness: widget.harness),
      ),
      DiscoverItemKind.circleTemplate => MaterialPageRoute<void>(
        builder: (_) => _TemplateFlow(harness: widget.harness),
      ),
      DiscoverItemKind.coven => MaterialPageRoute<void>(
        builder: (_) => _CovenFlow(harness: widget.harness),
      ),
      DiscoverItemKind.asset => MaterialPageRoute<void>(
        builder: (_) => _AssetFlow(harness: widget.harness),
      ),
    };
    Navigator.push(context, route);
  }
}

class _GrimoireFlow extends StatefulWidget {
  const _GrimoireFlow({required this.harness});
  final U4HttpHarness harness;

  @override
  State<_GrimoireFlow> createState() => _GrimoireFlowState();
}

class _GrimoireFlowState extends State<_GrimoireFlow> {
  late final GrimoireController controller = GrimoireController(
    grimoireId: u5GrimoireId,
    repository: GrimoireRepository(
      service: GeneratedGrimoireService(widget.harness.client),
      cache: MemoryReadCache(),
    ),
  );

  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GrimoireDetailScreen(
    controller: controller,
    onOpenAsset: (_) => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _AssetFlow(harness: widget.harness),
      ),
    ),
  );
}

class _AssetFlow extends StatefulWidget {
  const _AssetFlow({required this.harness});
  final U4HttpHarness harness;

  @override
  State<_AssetFlow> createState() => _AssetFlowState();
}

class _AssetFlowState extends State<_AssetFlow> {
  late final AssetCodexController controller = widget.harness.assetController();

  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AssetCodexScreen(
    controller: controller,
    rowanController: null,
    personalization: _personalization,
  );
}

class _TemplateFlow extends StatefulWidget {
  const _TemplateFlow({required this.harness});
  final U4HttpHarness harness;

  @override
  State<_TemplateFlow> createState() => _TemplateFlowState();
}

class _TemplateFlowState extends State<_TemplateFlow> {
  late final CircleRepository repository = CircleRepository(
    service: GeneratedCircleService(widget.harness.client),
    cache: MemoryReadCache(),
  );
  late final CircleTemplateController template = CircleTemplateController(
    templateId: u5TemplateId,
    repository: repository,
  );
  late final CircleListController copy = CircleListController(
    repository: repository,
    createKey: () => 'u5-loopback-copy-key',
  );

  @override
  void initState() {
    super.initState();
    unawaited(template.load());
  }

  @override
  void dispose() {
    template.dispose();
    copy.dispose();
    super.dispose();
  }

  Future<void> _copy(BuildContext context) async {
    await copy.copyTemplate(u5TemplateId);
    if (!context.mounted || copy.lastCreated == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _CircleFlow(repository: repository, circleId: copy.lastCreated!.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CircleTemplateScreen(
    controller: template,
    copyController: copy,
    onRetryCopy: () => unawaited(copy.retryPending()),
    onOpenAsset: (_) {},
    onCopy: (_) => unawaited(_copy(context)),
  );
}

class _CircleFlow extends StatefulWidget {
  const _CircleFlow({required this.repository, required this.circleId});
  final CircleRepository repository;
  final String circleId;

  @override
  State<_CircleFlow> createState() => _CircleFlowState();
}

class _CircleFlowState extends State<_CircleFlow> {
  late final CircleDetailController controller = CircleDetailController(
    circleId: widget.circleId,
    repository: widget.repository,
  );

  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PrivateCircleDetailScreen(controller: controller, onOpenAsset: (_) {});
}

class _CovenFlow extends StatefulWidget {
  const _CovenFlow({required this.harness});
  final U4HttpHarness harness;

  @override
  State<_CovenFlow> createState() => _CovenFlowState();
}

class _CovenFlowState extends State<_CovenFlow> {
  late final CovenDetailController controller = CovenDetailController(
    entryId: u5CovenId,
    repository: CovenRepository(
      service: GeneratedCovenApiService(widget.harness.client),
      cache: MemoryReadCache(),
    ),
  );

  @override
  void initState() {
    super.initState();
    unawaited(controller.load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CovenDetailScreen(
    controller: controller,
    rowanController: widget.harness.rowanController,
    personalization: _personalization,
  );
}
