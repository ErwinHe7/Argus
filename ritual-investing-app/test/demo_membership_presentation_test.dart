import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/cached_read.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/entitlements/application/entitlement_controller.dart';
import 'package:ritual_investing_app/features/entitlements/data/repository.dart';
import 'package:ritual_investing_app/features/entitlements/domain/model.dart';
import 'package:ritual_investing_app/features/entitlements/presentation/demo_membership_screen.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      '${brightness.name} plan comparison remains usable at 2x text',
      (tester) async {
        final repository = _Repository();
        final controller = _controller(repository);
        await controller.load();
        String? checkoutId;

        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.light
                : AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: MembershipPlansScreen(
              controller: controller,
              requestedCapability: DemoCapability.futureMirror,
              returnLocation: '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror',
              onOpenCheckout: (value) => checkoutId = value,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('no charge'), findsWidgets);
        expect(find.textContaining('real purchase'), findsOneWidget);
        expect(find.textContaining('Personalization changes'), findsOneWidget);
        expect(find.textContaining('Future Mirror'), findsWidgets);
        expect(find.text(_checkoutId), findsNothing);
        await _scrollTo(
          tester,
          find.byKey(const Key('membership-choose-premium')),
        );
        expect(
          tester
              .getSize(find.byKey(const Key('membership-choose-premium')))
              .height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byKey(const Key('membership-choose-premium')));
        await tester.pumpAndSettle();
        expect(checkoutId, _checkoutId);
        expect(repository.createCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('checkout and receipt keep Demo/no-charge disclosure adjacent', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = _controller(repository);
    await controller.load();
    controller.prepareCheckout(
      capability: DemoCapability.futureMirror,
      returnLocation: '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror',
    );
    await controller.createCheckout();
    var openedReceipt = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: DemoCheckoutScreen(
          sessionId: _checkoutId,
          controller: controller,
          onReceipt: () => openedReceipt = true,
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('no charge'), findsWidgets);
    expect(find.textContaining('no card'), findsOneWidget);
    await _scrollTo(
      tester,
      find.byKey(const Key('membership-confirm-checkout')),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('membership-confirm-checkout')))
          .height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const Key('membership-confirm-checkout')));
    await tester.pumpAndSettle();
    expect(openedReceipt, isTrue);

    String? returned;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: DemoMembershipReceiptScreen(
          sessionId: _checkoutId,
          controller: controller,
          onContinue: (value) => returned = value,
          onBackToMembership: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.textContaining('Receipt amount: No charge'));
    expect(find.textContaining('Receipt amount: No charge'), findsOneWidget);
    expect(find.textContaining('payment provider'), findsWidgets);
    await _scrollTo(
      tester,
      find.byKey(const Key('membership-return-to-capability')),
    );
    await tester.tap(find.byKey(const Key('membership-return-to-capability')));
    expect(returned, contains('/future-mirror'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale free gate stays closed and offers no upgrade traffic', (
    tester,
  ) async {
    final repository = _Repository()..stale = true;
    final controller = _controller(repository);
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DemoCapabilityGate(
          controller: controller,
          capability: DemoCapability.dailyRitual,
          returnLocation: '/ritual',
          onOpenMembership: () => fail('stale authority cannot upgrade'),
          child: const Text('PRIVATE RITUAL CONTENT'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIVATE RITUAL CONTENT'), findsNothing);
    expect(find.byKey(const Key('capability-open-membership')), findsNothing);
    expect(find.text('Refresh server access'), findsOneWidget);
  });

  testWidgets(
    'direct receipt route cannot show success without fresh premium entitlement',
    (tester) async {
      final repository = _Repository()
        ..checkout = DemoCheckout(
          id: _checkoutId,
          planCode: DemoPlanCode.premiumDemo,
          status: DemoCheckoutStatus.completed,
          expiresAt: DateTime.utc(2026, 8, 25, 13),
          version: 4,
          disclosure: _disclosure,
        );
      final controller = _controller(repository);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DemoMembershipReceiptScreen(
            sessionId: _checkoutId,
            controller: controller,
            onContinue: (_) => fail('free authority cannot continue'),
            onBackToMembership: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Premium Demo access is active'), findsNothing);
      expect(find.textContaining('Receipt amount:'), findsNothing);
      expect(
        find.byKey(const Key('membership-return-to-capability')),
        findsNothing,
      );
      await _scrollTo(tester, find.text('Refresh server membership'));
      expect(find.text('Refresh server membership'), findsOneWidget);
      expect(controller.phase, EntitlementPhase.reconciliationRequired);
    },
  );
}

EntitlementController _controller(_Repository repository) {
  var key = 0;
  return EntitlementController(
    repository: repository,
    pendingStore: PendingCommandStore(storage: _Storage()),
    scope: const CacheScope(accountId: 'account-a', resetGeneration: 1),
    createKey: () => 'membership-widget-key-${++key}',
    now: () => DateTime.utc(2026, 8, 25, 12),
    personalization: const MemberPersonalization(
      explanationDepth: MemberExplanationDepth.advanced,
      ritualVoice: MemberRitualVoice.mystical,
    ),
  );
}

class _Repository implements EntitlementRepository {
  bool stale = false;
  int createCalls = 0;
  DemoEntitlement entitlement = _freeEntitlement;
  DemoCheckout checkout = _openCheckout;

  @override
  Future<RepositoryRead<List<DemoPlan>>> loadPlans() async =>
      RepositoryRead(value: _plans, isStale: stale, committedAt: _now);

  @override
  Future<RepositoryRead<DemoEntitlement>> loadEntitlement() async =>
      RepositoryRead(value: entitlement, isStale: stale, committedAt: _now);

  @override
  Future<DemoCheckout> getCheckout(String sessionId) async => checkout;

  @override
  Future<DemoCheckout> createCheckout(String planCode, String key) async {
    createCalls++;
    return checkout;
  }

  @override
  Future<DemoEntitlement> confirmCheckout(
    String sessionId,
    int expectedVersion,
    String key,
  ) async {
    checkout = DemoCheckout(
      id: checkout.id,
      planCode: checkout.planCode,
      status: DemoCheckoutStatus.completed,
      expiresAt: checkout.expiresAt,
      version: expectedVersion + 1,
      disclosure: checkout.disclosure,
    );
    entitlement = DemoEntitlement(
      id: '33333333-3333-4333-8333-333333333334',
      planCode: DemoPlanCode.premiumDemo,
      status: DemoEntitlementStatus.active,
      startsAt: _now,
      version: 6,
      disclosure: _disclosure,
    );
    return entitlement;
  }

  @override
  Future<DemoEntitlement> restore(String key) async => entitlement;

  @override
  Future<DemoEntitlement> downgrade(int expectedVersion, String key) async =>
      entitlement;
}

final _plans = [
  DemoPlan(
    code: DemoPlanCode.free,
    displayName: 'Ritual Free Demo',
    priceCopy: 'No charge — simulated access only',
    capabilityCodes: const {'daily_ritual', 'demo_portfolio'},
    disclosure: _disclosure,
  ),
  DemoPlan(
    code: DemoPlanCode.premiumDemo,
    displayName: 'Ritual Premium Demo',
    priceCopy: 'Illustrative premium access — no charge',
    capabilityCodes: const {'daily_ritual', 'demo_portfolio', 'future_mirror'},
    disclosure: _disclosure,
  ),
];

final _freeEntitlement = DemoEntitlement(
  id: '33333333-3333-4333-8333-333333333333',
  planCode: DemoPlanCode.free,
  status: DemoEntitlementStatus.active,
  startsAt: DateTime.utc(2026, 8, 1),
  version: 5,
  disclosure: _disclosure,
);

final _openCheckout = DemoCheckout(
  id: _checkoutId,
  planCode: DemoPlanCode.premiumDemo,
  status: DemoCheckoutStatus.open,
  expiresAt: DateTime.utc(2026, 8, 25, 13),
  version: 3,
  disclosure: _disclosure,
);

final _disclosure = DemoDisclosure(
  isDemo: true,
  observedAt: _now,
  sourceLabel: 'Ritual deterministic Demo',
  limitations: const [
    'No money moves and no external financial provider is contacted.',
  ],
);

final _now = DateTime.utc(2026, 8, 25, 12);
const _checkoutId = '22222222-2222-4222-8222-222222222222';
final _verticalScrollable = find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 12; attempt++) {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(_verticalScrollable, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
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
