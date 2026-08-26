import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/entitlements/application/entitlement_controller.dart';
import 'package:ritual_investing_app/features/entitlements/data/repository.dart';
import 'package:ritual_investing_app/features/entitlements/domain/model.dart';

void main() {
  test(
    'gate uses fresh capability codes, never plan-name assumptions',
    () async {
      final service = _MembershipService();
      final controller = _controller(service);

      await controller.load();

      expect(controller.gate(DemoCapability.dailyRitual).isAllowed, isTrue);
      expect(controller.gate(DemoCapability.futureMirror).isAllowed, isFalse);
      service.entitlement = _entitlement(plan: DemoPlanCode.premiumDemo);
      await controller.load();
      expect(controller.gate(DemoCapability.futureMirror).isAllowed, isTrue);
    },
  );

  test('unknown capability and stale authority fail closed', () async {
    final service = _MembershipService();
    final controller = _controller(service);
    await controller.load();

    expect(controller.gateCode('future_mirror_plus').isAllowed, isFalse);
    service.offline = true;
    await controller.load();
    expect(controller.gate(DemoCapability.dailyRitual).isAllowed, isFalse);
    expect(controller.phase, EntitlementPhase.stale);
  });

  test('return context accepts only stable capability route shapes', () {
    final controller = _controller(_MembershipService());

    expect(
      controller.acceptsReturnContext(
        DemoCapability.futureMirror,
        '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror/22222222-2222-4222-8222-222222222222',
      ),
      isTrue,
    );
    expect(
      controller.acceptsReturnContext(
        DemoCapability.futureMirror,
        '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror/------------------------------------',
      ),
      isFalse,
    );
  });

  test('personalization changes explanation only, never authority', () async {
    final service = _MembershipService();
    final controller = _controller(
      service,
      personalization: const MemberPersonalization(
        explanationDepth: MemberExplanationDepth.beginner,
        ritualVoice: MemberRitualVoice.practical,
      ),
    );
    await controller.load();
    final before = controller.gate(DemoCapability.futureMirror);

    controller.updatePersonalization(
      const MemberPersonalization(
        explanationDepth: MemberExplanationDepth.advanced,
        ritualVoice: MemberRitualVoice.mystical,
      ),
    );

    expect(controller.explanationLabel, contains('Symbolic'));
    expect(controller.explanationLabel, contains('concise'));
    expect(controller.gate(DemoCapability.futureMirror), before);
  });

  test(
    'checkout confirms once and refreshes authoritative entitlement',
    () async {
      final service = _MembershipService();
      final controller = _controller(service);
      await controller.load();
      controller.prepareCheckout(
        capability: DemoCapability.futureMirror,
        returnLocation: '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror',
      );

      await controller.createCheckout();
      expect(controller.phase, EntitlementPhase.checkoutReview);
      await controller.confirmCheckout();

      expect(service.createKeys, ['membership-key-1']);
      expect(service.confirmKeys, ['membership-key-2']);
      expect(service.confirmVersions, [3]);
      expect(service.entitlementReads, greaterThanOrEqualTo(2));
      expect(controller.phase, EntitlementPhase.receipt);
      expect(controller.gate(DemoCapability.futureMirror).isAllowed, isTrue);
    },
  );

  test(
    'ambiguous confirm reconciles exact checkout without auto-submit',
    () async {
      final service = _MembershipService()..ambiguousConfirm = true;
      final controller = _controller(service);
      await controller.load();
      controller.prepareCheckout(
        capability: DemoCapability.futureMirror,
        returnLocation: '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror',
      );
      await controller.createCheckout();

      await controller.confirmCheckout();

      expect(service.confirmKeys, ['membership-key-2']);
      expect(service.checkoutReads, 1);
      expect(controller.phase, EntitlementPhase.receipt);
      expect(controller.hasProtectedCommand, isFalse);
    },
  );

  test(
    'relaunch reconciles protected confirm before offering same-key retry',
    () async {
      final storage = _Storage();
      final service = _MembershipService()
        ..ambiguousConfirm = true
        ..checkoutOffline = true;
      final first = _controller(service, storage: storage);
      await first.load();
      first.prepareCheckout(
        capability: DemoCapability.futureMirror,
        returnLocation: '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror',
      );
      await first.createCheckout();
      await first.confirmCheckout();
      expect(first.phase, EntitlementPhase.reconciliationRequired);
      expect(service.confirmKeys, ['membership-key-2']);

      service.checkoutOffline = false;
      final restarted = _controller(service, storage: storage);
      await restarted.load();

      expect(service.confirmKeys, ['membership-key-2']);
      expect(service.checkoutReads, 2);
      expect(restarted.phase, EntitlementPhase.receipt);
      expect(restarted.hasProtectedCommand, isFalse);
    },
  );

  test(
    'lost create response restores exact same-key review after relaunch',
    () async {
      final storage = _Storage();
      final service = _MembershipService()..ambiguousCreate = true;
      final first = _controller(service, storage: storage);
      await first.load();
      first.prepareCheckout(
        capability: DemoCapability.futureMirror,
        returnLocation: '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror',
      );
      await first.createCheckout();
      expect(first.phase, EntitlementPhase.restoredReview);
      expect(service.createKeys, ['membership-key-1']);

      final restarted = _controller(service, storage: storage);
      await restarted.load();
      expect(restarted.phase, EntitlementPhase.restoredReview);
      service.ambiguousCreate = false;
      restarted.reviewProtectedCommand();
      await restarted.createCheckout();

      expect(service.createKeys, ['membership-key-1', 'membership-key-1']);
      expect(service.createEffects, 1);
      expect(restarted.phase, EntitlementPhase.checkoutReview);
    },
  );

  test(
    'cancel is local abandonment and expired checkout cannot confirm',
    () async {
      final service = _MembershipService();
      final controller = _controller(service);
      await controller.load();
      controller.prepareCheckout(
        capability: DemoCapability.futureMirror,
        returnLocation: '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror',
      );
      await controller.createCheckout();
      controller.cancelCheckout();
      expect(service.cancelCalls, 0);
      expect(controller.phase, EntitlementPhase.ready);

      service.checkout = _checkout(status: DemoCheckoutStatus.expired);
      await controller.openCheckout(_checkoutId);
      await controller.confirmCheckout();
      expect(service.confirmKeys, isEmpty);
      expect(controller.phase, EntitlementPhase.expired);
    },
  );

  test('completed checkout never becomes receipt without fresh premium entitlement', () async {
    final service = _MembershipService()
      ..checkout = _checkout(status: DemoCheckoutStatus.completed);
    final controller = _controller(service);
    await controller.load();

    await controller.openCheckout(_checkoutId);

    expect(controller.phase, EntitlementPhase.reconciliationRequired);
    expect(controller.entitlement?.planCode, DemoPlanCode.free);
  });

  test(
    'restore and downgrade refresh authority and keep one protected key',
    () async {
      final service = _MembershipService()
        ..entitlement = _entitlement(plan: DemoPlanCode.premiumDemo);
      final controller = _controller(service);
      await controller.load();

      controller.prepareDowngrade();
      await controller.confirmDowngrade();
      expect(service.downgradeKeys, ['membership-key-1']);
      expect(service.downgradeVersions, [5]);
      expect(controller.entitlement?.planCode, DemoPlanCode.free);

      await controller.restore();
      expect(service.restoreKeys, ['membership-key-2']);
      expect(service.entitlementReads, greaterThanOrEqualTo(3));
    },
  );

  test('protected commands are account and reset scoped', () async {
    final storage = _Storage();
    final service = _MembershipService()..ambiguousCreate = true;
    final first = _controller(service, storage: storage);
    await first.load();
    first.prepareCheckout(
      capability: DemoCapability.futureMirror,
      returnLocation: '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror',
    );
    await first.createCheckout();

    final other = _controller(
      _MembershipService(),
      storage: storage,
      scope: const CacheScope(accountId: 'account-b', resetGeneration: 2),
    );
    await other.load();
    expect(other.hasProtectedCommand, isFalse);
  });
}

