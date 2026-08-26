// ignore_for_file: prefer_initializing_formals

import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class BriefingService {
  Future<BriefingPage> list({
    BriefingType? type,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? cursor,
  });
  Future<BriefingDetail> get(String briefingId);
  Future<DailyBriefingResult> daily(DateTime localDate);
  Future<BriefingSummary> setRead(String briefingId, bool read);
}

abstract interface class BriefingRepository {
  Future<RepositoryRead<BriefingPage>> load({
    BriefingType? type,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? cursor,
  });
  Future<RepositoryRead<BriefingDetail>> get(String briefingId);
  Future<DailyBriefingResult> daily(DateTime localDate);
  Future<BriefingSummary> setRead(String briefingId, bool read);
}

class CachedBriefingRepository implements BriefingRepository {
  CachedBriefingRepository({
    required BriefingService service,
    required ReadCache cache,
  }) : _service = service,
       _cache = cache;

  final BriefingService _service;
  final ReadCache _cache;

  @override
  Future<RepositoryRead<BriefingPage>> load({
    BriefingType? type,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? cursor,
  }) => cachedRead(
    key:
        'briefings:${type?.name ?? 'all'}:'
        '${_dateKey(periodStart)}:${_dateKey(periodEnd)}:${cursor ?? 'first'}',
    cache: _cache,
    fetch: () => _service.list(
      type: type,
      periodStart: periodStart,
      periodEnd: periodEnd,
      cursor: cursor,
    ),
  );

  @override
  Future<RepositoryRead<BriefingDetail>> get(String briefingId) => cachedRead(
    key: 'briefing:$briefingId',
    cache: _cache,
    fetch: () => _service.get(briefingId),
  );

  @override
  Future<DailyBriefingResult> daily(DateTime localDate) =>
      _service.daily(localDate);

  @override
  Future<BriefingSummary> setRead(String briefingId, bool read) =>
      _service.setRead(briefingId, read);
}

String _dateKey(DateTime? value) => value == null
    ? 'open'
    : '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
