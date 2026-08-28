import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart';
import 'repository.dart';

class GeneratedDiscoverApiService implements DiscoverService {
  GeneratedDiscoverApiService(RitualInvestingApiClient client)
    : _api = DiscoverApi(client.dio);
  final DiscoverApi _api;
  @override
  Future<DiscoverModel> fetch() async {
    try {
      final discoverRequest = _api.listDiscover(limit: 20);
      final creatorsRequest = _api.listSeededCreators(limit: 8);
      final responses = await Future.wait<Object>([
        discoverRequest,
        creatorsRequest,
      ]);
      final discover = (responses[0] as Response<DiscoverResponse>).data!;
      final creators =
          (responses[1] as Response<CreatorCollectionResponse>).data!;
      return DiscoverModel(
        items: discover.data.map(_mapDiscoverItem).toList(growable: false),
        creators: creators.data.map(_mapSeededCreator).toList(growable: false),
        nextCursor: discover.meta.nextCursor,
        hasMore: discover.meta.hasMore,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }
}

DiscoverItemView _mapDiscoverItem(DiscoverItem item) => switch (item.kind) {
  DiscoverItemKindEnum.asset => () {
    final value = item.asset;
    if (value == null ||
        value.assetType == AssetSummaryAssetTypeEnum.unknownDefaultOpenApi ||
        value.currency != 'USD') {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    return DiscoverItemView(
      id: value.id,
      revisionId: value.revisionId,
      slug: value.slug,
      kind: DiscoverItemKind.asset,
      title: value.name,
      subtitle: value.appearanceReason,
      symbol: value.symbol,
      appearanceReason: value.appearanceReason,
      demo: _mapResearchDemo(value.demo),
    );
  }(),
  DiscoverItemKindEnum.grimoire => () {
    final value = item.grimoire;
    if (value == null) throw const LoadFailure(LoadPhase.terminalFailure);
    return DiscoverItemView(
      id: value.id,
      revisionId: value.revisionId,
      slug: value.slug,
      kind: DiscoverItemKind.grimoire,
      title: value.title,
      subtitle: value.description,
      theme: value.theme,
      demo: _mapResearchDemo(value.demo),
    );
  }(),
  DiscoverItemKindEnum.circleTemplate => () {
    final value = item.circleTemplate;
    if (value == null) throw const LoadFailure(LoadPhase.terminalFailure);
    return DiscoverItemView(
      id: value.id,
      revisionId: value.revisionId,
      slug: value.slug,
      kind: DiscoverItemKind.circleTemplate,
      title: value.title,
      subtitle: value.description,
      theme: value.theme,
      creator: _mapSeededCreator(value.creator),
      demo: _mapResearchDemo(value.demo),
    );
  }(),
  DiscoverItemKindEnum.coven => () {
    final value = item.coven;
    if (value == null) throw const LoadFailure(LoadPhase.terminalFailure);
    return DiscoverItemView(
      id: value.id,
      revisionId: value.revisionId,
      slug: value.slug,
      kind: DiscoverItemKind.coven,
      title: value.company,
      subtitle: '${_covenCategory(value.category)} · ${value.teaser}',
      symbol: value.symbol,
      demo: _mapResearchDemo(value.demo),
    );
  }(),
  DiscoverItemKindEnum.unknownDefaultOpenApi => throw const LoadFailure(
    LoadPhase.terminalFailure,
  ),
};

SeededCreatorView _mapSeededCreator(SeededCreator value) {
  if (!value.isFictional) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return SeededCreatorView(
    id: value.id,
    slug: value.slug,
    displayName: value.displayName,
    bio: value.bio,
    isFictional: true,
    demo: _mapResearchDemo(value.demo),
  );
}

ResearchDemoDisclosure _mapResearchDemo(ResearchDisclosure value) =>
    ResearchDemoDisclosure(
      isDemo: value.isDemo,
      observedAt: value.observedAt,
      sourceLabel: value.sourceLabel,
      limitations: value.limitations,
    );

String _covenCategory(CovenSummaryCategoryEnum category) => switch (category) {
  CovenSummaryCategoryEnum.founder => 'Woman founder',
  CovenSummaryCategoryEnum.owner => 'Women-owned',
  CovenSummaryCategoryEnum.chiefExecutive => 'Woman chief executive',
  CovenSummaryCategoryEnum.unknownDefaultOpenApi => throw const LoadFailure(
    LoadPhase.terminalFailure,
  ),
};
