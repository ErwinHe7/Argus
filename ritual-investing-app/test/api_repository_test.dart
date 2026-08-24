import 'package:flutter_test/flutter_test.dart';
import 'package:ritual_investing_app/core/cache/read_cache.dart';
import 'package:ritual_investing_app/features/ritual/data/daily_ritual_repository.dart';
import 'package:ritual_investing_app/features/ritual/domain/daily_ritual.dart';

void main() {
  test(
    'repository falls back to a stale committed read when offline',
    () async {
      final cache = MemoryReadCache();
      const fixture = DailyRitual(
        title: 'The Compass',
        interpretation: 'Direction, not urgency.',
      );
      await cache.put('daily-ritual', fixture, DateTime.utc(2026, 8, 23));
      final repository = DailyRitualRepository(
        service: _OfflineService(),
        cache: cache,
      );
      final result = await repository.load();
      expect(result.value, fixture);
      expect(result.isStale, isTrue);
    },
  );
}

class _OfflineService implements DailyRitualService {
  @override
  Future<DailyRitual> fetchDaily() => Future.error(const OfflineException());
}
