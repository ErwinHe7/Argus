import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_api_client/ritual_auth_interceptor.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';
import 'package:ritual_investing_app/core/api/view_state.dart';
import 'package:ritual_investing_app/features/briefings/data/generated_briefing_api_service.dart';
import 'package:ritual_investing_app/features/briefings/domain/model.dart';
import 'package:ritual_investing_app/features/notifications/data/generated_notification_api_service.dart';
import 'package:ritual_investing_app/features/notifications/domain/model.dart';

void main() {
  test('U9 generated Dio adapters serialize exact in-app contracts', () async {
    final harness = await _Harness.start();
    addTearDown(harness.close);
    final client = RitualInvestingApiClient(
      basePathOverride: harness.baseUrl,
      interceptors: [RitualAuthInterceptor(tokenProvider: const _Token())],
    );
    final briefings = GeneratedBriefingService(client);
    final notifications = GeneratedNotificationService(client);

    final page = await briefings.list(
      type: BriefingType.weekly,
      periodStart: DateTime.utc(2026, 8, 18),
      periodEnd: DateTime.utc(2026, 8, 25),
      cursor: 'briefing-page-2',
    );
    final detail = await briefings.get(_briefingId);
    final pending = await briefings.daily(DateTime.utc(2026, 8, 25));
    final readBriefing = await briefings.setRead(_briefingId, true);

    final noticePage = await notifications.list(
      filter: NotificationReadFilter.unread,
      cursor: 'notification-page-2',
    );
    final preferences = await notifications.getPreferences();
    const draft = NotificationPreferencesDraft(
      dailyRitual: false,
      weeklyRecap: true,
      moonCycle: false,
      quietHours: NotificationQuietHours(
        enabled: true,
        start: '22:00',
        end: '07:00',
        timezone: 'America/New_York',
      ),
    );
    final patched = await notifications.patchPreferences(draft, 3);
    final readNotice = await notifications.setRead(_notificationId, true);
    final count = await notifications.readAll(
      NotificationReadAll(
        before: DateTime.utc(2026, 8, 25, 12),
        idempotencyKey: 'u9-read-all-key-000001',
      ),
    );

    expect(page.items.single.type, BriefingType.weekly);
    expect(detail.sections.single.disclosure, contains('Demo'));
    expect(pending.isPending, isTrue);
    expect(pending.pendingDate, DateTime.utc(2026, 8, 25));
    expect(readBriefing.isRead, isTrue);
    expect(
      noticePage.items.single.destination?.location,
      '/ritual/briefings/$_briefingId',
    );
    expect(preferences.version, 3);
    expect(patched.version, 4);
    expect(readNotice.isRead, isTrue);
    expect(count, 1);

    final briefingList = harness.single('GET', '/v1/briefings');
    expect(briefingList.query, {
      'type': 'weekly',
      'period_start': '2026-08-18',
      'period_end': '2026-08-25',
      'limit': '20',
      'cursor': 'briefing-page-2',
    });
    expect(
      harness.single('GET', '/v1/briefings/daily').query['local_date'],
      '2026-08-25',
    );
    expect(
      harness.single('PUT', '/v1/briefings/$_briefingId/read-state').body,
      {'read': true},
    );
    expect(harness.single('GET', '/v1/notifications').query, {
      'read': 'unread',
      'limit': '20',
      'cursor': 'notification-page-2',
    });
    final patch = harness.single('PATCH', '/v1/me/notification-preferences');
    expect(patch.ifMatch, '"v3"');
    expect(patch.body, {
      'daily_ritual': false,
      'weekly_recap': true,
      'moon_cycle': false,
      'quiet_hours': {
        'enabled': true,
        'start': '22:00',
        'end': '07:00',
        'timezone': 'America/New_York',
      },
    });
    expect(
      harness
          .single('PUT', '/v1/notifications/$_notificationId/read-state')
          .body,
      {'read': true},
    );
    final readAll = harness.single('POST', '/v1/notifications/read-all');
    expect(readAll.idempotencyKey, 'u9-read-all-key-000001');
    expect(readAll.body, {'before': '2026-08-25T12:00:00.000Z'});
    expect(
      harness.requests.every(
        (request) => request.authorization == 'Bearer u9-member-token',
      ),
      isTrue,
    );
    expect(
      harness.requests.every(
        (request) =>
            !request.path.startsWith('/v1/me/devices') &&
            !RegExp(
              r'push|token|provider|delivery',
              caseSensitive: false,
            ).hasMatch(request.path),
      ),
      isTrue,
    );
  });

  test('malformed U9 generated socket responses fail closed', () async {
    final harness = await _Harness.start();
    addTearDown(harness.close);
    final client = RitualInvestingApiClient(basePathOverride: harness.baseUrl);
    final briefings = GeneratedBriefingService(client);
    final notifications = GeneratedNotificationService(client);

    for (final mode in [
      _Mode.unknownBriefingType,
      _Mode.inconsistentBriefingCursor,
    ]) {
      harness.mode = mode;
      await expectLater(briefings.list(), throwsA(_terminalFailure));
    }
    for (final mode in [
      _Mode.detailIdMismatch,
      _Mode.unknownSection,
      _Mode.extraSectionPayload,
      _Mode.sectionSourceMismatch,
    ]) {
      harness.mode = mode;
      await expectLater(briefings.get(_briefingId), throwsA(_terminalFailure));
    }
    harness.mode = _Mode.pendingDateMismatch;
    await expectLater(
      briefings.daily(DateTime.utc(2026, 8, 25)),
      throwsA(_terminalFailure),
    );
    harness.mode = _Mode.briefingReadEchoMismatch;
    await expectLater(
      briefings.setRead(_briefingId, true),
      throwsA(_terminalFailure),
    );

    for (final mode in [
      _Mode.unknownNotificationKind,
      _Mode.externalNotificationRoute,
      _Mode.inconsistentNotificationCursor,
    ]) {
      harness.mode = mode;
      await expectLater(notifications.list(), throwsA(_terminalFailure));
    }
    harness.mode = _Mode.notificationReadEchoMismatch;
    await expectLater(
      notifications.setRead(_notificationId, true),
      throwsA(_terminalFailure),
    );
    for (final mode in [
      _Mode.preferenceEchoMismatch,
      _Mode.preferenceVersionNotAdvanced,
    ]) {
      harness.mode = mode;
      await expectLater(
        notifications.patchPreferences(_draft, 3),
        throwsA(_terminalFailure),
      );
    }
    harness.mode = _Mode.readAllCountTooHigh;
    await expectLater(
      notifications.readAll(
        NotificationReadAll(
          before: DateTime.utc(2026, 8, 25, 12),
          idempotencyKey: 'u9-read-all-key-000001',
        ),
      ),
      throwsA(_terminalFailure),
    );
  });

  test(
    'briefing date query rejects non-date equivalents before traffic',
    () async {
      final harness = await _Harness.start();
      addTearDown(harness.close);
      final service = GeneratedBriefingService(
        RitualInvestingApiClient(basePathOverride: harness.baseUrl),
      );

      for (final invalid in [
        DateTime(2026, 8, 25),
        DateTime.utc(2026, 8, 25, 1),
        DateTime.parse('2026-08-25T00:00:00-04:00'),
      ]) {
        await expectLater(service.daily(invalid), throwsA(_terminalFailure));
      }
      expect(harness.requests, isEmpty);
    },
  );
}

