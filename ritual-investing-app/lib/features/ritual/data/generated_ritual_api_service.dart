import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/daily_ritual.dart';
import 'daily_ritual_repository.dart';

class GeneratedRitualApiService implements DailyRitualService {
  GeneratedRitualApiService(RitualInvestingApiClient client)
    : _api = RitualsApi(client.dio);
  final RitualsApi _api;
  @override
  Future<DailyRitual> fetchDaily({DailyRitualMode? mode}) async {
    try {
      final modeValue = switch (mode) {
        null => null,
        DailyRitualMode.tarot => 'tarot',
        DailyRitualMode.astrology => 'astrology',
        DailyRitualMode.unknown => throw const LoadFailure(
          LoadPhase.terminalFailure,
        ),
      };
      final data = (await _api.getDailyRitual(mode: modeValue)).data!.data;
      return _mapDailyRitual(data);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async {
    try {
      return _mapDailyRitual(
        (await _api.getRitualAssignment(assignmentId: assignmentId)).data!.data,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async {
    try {
      final values = (await _api.getRitualEvidence(assignmentId: assignmentId))
          .data!
          .data;
      return values
          .map(
            (value) => RitualEvidenceDetail(
              claimId: value.claimId,
              factorLabel: value.factorLabel,
              observedAt: value.observedAt,
              summary: value.summary,
              uncertainty: value.uncertainty,
              source: RitualEvidenceSource(
                publisher: value.source_.publisher,
                title: value.source_.title,
                url: Uri.parse(value.source_.url),
                publishedAt: value.source_.publishedAt,
              ),
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    } on FormatException {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<RitualHistoryPage> fetchHistory({String? cursor}) async {
    try {
      final response = (await _api.listRitualHistory(cursor: cursor)).data!;
      return RitualHistoryPage(
        items: response.data
            .map((value) {
              final mode = switch (value.mode) {
                RitualHistoryItemModeEnum.tarot => DailyRitualMode.tarot,
                RitualHistoryItemModeEnum.astrology =>
                  DailyRitualMode.astrology,
                RitualHistoryItemModeEnum.unknownDefaultOpenApi =>
                  throw const LoadFailure(LoadPhase.terminalFailure),
              };
              final state = switch (value.state) {
                RitualHistoryItemStateEnum.assigned =>
                  DailyRitualState.assigned,
                RitualHistoryItemStateEnum.revealed =>
                  DailyRitualState.revealed,
                RitualHistoryItemStateEnum.completed =>
                  DailyRitualState.completed,
                RitualHistoryItemStateEnum.unknownDefaultOpenApi =>
                  throw const LoadFailure(LoadPhase.terminalFailure),
              };
              return RitualHistoryEntry(
                assignmentId: value.assignmentId,
                date: value.date,
                mode: mode,
                title: value.title,
                state: state,
                demo: _mapRitualDisclosure(value.demo),
              );
            })
            .toList(growable: false),
        nextCursor: response.meta.nextCursor,
        hasMore: response.meta.hasMore,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) => _transition(
    () => _api.revealRitual(assignmentId: assignmentId, ifMatch: '"v$version"'),
  );

  @override
  Future<DailyRitual> complete(String assignmentId, int version) => _transition(
    () =>
        _api.completeRitual(assignmentId: assignmentId, ifMatch: '"v$version"'),
  );

  Future<DailyRitual> _transition(
    Future<Response<GetRitualAssignment200Response>> Function() request,
  ) async {
    try {
      return _mapDailyRitual((await request()).data!.data);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const RitualAmbiguousMutation();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  DailyRitual _mapDailyRitual(DailyRitualDetail data) {
    final mode = switch (data.mode) {
      DailyRitualDetailModeEnum.tarot => DailyRitualMode.tarot,
      DailyRitualDetailModeEnum.astrology => DailyRitualMode.astrology,
      DailyRitualDetailModeEnum.unknownDefaultOpenApi =>
        throw const LoadFailure(LoadPhase.terminalFailure),
    };
    final state = switch (data.state) {
      DailyRitualDetailStateEnum.assigned => DailyRitualState.assigned,
      DailyRitualDetailStateEnum.revealed => DailyRitualState.revealed,
      DailyRitualDetailStateEnum.completed => DailyRitualState.completed,
      DailyRitualDetailStateEnum.unknownDefaultOpenApi =>
        throw const LoadFailure(LoadPhase.terminalFailure),
    };
    if (data.rowan.surface == RowanCounselSurfaceEnum.unknownDefaultOpenApi ||
        data.art.key == ArtReferenceKeyEnum.unknownDefaultOpenApi) {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    return DailyRitual(
      assignmentId: data.assignmentId,
      date: data.date,
      mode: mode,
      revision: RitualRevision(
        id: data.revision.id,
        number: data.revision.number,
      ),
      title: data.title,
      art: RitualArt(key: data.art.key.value, alt: data.art.alt),
      interpretation: data.interpretation,
      guidance: data.guidance,
      marketLabel: data.marketLabel,
      ideas: data.ideas
          .map(
            (idea) => RitualIdea(
              assetId: idea.assetId,
              symbol: idea.symbol,
              name: idea.name,
              appearanceReason: idea.appearanceReason,
              riskSummary: idea.riskSummary,
            ),
          )
          .toList(growable: false),
      evidence: data.evidence
          .map(
            (evidence) => RitualEvidence(
              claimId: evidence.claimId,
              factorLabel: evidence.factorLabel,
              observedAt: evidence.observedAt,
              summary: evidence.summary,
              uncertainty: evidence.uncertainty,
            ),
          )
          .toList(growable: false),
      rowan: RitualCounsel(
        scriptRevisionId: data.rowan.scriptRevisionId,
        surface: data.rowan.surface.value,
        body: data.rowan.body,
        riskFooter: data.rowan.riskFooter,
      ),
      version: data.version,
      state: state,
      revealedAt: data.revealedAt,
      completedAt: data.completedAt,
      demo: _mapRitualDisclosure(data.demo),
    );
  }
}

RitualDisclosure _mapRitualDisclosure(DemoDisclosure value) => RitualDisclosure(
  isDemo: value.isDemo,
  observedAt: value.observedAt,
  sourceLabel: value.sourceLabel,
  limitations: value.limitations,
);
