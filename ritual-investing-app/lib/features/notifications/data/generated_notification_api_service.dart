// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart';
import 'repository.dart';

class GeneratedNotificationService implements NotificationService {
  GeneratedNotificationService(api.RitualInvestingApiClient client)
    : _api = api.NotificationsApi(client.dio);

  final api.NotificationsApi _api;

  @override
  Future<NotificationPage> list({
    NotificationReadFilter filter = NotificationReadFilter.all,
    String? cursor,
  }) async {
    try {
      if (cursor != null) _terminal();
      final response = (await _api.listNotifications()).data!;
      final items = response.data
          .map(_item)
          .where(
            (item) => switch (filter) {
              NotificationReadFilter.all => true,
              NotificationReadFilter.read => item.isRead,
              NotificationReadFilter.unread => !item.isRead,
            },
          )
          .toList(growable: false);
      _requireUniqueIds(items.map((item) => item.id));
      return NotificationPage(items: items, hasMore: false, nextCursor: null);
    } on DioException catch (error) {
      _throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<NotificationPreferences> getPreferences() async {
    try {
      return _preferences((await _api.getNotificationPreferences()).data!.data);
    } on DioException catch (error) {
      _throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<NotificationItem> setRead(String notificationId, bool read) async {
    _requireUuid(notificationId);
    try {
      final result = _item(
        (await _api.markNotificationRead(
          notificationId: notificationId,
          setNotificationReadStateRequest: api.SetNotificationReadStateRequest(
            read: read,
          ),
        )).data!.data,
      );
      if (result.id != notificationId || result.isRead != read) _terminal();
      return result;
    } on DioException catch (error) {
      _throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<NotificationPreferences> patchPreferences(
    NotificationPreferencesDraft draft,
    int expectedVersion,
  ) async {
    _requireDraft(draft);
    if (expectedVersion <= 0) _terminal();
    try {
      final result = _preferences(
        (await _api.updateNotificationPreferences(
          ifMatch: '"v$expectedVersion"',
          requestBody: {
            'daily_ritual': draft.dailyRitual,
            'weekly_recap': draft.weeklyRecap,
            'moon_cycle': draft.moonCycle,
            'quiet_hours': {
              'enabled': draft.quietHours.enabled,
              'start': draft.quietHours.start,
              'end': draft.quietHours.end,
              'timezone': draft.quietHours.timezone,
            },
          },
        )).data!.data,
      );
      if (result.version <= expectedVersion || !draft.exactlyMatches(result)) {
        _terminal();
      }
      return result;
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const AmbiguousNotificationPreferences();
      throw ApiFailureMapper.map(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }

  @override
  Future<int> readAll(NotificationReadAll command) async {
    if (!command.before.isUtc || command.idempotencyKey.trim().isEmpty) {
      _terminal();
    }
    try {
      final count = (await _api.readAllNotifications(
        idempotencyKey: command.idempotencyKey,
        readAllNotificationsRequest: api.ReadAllNotificationsRequest(
          before: command.before,
        ),
      )).data!.data.updatedCount;
      if (count < 0 || count > 100) _terminal();
      return count;
    } on DioException catch (error) {
      if (_ambiguous(error)) throw const AmbiguousNotificationReadAll();
      throw ApiFailureMapper.map(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      _terminal();
    }
  }
}

NotificationItem _item(api.MemberNotification value) {
  _requireUuid(value.id);
  final destination = NotificationDestination.tryParse(value.deepLink);
  if (value.kind != 'briefing_ready' ||
      value.title.trim().isEmpty ||
      value.body.trim().isEmpty ||
      (value.deepLink != null && destination == null)) {
    _terminal();
  }
  return NotificationItem(
    id: value.id,
    kind: NotificationKind.briefingReady,
    title: value.title.trim(),
    body: value.body.trim(),
    destination: destination,
    scheduledAt: value.scheduledAt?.toUtc(),
    readAt: value.readAt?.toUtc(),
  );
}

NotificationPreferences _preferences(api.NotificationPreferences value) {
  final quietHours = value.quietHours;
  final result = NotificationPreferences(
    dailyRitual: value.dailyRitual,
    weeklyRecap: value.weeklyRecap,
    moonCycle: value.moonCycle,
    quietHours: NotificationQuietHours(
      enabled: quietHours['enabled'] == true,
      start: quietHours['start'] as String? ?? '22:00',
      end: quietHours['end'] as String? ?? '07:00',
      timezone: quietHours['timezone'] as String? ?? 'UTC',
    ),
    version: value.version,
  );
  if (result.version <= 0) _terminal();
  _requireDraft(result.asDraft());
  return result;
}

void _requireDraft(NotificationPreferencesDraft draft) {
  final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  if (!time.hasMatch(draft.quietHours.start) ||
      !time.hasMatch(draft.quietHours.end) ||
      draft.quietHours.timezone.trim().isEmpty ||
      draft.quietHours.timezone.length > 64) {
    _terminal();
  }
}

void _requireUuid(String value) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value)) {
    _terminal();
  }
}

void _requireUniqueIds(Iterable<String> ids) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) _terminal();
  }
}

Never _terminal() => throw const LoadFailure(LoadPhase.terminalFailure);

Never _throwFailure(DioException error) {
  if (_ambiguous(error)) throw const OfflineException();
  throw ApiFailureMapper.map(error);
}

bool _ambiguous(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;