final _terminalFailure = isA<LoadFailure>().having(
  (failure) => failure.phase,
  'phase',
  LoadPhase.terminalFailure,
);

const _draft = NotificationPreferencesDraft(
  dailyRitual: false,
  weeklyRecap: true,
  moonCycle: false,
  quietHours: NotificationQuietHours(
    enabled: true,
    start: '22:00',
    end: '07:00',
    timezone: 'America/New_York',
  ),
);

enum _Mode {
  valid,
  unknownBriefingType,
  inconsistentBriefingCursor,
  detailIdMismatch,
  unknownSection,
  extraSectionPayload,
  sectionSourceMismatch,
  pendingDateMismatch,
  briefingReadEchoMismatch,
  unknownNotificationKind,
  externalNotificationRoute,
  inconsistentNotificationCursor,
  notificationReadEchoMismatch,
  preferenceEchoMismatch,
  preferenceVersionNotAdvanced,
  readAllCountTooHigh,
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
      final rawBody = await utf8.decoder.bind(request).join();
      final body = rawBody.isEmpty
          ? null
          : jsonDecode(rawBody) as Map<String, dynamic>;
      requests.add(
        _Request(
          method: request.method,
          path: request.uri.path,
          query: request.uri.queryParameters,
          authorization: request.headers.value(HttpHeaders.authorizationHeader),
          idempotencyKey: request.headers.value('idempotency-key'),
          ifMatch: request.headers.value(HttpHeaders.ifMatchHeader),
          body: body,
        ),
      );
      request.response.headers.contentType = ContentType.json;
      final path = request.uri.path;
      if (request.method == 'GET' && path == '/v1/briefings') {
        request.response.write(
          jsonEncode({
            'data': [_briefingSummary(mode)],
            'meta': _collectionMeta(
              inconsistent: mode == _Mode.inconsistentBriefingCursor,
            ),
          }),
        );
      } else if (request.method == 'GET' && path == '/v1/briefings/daily') {
        request.response.statusCode = HttpStatus.accepted;
        request.response.write(
          jsonEncode({
            'data': {
              'status': 'briefing_pending',
              'local_date': mode == _Mode.pendingDateMismatch
                  ? '2026-08-24'
                  : '2026-08-25',
            },
            'meta': _responseMeta,
          }),
        );
      } else if (path == '/v1/briefings/$_briefingId/read-state') {
        request.response.write(
          jsonEncode({
            'data': _briefingSummary(
              mode,
              read: mode != _Mode.briefingReadEchoMismatch,
            ),
            'meta': _responseMeta,
          }),
        );
      } else if (path == '/v1/briefings/$_briefingId') {
        request.response.write(
          jsonEncode({'data': _briefingDetail(mode), 'meta': _responseMeta}),
        );
      } else if (request.method == 'GET' && path == '/v1/notifications') {
        request.response.write(
          jsonEncode({
            'data': [_notification(mode)],
            'meta': _collectionMeta(
              inconsistent: mode == _Mode.inconsistentNotificationCursor,
            ),
          }),
        );
      } else if (path == '/v1/notifications/$_notificationId/read-state') {
        request.response.write(
          jsonEncode({
            'data': _notification(
              mode,
              read: mode != _Mode.notificationReadEchoMismatch,
            ),
            'meta': _responseMeta,
          }),
        );
      } else if (path == '/v1/me/notification-preferences') {
        request.response.write(
          jsonEncode({
            'data': _preferences(mode, patched: request.method == 'PATCH'),
            'meta': _responseMeta,
          }),
        );
      } else if (path == '/v1/notifications/read-all') {
        request.response.write(
          jsonEncode({
            'data': {
              'updated_count': mode == _Mode.readAllCountTooHigh ? 101 : 1,
            },
            'meta': _responseMeta,
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode(_error('not_found')));
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
    required this.query,
    required this.authorization,
    required this.idempotencyKey,
    required this.ifMatch,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final String? authorization;
  final String? idempotencyKey;
  final String? ifMatch;
  final Map<String, dynamic>? body;
}

class _Token implements AccessTokenProvider {
  const _Token();

  @override
  Future<String?> accessToken() async => 'u9-member-token';
}

Map<String, Object?> _briefingSummary(_Mode mode, {bool read = false}) => {
  'id': mode == _Mode.detailIdMismatch ? _foreignId : _briefingId,
  'briefing_type': mode == _Mode.unknownBriefingType ? 'seasonal' : 'weekly',
  'period_start': '2026-08-18',
  'period_end': '2026-08-25',
  'generation': 1,
  'source_sequence': 14,
  'generated_at': '2026-08-25T12:00:00.000Z',
  'read_at': read ? '2026-08-25T12:01:00.000Z' : null,
};

Map<String, Object?> _briefingDetail(_Mode mode) => {
  ..._briefingSummary(mode),
  'sections': [
    {
      'section_type': mode == _Mode.unknownSection ? 'prediction' : 'summary',
      'ordinal': 1,
      'schema_version': 1,
      'payload': {
        'source_sequence': mode == _Mode.sectionSourceMismatch ? 13 : 14,
        'disclosure': 'Recorded Demo reflection; not financial advice.',
        if (mode == _Mode.extraSectionPayload) 'model': 'invented',
      },
    },
  ],
};

Map<String, Object?> _notification(_Mode mode, {bool read = false}) => {
  'id': _notificationId,
  'kind': mode == _Mode.unknownNotificationKind
      ? 'provider_connected'
      : 'briefing_ready',
  'title': 'Your briefing is ready',
  'body': 'Open Ritual to review the recorded recap.',
  'deep_link': mode == _Mode.externalNotificationRoute
      ? 'https://provider.example'
      : '/briefings/$_briefingId',
  'scheduled_at': '2026-08-25T12:00:00.000Z',
  'read_at': read ? '2026-08-25T12:01:00.000Z' : null,
};

Map<String, Object?> _preferences(_Mode mode, {required bool patched}) => {
  'daily_ritual': patched && mode != _Mode.preferenceEchoMismatch
      ? false
      : true,
  'weekly_recap': true,
  'moon_cycle': patched ? false : true,
  'quiet_hours': patched
      ? {
          'enabled': true,
          'start': '22:00',
          'end': '07:00',
          'timezone': 'America/New_York',
        }
      : {'enabled': false, 'start': '22:00', 'end': '07:00', 'timezone': 'UTC'},
  'version': patched && mode != _Mode.preferenceVersionNotAdvanced ? 4 : 3,
};

Map<String, Object?> _collectionMeta({required bool inconsistent}) => {
  'has_more': inconsistent,
  'next_cursor': null,
  'request_id': _requestId,
};

const _responseMeta = {'request_id': _requestId};

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
const _foreignId = '00000000-0000-4000-8000-000000000099';
