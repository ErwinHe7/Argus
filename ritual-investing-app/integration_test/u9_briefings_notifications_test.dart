import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/app/theme/app_theme.dart';
import 'package:ritual_investing_app/core/api/invalidation_bus.dart';
import 'package:ritual_investing_app/core/api/pending_command_store.dart';
import 'package:ritual_investing_app/core/bootstrap/member_bootstrap.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/briefings/application/briefing_controller.dart';
import 'package:ritual_investing_app/features/briefings/data/generated_briefing_api_service.dart';
import 'package:ritual_investing_app/features/briefings/data/repository.dart';
import 'package:ritual_investing_app/features/briefings/presentation/briefing_screen.dart';
import 'package:ritual_investing_app/features/notifications/application/notification_controller.dart';
import 'package:ritual_investing_app/features/notifications/data/generated_notification_api_service.dart';
import 'package:ritual_investing_app/features/notifications/data/repository.dart';
import 'package:ritual_investing_app/features/notifications/presentation/notification_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'loopback member reviews personalized recaps and in-app-only notices',
    (tester) async {
      late _Harness harness;
      await tester.runAsync(() async => harness = await _Harness.start());
      addTearDown(harness.close);
      await tester.pumpWidget(_FlowApp(harness));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('u9-open-briefings')));
      await _pumpUntil(
        tester,
        () => find.text('Moon-cycle recap').evaluate().isNotEmpty,
      );
      expect(find.textContaining('Symbolic reflection'), findsOneWidget);
      expect(find.text('Moon-cycle recap'), findsOneWidget);
      await _tapVisible(tester, find.text('Moon-cycle recap'));
      await _pumpUntil(
        tester,
        () => find.textContaining('summary v1').evaluate().isNotEmpty,
      );
      expect(find.textContaining('summary v1'), findsOneWidget);
      expect(find.text('Source sequence 44'), findsOneWidget);
      expect(find.textContaining('not financial advice'), findsWidgets);
      await _tapVisible(tester, find.byKey(const Key('briefing-read-toggle')));
      await _pumpUntil(
        tester,
        () => harness.has('PUT', '/v1/briefings/$_briefingId/read-state'),
      );
      expect(
        harness.single('PUT', '/v1/briefings/$_briefingId/read-state').body,
        {'read': true},
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('u9-open-notifications')));
      await _pumpUntil(
        tester,
        () => find.textContaining('In-app only').evaluate().isNotEmpty,
      );
      expect(find.textContaining('Symbolic inbox'), findsOneWidget);
      expect(find.textContaining('In-app only'), findsOneWidget);
      expect(find.textContaining('push token'), findsNothing);
      expect(find.textContaining('device registration'), findsNothing);
      await _tapVisible(
        tester,
        find.byKey(const Key('notifications-preferences')),
      );
      await _tapVisible(tester, find.byKey(const Key('preference-daily')));
      await _tapVisible(
        tester,
        find.byKey(const Key('notification-preferences-save')),
      );
      await _pumpUntil(
        tester,
        () => harness.has('PATCH', '/v1/me/notification-preferences'),
      );
      final patch = harness.single('PATCH', '/v1/me/notification-preferences');
      expect(patch.ifMatch, '"v3"');
      expect(patch.body?['daily_ritual'], isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.byKey(const Key('notifications-read-all')),
      );
      expect(
        find.byKey(const Key('notifications-confirm-read-all')),
        findsOneWidget,
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('notifications-confirm-read-all')),
      );
      await _pumpUntil(
        tester,
        () => harness.has('POST', '/v1/notifications/read-all'),
      );
      final readAll = harness.single('POST', '/v1/notifications/read-all');
      expect(readAll.idempotencyKey, 'u9-integration-read-all');
      expect(readAll.body, {'before': '2026-08-25T12:00:00.000Z'});

      expect(
        harness.requests.every(
          (request) =>
              request.authorization == 'Bearer u9-integration-member' &&
              !request.path.startsWith('/v1/me/devices') &&
              !RegExp(
                r'push|token|provider|delivery',
                caseSensitive: false,
              ).hasMatch('${request.path} ${request.rawBody}'),
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
  if (vertical.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: vertical.last);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for loopback UI state.',
  );
  await tester.pumpAndSettle();
}

class _FlowApp extends StatefulWidget {
  const _FlowApp(this.harness);

  final _Harness harness;

  @override
  State<_FlowApp> createState() => _FlowAppState();
}

class _FlowAppState extends State<_FlowApp> {
  static const scope = CacheScope(accountId: 'u9-account', resetGeneration: 9);
  late final InvalidationBus bus = InvalidationBus();
  late final BriefingController briefings = BriefingController(
    repository: CachedBriefingRepository(
      service: GeneratedBriefingService(widget.harness.client),
      cache: MemoryReadCache(),
    ),
    invalidationBus: bus,
    scope: scope,
    personalization: const MemberPersonalization(
      ritualVoice: MemberRitualVoice.mystical,
    ),
  );
  late final NotificationController notifications = NotificationController(
    repository: CachedNotificationRepository(
      service: GeneratedNotificationService(widget.harness.client),
      cache: MemoryReadCache(),
    ),
    pendingStore: PendingCommandStore(storage: _Storage()),
    invalidationBus: bus,
    scope: scope,
    createKey: () => 'u9-integration-read-all',
    now: () => DateTime.utc(2026, 8, 25, 12),
    personalization: const MemberPersonalization(
      ritualVoice: MemberRitualVoice.mystical,
    ),
  );

  @override
  void dispose() {
    briefings.dispose();
    notifications.dispose();
    unawaited(bus.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: _Hub(briefings: briefings, notifications: notifications),
  );
}

class _Hub extends StatelessWidget {
  const _Hub({required this.briefings, required this.notifications});