EntitlementController _controller(
  _MembershipService service, {
  _Storage? storage,
  CacheScope scope = const CacheScope(
    accountId: 'account-a',
    resetGeneration: 2,
  ),
  MemberPersonalization personalization = const MemberPersonalization(),
}) {
  var key = 0;
  return EntitlementController(
    repository: CachedEntitlementRepository(
      service: service,
      cache: MemoryReadCache(),
    ),
    pendingStore: PendingCommandStore(storage: storage ?? _Storage()),
    scope: scope,
    createKey: () => 'membership-key-${++key}',
    now: () => DateTime.utc(2026, 8, 25, 12),
    personalization: personalization,
  );
}

class _MembershipService implements EntitlementService {
  bool offline = false;
  bool ambiguousCreate = false;
  bool ambiguousConfirm = false;
  bool checkoutOffline = false;
  int entitlementReads = 0;
  int checkoutReads = 0;
  int createEffects = 0;
  int cancelCalls = 0;
  final List<String> createKeys = [];
  final List<String> confirmKeys = [];
  final List<int> confirmVersions = [];
  final List<String> restoreKeys = [];
  final List<String> downgradeKeys = [];
  final List<int> downgradeVersions = [];
  final Map<String, DemoCheckout> _creates = {};
  DemoEntitlement entitlement = _entitlement();
  DemoCheckout checkout = _checkout();

