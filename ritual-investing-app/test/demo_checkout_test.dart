import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/entitlements/data/repository.dart';
import 'package:ritual_investing_app/features/entitlements/domain/model.dart';

void main() {
  test(
    'generated Dio membership adapter sends exact provider-free contract',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final service = GeneratedEntitlementService(
        RitualInvestingApiClient(
          basePathOverride: harness.baseUrl,
          interceptors: [RitualAuthInterceptor(tokenProvider: const _Token())],
        ),
      );

      final plans = await service.listPlans();
      final entitlement = await service.getEntitlement();
      final created = await service.createCheckout(
        'premium_demo',
        'checkout-create-key-0001',
      );
      final exact = await service.getCheckout(_checkoutId);
      final confirmed = await service.confirmCheckout(
        _checkoutId,
        3,
        'checkout-confirm-key-001',
      );
      final restored = await service.restore('entitlement-restore-key1');
      final downgraded = await service.downgrade(6, 'entitlement-downgrade-1');

      expect(plans.map((plan) => plan.code), {
        DemoPlanCode.free,
        DemoPlanCode.premiumDemo,
      });
      expect(entitlement.planCode, DemoPlanCode.free);
      expect(created.status, DemoCheckoutStatus.open);
      expect(exact.id, _checkoutId);
      expect(confirmed.planCode, DemoPlanCode.premiumDemo);
      expect(restored.planCode, DemoPlanCode.premiumDemo);
      expect(downgraded.planCode, DemoPlanCode.free);

      final create = harness.single('POST', '/v1/demo-checkout-sessions');
      expect(create.idempotencyKey, 'checkout-create-key-0001');
      expect(create.ifMatch, isNull);
      expect(create.body, {'plan_code': 'premium_demo'});

      final confirm = harness.single(
        'POST',
        '/v1/demo-checkout-sessions/$_checkoutId/confirm',
      );
      expect(confirm.idempotencyKey, 'checkout-confirm-key-001');
      expect(confirm.ifMatch, '"v3"');
      expect(confirm.body, isEmpty);

      final restore = harness.single('POST', '/v1/me/entitlements/restore');
      expect(restore.idempotencyKey, 'entitlement-restore-key1');
      expect(restore.ifMatch, isNull);
      expect(restore.body, isEmpty);

      final downgrade = harness.single('POST', '/v1/me/entitlements/downgrade');
      expect(downgrade.idempotencyKey, 'entitlement-downgrade-1');
      expect(downgrade.ifMatch, '"v6"');
      expect(downgrade.body, isEmpty);

      expect(
        harness.requests.every(
          (request) => request.authorization == 'Bearer u10-member-token',
        ),
        isTrue,
      );
      expect(
        harness.requests.every(
          (request) =>
              request.path.startsWith('/v1/') &&
              !RegExp(
                r'card|bank|billing|payment|purchase|provider|store[_-]?kit',
                caseSensitive: false,
              ).hasMatch(jsonEncode(request.body)),
        ),
        isTrue,
      );
    },
  );

  test('unknown and unsafe membership authority fails closed', () async {
    final harness = await _Harness.start();
    addTearDown(harness.close);
    final service = GeneratedEntitlementService(
      RitualInvestingApiClient(basePathOverride: harness.baseUrl),
    );

    for (final mode in [
      _Mode.unknownPlan,
      _Mode.unknownCapability,
      _Mode.duplicateCapability,
      _Mode.unsafePriceCopy,
      _Mode.nonDemo,
    ]) {
      harness.mode = mode;
      await expectLater(service.listPlans(), throwsA(_terminalFailure));
    }
    for (final mode in [
      _Mode.unknownEntitlementPlan,
      _Mode.unknownEntitlementStatus,
      _Mode.unknownSource,
      _Mode.invalidEntitlementVersion,
      _Mode.invalidEntitlementId,
    ]) {
      harness.mode = mode;
      await expectLater(service.getEntitlement(), throwsA(_terminalFailure));
    }
    for (final mode in [
      _Mode.unknownCheckoutStatus,
      _Mode.invalidCheckoutVersion,
      _Mode.checkoutIdMismatch,
    ]) {
      harness.mode = mode;
      await expectLater(
        service.getCheckout(_checkoutId),
        throwsA(_terminalFailure),
      );
    }
  });

  test(
    'invalid plan, key, version, and ID are rejected before traffic',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final service = GeneratedEntitlementService(
        RitualInvestingApiClient(basePathOverride: harness.baseUrl),
      );

      await expectLater(
        service.createCheckout('free', 'checkout-create-key-0001'),
        throwsA(_terminalFailure),
      );
      await expectLater(
        service.createCheckout('premium_demo', 'short'),
        throwsA(_terminalFailure),
      );
      await expectLater(
        service.confirmCheckout(_checkoutId, 0, 'checkout-confirm-key-001'),
        throwsA(_terminalFailure),
      );
      await expectLater(
        service.getCheckout('not-a-uuid'),
        throwsA(_terminalFailure),
      );
      await expectLater(
        service.downgrade(0, 'entitlement-downgrade-1'),
        throwsA(_terminalFailure),
      );

      expect(harness.requests, isEmpty);
    },
  );
}

final _terminalFailure = isA<LoadFailure>().having(
  (failure) => failure.phase,
  'phase',
  LoadPhase.terminalFailure,
);

enum _Mode {
  valid,
  unknownPlan,
  unknownCapability,
  duplicateCapability,
  unsafePriceCopy,
  nonDemo,
  unknownEntitlementPlan,
  unknownEntitlementStatus,
  unknownSource,
  invalidEntitlementVersion,
  invalidEntitlementId,
  unknownCheckoutStatus,
  invalidCheckoutVersion,
  checkoutIdMismatch,
}

