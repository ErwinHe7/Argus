import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../features/coven/data/repository.dart';
import '../../features/coven/domain/model.dart';
import '../../features/discover/data/repository.dart';
import '../../features/discover/domain/model.dart';
import '../../features/profile/data/repository.dart';
import '../../features/profile/domain/model.dart';
import '../../features/ritual/data/daily_ritual_repository.dart';
import '../../features/ritual/domain/daily_ritual.dart';
import 'view_state.dart';

class GeneratedRitualApiService implements DailyRitualService {
  GeneratedRitualApiService(RitualInvestingApiClient client)
    : _api = RitualsApi(client.dio);
  final RitualsApi _api;
  @override
  Future<DailyRitual> fetchDaily() async {
    try {
      final data = (await _api.getDailyRitual()).data!.data;
      return DailyRitual(
        title: data.title,
        interpretation: data.interpretation,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

class GeneratedDiscoverApiService implements DiscoverService {
  GeneratedDiscoverApiService(RitualInvestingApiClient client)
    : _api = DiscoverApi(client.dio);
  final DiscoverApi _api;
  @override
  Future<DiscoverModel> fetch() async {
    try {
      final responses = await Future.wait([
        _api.listGrimoires(limit: 3),
        _api.listCircleTemplates(limit: 2),
      ]);
      final grimoires = responses[0].data as GrimoireCollectionResponse;
      final circles = responses[1].data as CircleTemplateCollectionResponse;
      return DiscoverModel(
        grimoires: grimoires.data
            .map(
              (item) =>
                  DiscoverCard(title: item.title, subtitle: item.description),
            )
            .toList(),
        circles: circles.data
            .map(
              (item) =>
                  DiscoverCard(title: item.title, subtitle: item.description),
            )
            .toList(),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

class GeneratedCovenApiService implements CovenService {
  GeneratedCovenApiService(RitualInvestingApiClient client)
    : _api = FoundersCovenApi(client.dio);
  final FoundersCovenApi _api;
  @override
  Future<CovenModel> fetch() async {
    try {
      final values = (await _api.listCoven(limit: 4)).data!.data;
      return CovenModel(
        entries: values
            .map(
              (item) => CovenEntry(
                name: item.company,
                symbol: item.symbol,
                category: switch (item.category) {
                  CovenSummaryCategoryEnum.founder => 'Woman founder',
                  CovenSummaryCategoryEnum.owner => 'Women-owned',
                  CovenSummaryCategoryEnum.chiefExecutive =>
                    'Woman chief executive',
                  CovenSummaryCategoryEnum.unknownDefaultOpenApi =>
                    'Verified qualification',
                },
                focus: item.focus,
              ),
            )
            .toList(),
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

class GeneratedProfileApiService implements ProfileService {
  GeneratedProfileApiService(RitualInvestingApiClient client)
    : _api = AccountApi(client.dio);
  final AccountApi _api;
  @override
  Future<ProfileModel> fetch() async {
    try {
      return ProfileModel(
        displayName: (await _api.getMe()).data!.data.profile.displayName,
      );
    } on DioException catch (error) {
      _throwApiFailure(error);
    }
  }
}

Never _throwApiFailure(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout) {
    throw const OfflineException();
  }
  throw LoadFailure(switch (error.response?.statusCode) {
    403 => LoadPhase.forbidden,
    404 => LoadPhase.empty,
    409 => LoadPhase.conflict,
    429 => LoadPhase.throttled,
    _ => LoadPhase.retryableFailure,
  });
}
