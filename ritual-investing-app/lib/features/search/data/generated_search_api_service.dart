import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart'
    as api;

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart';
import 'repository.dart';

class GeneratedSearchService implements SearchService {
  GeneratedSearchService(api.RitualInvestingApiClient client)
    : _api = api.SearchApi(client.dio);

  final api.SearchApi _api;

  @override
  Future<SearchPage> search(SearchRequest request) async {
    final cancelToken = CancelToken();
    request.cancellation.whenCancelled.then((_) {
      if (!cancelToken.isCancelled) cancelToken.cancel('superseded');
    });
    try {
      final response = (await _api.searchPublishedCatalog(
        q: request.context.query,
        kinds: _kinds(request.context.kinds),
        cursor: request.cursor,
        cancelToken: cancelToken,
      )).data!;
      return SearchPage(
        items: response.data.map(_item).toList(growable: false),
        nextCursor: response.meta.nextCursor,
        hasMore: response.meta.hasMore,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) throw const SearchCancelled();
      if (error.response?.statusCode == 429) {
        throw SearchRateLimited(_retryAfter(error.response));
      }
      if (_offline(error)) throw const LoadFailure(LoadPhase.retryableFailure);
      throw ApiFailureMapper.map(error);
    }
  }
}

String _kinds(Set<SearchKind> kinds) {
  final values =
      (kinds.isEmpty ? SearchKind.values : kinds)
          .map(
            (kind) => switch (kind) {
              SearchKind.asset => 'asset',
              SearchKind.coven => 'coven',
              SearchKind.grimoire => 'grimoire',
              SearchKind.circleTemplate => 'circle_template',
            },
          )
          .toList(growable: false)
        ..sort();
  return values.join(',');
}

SearchItem _item(api.SearchResult result) => switch (result.kind) {
  api.SearchResultKindEnum.asset => _asset(result.asset),
  api.SearchResultKindEnum.coven => _coven(result.coven),
  api.SearchResultKindEnum.grimoire => _grimoire(result.grimoire),
  api.SearchResultKindEnum.circleTemplate => _circle(result.circleTemplate),
  api.SearchResultKindEnum.unknownDefaultOpenApi => throw const LoadFailure(
    LoadPhase.terminalFailure,
  ),
};

SearchItem _asset(api.AssetSummary? value) {
  if (value == null ||
      value.assetType == api.AssetSummaryAssetTypeEnum.unknownDefaultOpenApi ||
      value.currency == api.AssetSummaryCurrencyEnum.unknownDefaultOpenApi) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return SearchItem(
    id: value.id,
    revisionId: value.revisionId,
    kind: SearchKind.asset,
    title: value.name,
    subtitle: value.appearanceReason,
    symbol: value.symbol,
    isDemo: value.demo.isDemo,
    observedAt: value.demo.observedAt,
  );
}

SearchItem _coven(api.CovenSummary? value) {
  if (value == null ||
      value.category == api.CovenSummaryCategoryEnum.unknownDefaultOpenApi) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return SearchItem(
    id: value.id,
    revisionId: value.revisionId,
    kind: SearchKind.coven,
    title: value.company,
    subtitle: value.teaser,
    symbol: value.symbol,
    isDemo: value.demo.isDemo,
    observedAt: value.effectiveDate,
  );
}

SearchItem _grimoire(api.GrimoireSummary? value) {
  if (value == null) throw const LoadFailure(LoadPhase.terminalFailure);
  return SearchItem(
    id: value.id,
    revisionId: value.revisionId,
    kind: SearchKind.grimoire,
    title: value.title,
    subtitle: value.description,
    symbol: null,
    isDemo: value.demo.isDemo,
    observedAt: value.demo.observedAt,
  );
}

SearchItem _circle(api.CircleTemplateSummary? value) {
  if (value == null) throw const LoadFailure(LoadPhase.terminalFailure);
  return SearchItem(
    id: value.id,
    revisionId: value.revisionId,
    kind: SearchKind.circleTemplate,
    title: value.title,
    subtitle: value.description,
    symbol: null,
    isDemo: value.demo.isDemo,
    observedAt: value.demo.observedAt,
  );
}

Duration _retryAfter(Response<dynamic>? response) {
  final value = response?.headers.value('retry-after');
  final seconds = int.tryParse(value ?? '');
  if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
  final date = DateTime.tryParse(value ?? '')?.toUtc();
  if (date != null) {
    final difference = date.difference(DateTime.now().toUtc());
    if (!difference.isNegative) return difference;
  }
  return const Duration(seconds: 30);
}

bool _offline(DioException error) =>
    error.type == DioExceptionType.connectionError ||
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;