class _Harness {
  _Harness._(this.server);

  final HttpServer server;
  final List<_Request> requests = [];
  _Mode mode = _Mode.valid;

  String get baseUrl => 'http://${server.address.address}:${server.port}';

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final harness = _Harness._(server);
    harness._serve();
    return harness;
  }

  _Request single(String method, String path) => requests.singleWhere(
    (request) => request.method == method && request.path == path,
  );

  Future<void> _serve() async {
    await for (final request in server) {
      final raw = await utf8.decoder.bind(request).join();
      final body = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      requests.add(
        _Request(
          method: request.method,
          path: request.uri.path,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          ifMatch: request.headers.value(HttpHeaders.ifMatchHeader),
          body: body,
        ),
      );
      request.response.headers.contentType = ContentType.json;
      final path = request.uri.path;
      if (path == '/v1/demo-plans') {
        request.response.write(
          jsonEncode({'data': _plans(mode), 'meta': _meta}),
        );
      } else if (path == '/v1/me/entitlements' && request.method == 'GET') {
        request.response.write(
          jsonEncode({'data': _entitlement(mode), 'meta': _meta}),
        );
      } else if (path == '/v1/demo-checkout-sessions') {
        request.response.statusCode = HttpStatus.created;
        request.response.write(
          jsonEncode({'data': _checkout(mode), 'meta': _meta}),
        );
      } else if (path == '/v1/demo-checkout-sessions/$_checkoutId') {
        request.response.write(
          jsonEncode({'data': _checkout(mode), 'meta': _meta}),
        );
      } else if (path.endsWith('/confirm')) {
        request.response.write(
          jsonEncode({
            'data': _entitlement(_Mode.valid, plan: 'premium_demo', version: 6),
            'meta': _meta,
          }),
        );
      } else if (path == '/v1/me/entitlements/restore') {
        request.response.write(
          jsonEncode({
            'data': _entitlement(_Mode.valid, plan: 'premium_demo', version: 6),
            'meta': _meta,
          }),
        );
      } else if (path == '/v1/me/entitlements/downgrade') {
        request.response.write(
          jsonEncode({
            'data': _entitlement(_Mode.valid, version: 7),
            'meta': _meta,
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode(_error));
      }
      await request.response.close();
    }
  }

  Future<void> close() => server.close(force: true);
}

class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.authorization,
    required this.idempotencyKey,
    required this.ifMatch,
    required this.body,
  });

  final String method;
  final String path;
  final String? authorization;
  final String? idempotencyKey;
  final String? ifMatch;
  final Map<String, dynamic> body;
}

class _Token implements AccessTokenProvider {
  const _Token();

  @override
  Future<String?> accessToken() async => 'u10-member-token';
}

List<Map<String, Object?>> _plans(_Mode mode) => [
  {
    'code': 'free',
    'display_name': 'Ritual Free Demo',
    'price_copy': mode == _Mode.unsafePriceCopy
        ? r'$9.99 per month'
        : 'No charge — simulated access only',
    'feature_codes': ['daily_ritual', 'demo_portfolio'],
    'demo': _demo(mode),
  },
  {
    'code': mode == _Mode.unknownPlan ? 'enterprise' : 'premium_demo',
    'display_name': 'Ritual Premium Demo',
    'price_copy': 'Illustrative premium access — no charge',
    'feature_codes': mode == _Mode.unknownCapability
        ? ['daily_ritual', 'broker_trading']
        : mode == _Mode.duplicateCapability
        ? ['future_mirror', 'future_mirror']
        : ['daily_ritual', 'demo_portfolio', 'future_mirror'],
    'demo': _demo(mode),
  },
];

Map<String, Object?> _entitlement(
  _Mode mode, {
  String plan = 'free',
  int version = 5,
}) => {
  'id': mode == _Mode.invalidEntitlementId ? 'not-a-uuid' : _entitlementId,
  'plan_code': mode == _Mode.unknownEntitlementPlan ? 'enterprise' : plan,
  'status': mode == _Mode.unknownEntitlementStatus ? 'paused' : 'active',
  'source': mode == _Mode.unknownSource ? 'app_store' : 'demo',
  'starts_at': '2026-08-01T00:00:00.000Z',
  'ends_at': null,
  'version': mode == _Mode.invalidEntitlementVersion ? 0 : version,
  'demo': _demo(mode),
};

Map<String, Object?> _checkout(_Mode mode) => {
  'id': mode == _Mode.checkoutIdMismatch ? _otherId : _checkoutId,
  'plan_code': 'premium_demo',
  'status': mode == _Mode.unknownCheckoutStatus ? 'pending' : 'open',
  'expires_at': '2026-08-25T13:00:00.000Z',
  'version': mode == _Mode.invalidCheckoutVersion ? 0 : 3,
  'demo': _demo(mode),
};

Map<String, Object?> _demo(_Mode mode) => {
  'is_demo': mode != _Mode.nonDemo,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Ritual deterministic Demo',
  'limitations': [
    'No money moves and no external financial provider is contacted.',
    'Demo outcomes are not advice or a guarantee.',
  ],
};

const _meta = {'request_id': _requestId};
const _error = {
  'error': {
    'code': 'not_found',
    'field_errors': <Object?>[],
    'message': 'Not found.',
    'request_id': _requestId,
    'retryable': false,
  },
};
const _requestId = '00000000-0000-4000-8000-000000000001';
const _checkoutId = '22222222-2222-4222-8222-222222222222';
const _entitlementId = '33333333-3333-4333-8333-333333333333';
const _otherId = '44444444-4444-4444-8444-444444444444';
