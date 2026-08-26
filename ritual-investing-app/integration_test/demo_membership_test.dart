import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/entitlements/application/entitlement_controller.dart';
import 'package:ritual_investing_app/features/entitlements/data/generated_entitlement_api_service.dart';
import 'package:ritual_investing_app/features/entitlements/data/repository.dart';
import 'package:ritual_investing_app/features/entitlements/domain/model.dart';
import 'package:ritual_investing_app/features/entitlements/presentation/demo_membership_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'loopback member upgrades, relaunches, restores, and downgrades without provider traffic',
    (tester) async {
      late _Harness harness;
      await tester.runAsync(() async => harness = await _Harness.start());
      addTearDown(harness.close);
      final flow = _FlowApp(harness);
      await tester.pumpWidget(flow);
      await tester.pumpAndSettle();

      expect(find.text('FUTURE MIRROR MEMBER CONTENT'), findsNothing);
      await _tapVisible(
        tester,
        find.byKey(const Key('capability-open-membership')),
      );
      expect(find.text('Open Future Mirror'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const Key('membership-choose-premium')),
      );
      expect(find.text('Review Demo checkout'), findsOneWidget);
      expect(find.textContaining('no card'), findsWidgets);
      await _tapVisible(
        tester,
        find.byKey(const Key('membership-confirm-checkout')),
      );

      expect(find.text('Premium Demo access is active'), findsOneWidget);
      expect(find.textContaining('Receipt amount: No charge'), findsOneWidget);
      await _tapVisible(
        tester,
        find.byKey(const Key('membership-return-to-capability')),
      );
      expect(find.text('FUTURE MIRROR MEMBER CONTENT'), findsOneWidget);
      expect(find.textContaining('/future-mirror'), findsNothing);

      final secondDevice = _controller(harness, accountId: 'u10-device-b');
      await tester.runAsync(secondDevice.load);
      addTearDown(secondDevice.dispose);
      expect(
        secondDevice.gate(DemoCapability.futureMirror).isAllowed,
        isTrue,
        reason: 'another device reads the same server entitlement',
      );

      await _tapVisible(tester, find.byKey(const Key('u10-open-membership')));
      await _tapVisible(
        tester,
        find.byKey(const Key('membership-prepare-downgrade')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('membership-confirm-downgrade')),
      );
      expect(harness.entitlementPlan, 'free');

      await _tapVisible(tester, find.byKey(const Key('membership-restore')));
      expect(harness.entitlementPlan, 'free');

      final create = harness.single('POST', '/v1/demo-checkout-sessions');
      expect(create.idempotencyKey, isNotNull);
      expect(create.body, {'plan_code': 'premium_demo'});
      final confirm = harness.single(
        'POST',
        '/v1/demo-checkout-sessions/$_checkoutId/confirm',
      );
      expect(confirm.ifMatch, '"v1"');
      expect(confirm.idempotencyKey, isNotNull);
      expect(confirm.body, isEmpty);
      final downgrade = harness.single('POST', '/v1/me/entitlements/downgrade');
      expect(downgrade.ifMatch, '"v2"');
      expect(downgrade.idempotencyKey, isNotNull);
      final restore = harness.single('POST', '/v1/me/entitlements/restore');
      expect(restore.idempotencyKey, isNotNull);

      expect(
        harness.requests.every(
          (request) =>
              request.authorization == 'Bearer u10-integration-member' &&
              request.path.startsWith('/v1/') &&
              !RegExp(
                r'card|bank|billing|payment|purchase|provider|store[_-]?kit',
                caseSensitive: false,
              ).hasMatch(request.rawBody),
        ),
        isTrue,
      );
    },
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  final vertical = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );
  for (var attempt = 0; attempt < 14; attempt++) {
    if (finder.hitTestable().evaluate().isNotEmpty) break;
    if (vertical.evaluate().isNotEmpty) {
      await tester.drag(vertical.last, const Offset(0, -320));
      await tester.pumpAndSettle();
    }
  }
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

