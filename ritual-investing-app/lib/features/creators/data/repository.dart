// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/ritual_api.dart';
import '../../../core/api/view_state.dart';
import '../../../core/cache/cached_read.dart';
import '../../../core/cache/read_cache.dart';
import '../../discover/domain/model.dart';

export '../../../core/cache/cached_read.dart' show OfflineException;

abstract interface class CreatorService {
  Future<SeededCreatorView> fetchById(String creatorId);
}

class CreatorRepository {
  CreatorRepository({required CreatorService service, required ReadCache cache})
    : _service = service,
      _cache = cache;

  final CreatorService _service;
  final ReadCache _cache;

  Future<RepositoryRead<SeededCreatorView>> load(String creatorId) =>
      cachedRead(
        key: 'seeded-creator:$creatorId',
        cache: _cache,
        fetch: () => _service.fetchById(creatorId),
      );
}

class GeneratedCreatorService implements CreatorService {
  GeneratedCreatorService(api.RitualInvestingApiClient client)
    : _api = api.DiscoverApi(client.dio);

  final api.DiscoverApi _api;

  @override
  Future<SeededCreatorView> fetchById(String creatorId) async {
    try {
      final values = (await _api.listSeededCreators(limit: 50)).data!.data;
      final value = values
          .where((creator) => creator.id == creatorId)
          .firstOrNull;
      if (value == null || !value.isFictional) {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      return SeededCreatorView(
        id: value.id,
        slug: value.slug,
        displayName: value.displayName,
        bio: value.bio,
        isFictional: true,
        demo: ResearchDemoDisclosure(
          isDemo: value.demo.isDemo,
          observedAt: value.demo.observedAt,
          sourceLabel: value.demo.sourceLabel,
          limitations: value.demo.limitations,
        ),
      );
    } on DioException catch (error) {
      throw ApiFailureMapper.map(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }
}
