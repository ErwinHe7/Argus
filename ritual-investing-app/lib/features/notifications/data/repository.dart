// ignore_for_file: prefer_initializing_formals

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