  final BriefingController briefings;
  final NotificationController notifications;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('U9 member experience')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              key: const Key('u9-open-briefings'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BriefingsScreen(
                    controller: briefings,
                    onOpenBriefing: (briefingId) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BriefingDetailScreen(
                          briefingId: briefingId,
                          controller: briefings,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open briefings'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('u9-open-notifications'),
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NotificationsScreen(
                    controller: notifications,
                    onOpenDestination: (_) {},
                    onOpenPreferences: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationPreferencesScreen(
                          controller: notifications,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open notices'),
            ),
          ],
        ),
      ),
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
  _Harness._(this.server, this.client, this._previousHttpOverrides);

  final HttpServer server;
  final RitualInvestingApiClient client;
  final HttpOverrides? _previousHttpOverrides;
  final List<_Request> requests = [];
  bool briefingRead = false;
  bool allRead = false;
  bool dailyEnabled = true;

  static Future<_Harness> start() async {
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    late final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } catch (_) {
      HttpOverrides.global = previousHttpOverrides;
      rethrow;
    }
    final client = RitualInvestingApiClient(
      basePathOverride: 'http://${server.address.address}:${server.port}',
      interceptors: [RitualAuthInterceptor(tokenProvider: const _Token())],
    );
    final harness = _Harness._(server, client, previousHttpOverrides);
    unawaited(harness._serve());
    return harness;
  }

  _Request single(String method, String path) => requests.singleWhere(
    (request) => request.method == method && request.path == path,
  );

  bool has(String method, String path) => requests.any(
    (request) => request.method == method && request.path == path,
  );

  Future<void> _serve() async {
    await for (final request in server) {
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.isEmpty
          ? null
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
      if (request.method == 'GET' && path == '/v1/briefings') {
        _json(request, {
          'data': [_briefing],
          'meta': _collectionMeta,
        });
      } else if (request.method == 'GET' &&
          path == '/v1/briefings/$_briefingId') {
        _json(request, {'data': _briefingDetail, 'meta': _meta});
      } else if (request.method == 'PUT' &&
          path == '/v1/briefings/$_briefingId/read-state') {
        briefingRead = body?['read'] == true;
        _json(request, {'data': _briefing, 'meta': _meta});
      } else if (request.method == 'GET' && path == '/v1/notifications') {
        _json(request, {
          'data': [_notification],
          'meta': _collectionMeta,
        });
      } else if (path == '/v1/me/notification-preferences') {
        if (request.method == 'PATCH') {
          dailyEnabled = body?['daily_ritual'] == true;
        }
        _json(request, {'data': _preferences, 'meta': _meta});
      } else if (request.method == 'POST' &&
          path == '/v1/notifications/read-all') {
        allRead = true;
        _json(request, {
          'data': {'updated_count': 1},
          'meta': _meta,
        });
      } else {
        request.response.statusCode = HttpStatus.notFound;
        _json(request, _error('not_found'));
      }
      await request.response.close();
    }
  }

  Map<String, Object?> get _briefing => {
    'id': _briefingId,
    'briefing_type': 'moon_cycle',
    'period_start': '2026-08-18',
    'period_end': '2026-08-25',
    'generation': 1,
    'source_sequence': 44,
    'generated_at': '2026-08-25T12:00:00.000Z',
    'read_at': briefingRead ? '2026-08-25T12:01:00.000Z' : null,
  };

  Map<String, Object?> get _briefingDetail => {
    ..._briefing,
    'sections': [
      {
        'section_type': 'summary',
        'ordinal': 1,
        'schema_version': 1,
        'payload': {
          'source_sequence': 44,
          'disclosure':
              'Recorded Demo reflection; not financial advice or a prediction.',
        },
      },
    ],
  };

  Map<String, Object?> get _notification => {
    'id': _notificationId,
    'kind': 'briefing_ready',
    'title': 'Your moon-cycle recap is ready',
    'body': 'Open Ritual to review the recorded Demo reflection.',
    'deep_link': '/briefings/$_briefingId',
    'scheduled_at': '2026-08-25T12:00:00.000Z',
    'read_at': allRead ? '2026-08-25T12:01:00.000Z' : null,
  };

  Map<String, Object?> get _preferences => {
    'daily_ritual': dailyEnabled,
    'weekly_recap': true,
    'moon_cycle': true,
    'quiet_hours': {
      'enabled': false,
      'start': '22:00',
      'end': '07:00',
      'timezone': 'UTC',
    },
    'version': dailyEnabled ? 3 : 4,
  };

  Future<void> close() async {
    client.dio.close(force: true);
    await server.close(force: true);
    HttpOverrides.global = _previousHttpOverrides;
  }
}

void _json(HttpRequest request, Map<String, Object?> value) =>
    request.response.write(jsonEncode(value));

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
  final Map<String, dynamic>? body;
  final String rawBody;
}

class _Token implements AccessTokenProvider {
  const _Token();

  @override
  Future<String?> accessToken() async => 'u9-integration-member';
}

const _meta = {'request_id': _requestId};
const _collectionMeta = {
  'has_more': false,
  'next_cursor': null,
  'request_id': _requestId,
};

Map<String, Object?> _error(String code) => {
  'error': {
    'code': code,
    'field_errors': <Object?>[],
    'message': 'Request could not be completed.',
    'request_id': _requestId,
    'retryable': false,
  },
};

const _requestId = '00000000-0000-4000-8000-000000000001';
const _briefingId = '00000000-0000-4000-8000-000000000091';
const _notificationId = '00000000-0000-4000-8000-000000000092';