  @override
  Future<List<DemoPlan>> listPlans() async {
    if (offline) throw const OfflineException();
    return _plans;
  }

  @override
  Future<DemoEntitlement> getEntitlement() async {
    entitlementReads++;
    if (offline) throw const OfflineException();
    return entitlement;
  }

  @override
  Future<DemoCheckout> getCheckout(String sessionId) async {
    checkoutReads++;
    if (offline || checkoutOffline) throw const OfflineException();
    return checkout;
  }

  @override
  Future<DemoCheckout> createCheckout(String planCode, String key) async {
    createKeys.add(key);
    final existing = _creates[key];
    if (existing != null) return existing;
    _creates[key] = checkout;
    createEffects++;
    if (ambiguousCreate) throw const AmbiguousEntitlementMutation();
    return checkout;
  }

  @override
  Future<DemoEntitlement> confirmCheckout(
    String sessionId,
    int expectedVersion,
    String key,
  ) async {
    confirmKeys.add(key);
    confirmVersions.add(expectedVersion);
    entitlement = _entitlement(plan: DemoPlanCode.premiumDemo, version: 6);
    checkout = _checkout(
      status: DemoCheckoutStatus.completed,
      version: expectedVersion + 1,
    );
    if (ambiguousConfirm) throw const AmbiguousEntitlementMutation();
    return entitlement;
  }

  @override
  Future<DemoEntitlement> restore(String key) async {
    restoreKeys.add(key);
    return entitlement;
  }

  @override
  Future<DemoEntitlement> downgrade(int expectedVersion, String key) async {
    downgradeKeys.add(key);
    downgradeVersions.add(expectedVersion);
    entitlement = _entitlement(version: expectedVersion + 1);
    return entitlement;
  }
}

const _checkoutId = '22222222-2222-4222-8222-222222222222';

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

DemoEntitlement _entitlement({
  DemoPlanCode plan = DemoPlanCode.free,
  int version = 5,
}) => DemoEntitlement(
  id: '33333333-3333-4333-8333-333333333333',
  planCode: plan,
  status: DemoEntitlementStatus.active,
  startsAt: DateTime.utc(2026, 8, 1),
  version: version,
  disclosure: _disclosure,
);

DemoCheckout _checkout({
  DemoCheckoutStatus status = DemoCheckoutStatus.open,
  int version = 3,
}) => DemoCheckout(
  id: _checkoutId,
  planCode: DemoPlanCode.premiumDemo,
  status: status,
  expiresAt: DateTime.utc(2026, 8, 25, 13),
  version: version,
  disclosure: _disclosure,
);

final _disclosure = DemoDisclosure(
  isDemo: true,
  observedAt: DateTime.utc(2026, 8, 25),
  sourceLabel: 'Ritual Demo service',
  limitations: const ['No real purchase or charge occurs.'],
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
