// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/ritual_api.dart';
import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class NotificationService {
  Future<NotificationPage> list({
    NotificationReadFilter filter,
    String? cursor,
  });
  Future<NotificationPreferences> getPreferences();
  Future<NotificationItem> setRead(String notificationId, bool read);
  Future<NotificationPreferences> patchPreferences(
    NotificationPreferencesDraft draft,
    int expectedVersion,
  );
  Future<int> readAll(NotificationReadAll command);
}

abstract interface class NotificationRepository {
  Future<RepositoryRead<NotificationPage>> load({
    NotificationReadFilter filter,
    String? cursor,
  });
  Future<RepositoryRead<NotificationPreferences>> getPreferences();
  Future<NotificationItem> setRead(String notificationId, bool read);
  Future<NotificationPreferences> patchPreferences(
    NotificationPreferencesDraft draft,
    int expectedVersion,
  );
  Future<int> readAll(NotificationReadAll command);
}

class CachedNotificationRepository implements NotificationRepository {
  CachedNotificationRepository({
    required NotificationService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final NotificationService _service;
  final ReadCache _cache;

  @override
  Future<RepositoryRead<NotificationPage>> load({
    NotificationReadFilter filter = NotificationReadFilter.all,
    String? cursor,
  }) => cachedRead(
    key: 'notifications:${filter.name}:${cursor ?? 'first'}',
    cache: _cache,
    fetch: () => _service.list(filter: filter, cursor: cursor),
  );

  @override
  Future<RepositoryRead<NotificationPreferences>> getPreferences() =>
      cachedRead(
        key: 'notification-preferences',
        cache: _cache,
        fetch: _service.getPreferences,
      );

  @override
  Future<NotificationPreferences> patchPreferences(
    NotificationPreferencesDraft draft,
    int expectedVersion,
  ) => _service.patchPreferences(draft, expectedVersion);

  @override
  Future<int> readAll(NotificationReadAll command) => _service.readAll(command);

  @override
  Future<NotificationItem> setRead(String notificationId, bool read) =>
      _service.setRead(notificationId, read);
}

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
      final response = (await _api.listNotifications(
        read: filter.name,
        cursor: cursor,
      )).data!;
      final items = response.data.map(_item).toList(growable: false);
      _requireUniqueIds(items.map((item) => item.id));
      _requirePage(response.meta.hasMore, response.meta.nextCursor);
      return NotificationPage(
        items: items,
        hasMore: response.meta.hasMore,
        nextCursor: response.meta.nextCursor,
      );
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
      return _preferences(
        (await _api.getNotificationPreferences()).data!.data,
      );
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
        (await _api.setNotificationReadState(
          notificationId: notificationId,
          setBriefingReadStateRequest: api.SetBriefingReadStateRequest(read: read),
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
        (await _api.patchNotificationPreferences(
          ifMatch: '"v$expectedVersion"',
          patchNotificationPreferencesRequest: api.PatchNotificationPreferencesRequest(
            dailyRitual: draft.dailyRitual,
            weeklyRecap: draft.weeklyRecap,
            moonCycle: draft.moonCycle,
            quietHours: api.GetNotificationPreferences200ResponseDataQuietHours(
              enabled: draft.quietHours.enabled,
              start: draft.quietHours.start,
              end: draft.quietHours.end,
              timezone: draft.quietHours.timezone,
            ),
          ),
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

NotificationItem _item(api.ListNotifications200ResponseDataInner value) {
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

NotificationPreferences _preferences(
  api.GetNotificationPreferences200ResponseData value,
) {
  final result = NotificationPreferences(
    dailyRitual: value.dailyRitual,
    weeklyRecap: value.weeklyRecap,
    moonCycle: value.moonCycle,
    quietHours: NotificationQuietHours(
      enabled: value.quietHours.enabled,
      start: value.quietHours.start,
      end: value.quietHours.end,
      timezone: value.quietHours.timezone,
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

void _requirePage(bool hasMore, String? cursor) {
  if (hasMore != (cursor != null && cursor.isNotEmpty)) _terminal();
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
