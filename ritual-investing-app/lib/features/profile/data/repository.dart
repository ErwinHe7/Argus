// ignore_for_file: prefer_initializing_formals

import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../domain/model.dart';

abstract interface class ProfileService {
  Future<ProfileModel> fetch();
  Future<void> patchPreferences(ProfilePreferencesUpdate update);
  Future<void> putInvestor(ProfileInvestorUpdate update);
  Future<ProfileConsentReceipt> putAstrology(ProfileAstrologyUpdate update);
  Future<ProfileConsentReceipt> deleteAstrology({required int expectedVersion});
}

class AstrologyDeletionPartialFailure extends LoadFailure {
  const AstrologyDeletionPartialFailure(super.phase);
}

abstract interface class ProfileRepository {
  Future<RepositoryRead<ProfileModel>> load();
  Future<RepositoryRead<ProfileModel>> updatePreferences(
    ProfilePreferencesUpdate update,
  );
  Future<RepositoryRead<ProfileModel>> updateInvestor(
    ProfileInvestorUpdate update,
  );
  Future<RepositoryRead<ProfileModel>> updateAstrology(
    ProfileAstrologyUpdate update,
  );
  Future<RepositoryRead<ProfileModel>> deleteAstrology({
    required int expectedVersion,
  });
}

class CachedProfileRepository implements ProfileRepository {
  CachedProfileRepository({
    required ProfileService service,
    required ReadCache cache,
    DateTime Function()? now,
  }) : _service = service,
       _cache = cache,
       _now = now ?? DateTime.now;
  final ProfileService _service;
  final ReadCache _cache;
  final DateTime Function() _now;
  static const _cacheKey = 'profile';

  @override
  Future<RepositoryRead<ProfileModel>> load() => cachedRead(
    key: _cacheKey,
    cache: _cache,
    fetch: _service.fetch,
    now: _now,
  );

  @override
  Future<RepositoryRead<ProfileModel>> updatePreferences(
    ProfilePreferencesUpdate update,
  ) async {
    await _service.patchPreferences(update);
    return _refresh();
  }

  @override
  Future<RepositoryRead<ProfileModel>> updateInvestor(
    ProfileInvestorUpdate update,
  ) async {
    await _service.putInvestor(update);
    return _refresh();
  }

  @override
  Future<RepositoryRead<ProfileModel>> updateAstrology(
    ProfileAstrologyUpdate update,
  ) async {
    final receipt = await _service.putAstrology(update);
    return _refresh(
      decision: ProfileConsentDecision.accepted,
      receipt: receipt,
    );
  }

  @override
  Future<RepositoryRead<ProfileModel>> deleteAstrology({
    required int expectedVersion,
  }) async {
    late final ProfileConsentReceipt receipt;
    try {
      receipt = await _service.deleteAstrology(
        expectedVersion: expectedVersion,
      );
    } on AstrologyDeletionPartialFailure {
      final cached = await _cache.get<ProfileModel>(_cacheKey);
      if (cached != null) {
        await _cache.put(
          _cacheKey,
          cached.value.copyWith(
            clearAstrology: true,
            astrologyDecision: ProfileConsentDecision.unknown,
          ),
          _now().toUtc(),
        );
      }
      rethrow;
    }
    return _refresh(
      decision: ProfileConsentDecision.withdrawn,
      receipt: receipt,
    );
  }

  Future<RepositoryRead<ProfileModel>> _refresh({
    ProfileConsentDecision? decision,
    ProfileConsentReceipt? receipt,
  }) async {
    var value = await _service.fetch();
    if (decision != null) {
      value = value.copyWith(
        astrologyDecision: decision,
        lastConsentReceipt: receipt,
        clearAstrology: decision != ProfileConsentDecision.accepted,
      );
    }
    final committedAt = _now().toUtc();
    await _cache.put(_cacheKey, value, committedAt);
    return RepositoryRead(
      value: value,
      isStale: false,
      committedAt: committedAt,
    );
  }
}