class _FlowApp extends StatefulWidget {
  const _FlowApp(this.harness);

  final _Harness harness;

  @override
  State<_FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<_FlowApp> {
  late final EntitlementController controller = _controller(
    widget.harness,
    accountId: 'u10-device-a',
  );
  String? returnedLocation;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _openMembership(
    BuildContext context, {
    DemoCapability? capability,
    String? returnLocation,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (membershipContext) => MembershipPlansScreen(
          controller: controller,
          requestedCapability: capability,
          returnLocation: returnLocation,
          onOpenCheckout: (sessionId) => Navigator.of(membershipContext).push(
            MaterialPageRoute(
              builder: (checkoutContext) => DemoCheckoutScreen(
                sessionId: sessionId,
                controller: controller,
                onCancel: () => Navigator.of(checkoutContext).pop(),
                onReceipt: () => Navigator.of(checkoutContext).pushReplacement(
                  MaterialPageRoute(
                    builder: (receiptContext) => DemoMembershipReceiptScreen(
                      sessionId: sessionId,
                      controller: controller,
                      onContinue: (location) {
                        returnedLocation = location;
                        Navigator.of(receiptContext)
                            .popUntil((route) => route.isFirst);
                        setState(() {});
                      },
                      onBackToMembership: () =>
                          Navigator.of(receiptContext).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Builder(
      builder: (context) => DemoCapabilityGate(
        controller: controller,
        capability: DemoCapability.futureMirror,
        returnLocation: _futureMirrorLocation,
        onOpenMembership: () => _openMembership(
          context,
          capability: DemoCapability.futureMirror,
          returnLocation: _futureMirrorLocation,
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('U10 member experience')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('FUTURE MIRROR MEMBER CONTENT'),
                const SizedBox(height: 12),
                if (returnedLocation != null)
                  const Text('Returned to the requested member capability'),
                FilledButton(
                  key: const Key('u10-open-membership'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _openMembership(context),
                  child: const Text('Open Demo membership'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

EntitlementController _controller(
  _Harness harness, {
  required String accountId,
}) {
  var key = 0;
  return EntitlementController(
    repository: CachedEntitlementRepository(
      service: GeneratedEntitlementService(harness.client),
      cache: MemoryReadCache(),
    ),
    pendingStore: PendingCommandStore(storage: _Storage()),
    scope: CacheScope(accountId: accountId, resetGeneration: 10),
    createKey: () => 'u10-integration-command-${++key}',
    now: () => DateTime.utc(2026, 8, 25, 12),
    personalization: const MemberPersonalization(
      explanationDepth: MemberExplanationDepth.advanced,
      ritualVoice: MemberRitualVoice.mystical,
    ),
  );
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

class _Harness {
  _Harness._(this.server, this.client);

  final HttpServer server;
  final RitualInvestingApiClient client;
  final List<_Request> requests = [];
  String entitlementPlan = 'free';
  String entitlementId = _freeEntitlementId;
  int entitlementVersion = 1;
  String checkoutStatus = 'open';
  int checkoutVersion = 1;

  static Future<_Harness> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: [RitualAuthInterceptor(tokenProvider: const _Token())],
    );
    final harness = _Harness._(server, client);
    unawaited(harness._serve());
    return harness;
  }

  _Request single(String method, String path) => requests.singleWhere(
    (request) => request.method == method && request.path == path,
  );

  Future<void> _serve() async {
    await for (final request in server) {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(rawBody) as Map<String, dynamic>;
      requests.add(
        _Request(
          method: request.method,
          path: request.uri.path,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          ifMatch: request.headers.value(HttpHeaders.ifMatchHeader),
          body: body,
          rawBody: rawBody,
        ),
      );
      request.response.headers.contentType = ContentType.json;
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/v1/demo-plans') {
        request.response.write(jsonEncode({'data': _plans, 'meta': _meta}));
      } else if (request.method == 'GET' && path == '/v1/me/entitlements') {
        request.response.write(
          jsonEncode({'data': _entitlement(), 'meta': _meta}),
        );
      } else if (request.method == 'POST' &&
          path == '/v1/demo-checkout-sessions') {
        request.response.statusCode = HttpStatus.created;
        request.response.write(
          jsonEncode({'data': _checkout(), 'meta': _meta}),
        );
      } else if (request.method == 'GET' &&
          path == '/v1/demo-checkout-sessions/$_checkoutId') {
        request.response.write(
          jsonEncode({'data': _checkout(), 'meta': _meta}),
        );
      } else if (request.method == 'POST' && path.endsWith('/confirm')) {
        checkoutStatus = 'completed';
        checkoutVersion = 2;
        entitlementPlan = 'premium_demo';
        entitlementId = _premiumEntitlementId;
        entitlementVersion = 2;
        request.response.write(
          jsonEncode({'data': _entitlement(), 'meta': _meta}),
        );
      } else if (request.method == 'POST' &&
          path == '/v1/me/entitlements/downgrade') {
        entitlementPlan = 'free';
        entitlementId = _downgradedEntitlementId;
        entitlementVersion = 3;
        request.response.write(
          jsonEncode({'data': _entitlement(), 'meta': _meta}),
        );
      } else if (request.method == 'POST' &&
          path == '/v1/me/entitlements/restore') {
        request.response.write(
          jsonEncode({'data': _entitlement(), 'meta': _meta}),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode(_error));
      }
      await request.response.close();
    }
  }

  Map<String, Object?> _entitlement() => {
    'id': entitlementId,
    'plan_code': entitlementPlan,
    'status': 'active',
    'source': 'demo',
    'starts_at': '2026-08-25T12:00:00.000Z',
    'ends_at': null,
    'version': entitlementVersion,
    'demo': _demo,
  };

  Map<String, Object?> _checkout() => {
    'id': _checkoutId,
    'plan_code': 'premium_demo',
    'status': checkoutStatus,
    'expires_at': '2026-08-25T13:00:00.000Z',
    'version': checkoutVersion,
    'demo': _demo,
  };

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
    required this.rawBody,
  });

  final String method;
  final String path;
  final String? authorization;
  final String? idempotencyKey;
  final String? ifMatch;
  final Map<String, dynamic> body;
  final String rawBody;
}

class _Token implements AccessTokenProvider {
  const _Token();

  @override
  Future<String?> accessToken() async => 'u10-integration-member';
}

const _futureMirrorLocation =
    '/you/portfolios/portfolio-a/intentions/11111111-1111-4111-8111-111111111111/future-mirror';
const _checkoutId = '22222222-2222-4222-8222-222222222222';
const _freeEntitlementId = '33333333-3333-4333-8333-333333333331';
const _premiumEntitlementId = '33333333-3333-4333-8333-333333333332';
const _downgradedEntitlementId = '33333333-3333-4333-8333-333333333333';
const _requestId = '00000000-0000-4000-8000-000000000001';
const _meta = {'request_id': _requestId};
const _demo = {
  'is_demo': true,
  'observed_at': '2026-08-25T12:00:00.000Z',
  'source_label': 'Ritual deterministic Demo',
  'limitations': [
    'No money moves and no external financial provider is contacted.',
    'Demo outcomes are not advice or a guarantee.',
  ],
};
const _plans = [
  {
    'code': 'free',
    'display_name': 'Ritual Free Demo',
    'price_copy': 'No charge — simulated access only',
    'feature_codes': ['daily_ritual', 'demo_portfolio'],
    'demo': _demo,
  },
  {
    'code': 'premium_demo',
    'display_name': 'Ritual Premium Demo',
    'price_copy': 'Illustrative premium access — no charge',
    'feature_codes': ['daily_ritual', 'demo_portfolio', 'future_mirror'],
    'demo': _demo,
  },
];
const _error = {
  'error': {
    'code': 'not_found',
    'field_errors': <Object?>[],
    'message': 'Not found.',
    'request_id': _requestId,
    'retryable': false,
  },
};
