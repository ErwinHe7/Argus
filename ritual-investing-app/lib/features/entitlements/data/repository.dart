// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class EntitlementService {
  Future<List<DemoPlan>> listPlans();
  Future<DemoEntitlement> getEntitlement();
  Future<DemoCheckout> getCheckout(String sessionId);
  Future<DemoCheckout> createCheckout(String planCode, String key);
  Future<DemoEntitlement> confirmCheckout(
    String sessionId,
    int expectedVersion,
    String key,
  );
  Future<DemoEntitlement> restore(String key);
  Future<DemoEntitlement> downgrade(int expectedVersion, String key);
}

abstract interface class EntitlementRepository {
  Future<RepositoryRead<List<DemoPlan>>> loadPlans();
  Future<RepositoryRead<DemoEntitlement>> loadEntitlement();
  Future<DemoCheckout> getCheckout(String sessionId);
  Future<DemoCheckout> createCheckout(String planCode, String key);
  Future<DemoEntitlement> confirmCheckout(
    String sessionId,
    int expectedVersion,
    String key,
  );
  Future<DemoEntitlement> restore(String key);
  Future<DemoEntitlement> downgrade(int expectedVersion, String key);
}

class CachedEntitlementRepository implements EntitlementRepository {
  CachedEntitlementRepository({
    required EntitlementService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final EntitlementService _service;
  final ReadCache _cache;

  @override
  Future<RepositoryRead<List<DemoPlan>>> loadPlans() => cachedRead(
    key: 'demo-membership-plans',
    cache: _cache,
    fetch: _service.listPlans,
  );

  @override
  Future<RepositoryRead<DemoEntitlement>> loadEntitlement() => cachedRead(
    key: 'demo-membership-entitlement',
    cache: _cache,
    fetch: _service.getEntitlement,
  );

  @override
  Future<DemoCheckout> getCheckout(String sessionId) =>
      _service.getCheckout(sessionId);

  @override
  Future<DemoCheckout> createCheckout(String planCode, String key) =>
      _service.createCheckout(planCode, key);

  @override
  Future<DemoEntitlement> confirmCheckout(
    String sessionId,
    int expectedVersion,
    String key,
  ) => _service.confirmCheckout(sessionId, expectedVersion, key);

  @override
  Future<DemoEntitlement> restore(String key) => _service.restore(key);

  @override
  Future<DemoEntitlement> downgrade(int expectedVersion, String key) =>
      _service.downgrade(expectedVersion, key);
}
