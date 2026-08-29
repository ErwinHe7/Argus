// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../../discover/domain/model.dart';
import 'repository.dart';

class GeneratedCreatorService implements CreatorService {
  GeneratedCreatorService(api.RitualInvestingApiClient client)
    : _api = api.DiscoverApi(client.dio);

  final api.DiscoverApi _api;

  @override
  Future<SeededCreatorView> fetchById(String creatorId) async {
    try {
      final value = (await _api.getSeededCreator(id: creatorId)).data?.data;
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
