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
      final response = await _api.getDailyRitual(
        mode: switch (mode) {
          null => null,
          DailyRitualMode.tarot => 'tarot',
          DailyRitualMode.astrology => 'astrology',
          DailyRitualMode.unknown => throw const LoadFailure(
            LoadPhase.terminalFailure,
          ),
        },
      );
      return _map(response.data!.data);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<DailyRitual> fetchAssignment(String assignmentId) async {
    try {
      return _map(
        (await _api.getRitual(assignmentId: assignmentId)).data!.data,
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<List<RitualEvidenceDetail>> fetchEvidence(String assignmentId) async {
    try {
      final claims = (await _api.getRitualEvidence(assignmentId: assignmentId))
          .data!
          .data;
      return claims
          .map(
            (claim) => RitualEvidenceDetail(
              claimId: claim.id,
              factorLabel: claim.claimType,
              observedAt: claim.observedAt ?? claim.source_.retrievedAt.toUtc(),
              summary: claim.summary,
              uncertainty: claim.uncertainty,
              source: RitualEvidenceSource(
                publisher: claim.source_.publisher,
                title: claim.source_.title,
                url: Uri.parse(claim.source_.canonicalUrl),
                publishedAt: claim.source_.publishedAt?.toUtc(),
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
    if (cursor != null) throw const LoadFailure(LoadPhase.terminalFailure);
    try {
      final items = (await _api.listRitualHistory()).data!.data
          .map((value) => RitualHistoryEntry.fromRitual(_map(value)))
          .toList(growable: false);
      return RitualHistoryPage(items: items, nextCursor: null, hasMore: false);
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<DailyRitual> reveal(String assignmentId, int version) => _transition(
    assignmentId: assignmentId,
    version: version,
    from: TransitionRitualRequestFromEnum.assigned,
    to: TransitionRitualRequestToEnum.revealed,
  );

  @override
  Future<DailyRitual> complete(String assignmentId, int version) => _transition(
    assignmentId: assignmentId,
    version: version,
    from: TransitionRitualRequestFromEnum.revealed,
    to: TransitionRitualRequestToEnum.completed,
  );

  Future<DailyRitual> _transition({
    required String assignmentId,
    required int version,
    required TransitionRitualRequestFromEnum from,
    required TransitionRitualRequestToEnum to,
  }) async {
    try {
      final response = await _api.transitionRitual(
        assignmentId: assignmentId,
        ifMatch: '"v$version"',
        transitionRitualRequest: TransitionRitualRequest(from: from, to: to),
      );
      return _map(response.data!.data);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const RitualAmbiguousMutation();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }
}

DailyRitual _map(DailyRitualAssignment value) {
  final payload = value.payload;
  final title = _string(payload, 'title');
  final observedAt = _timestamp(payload['observation_at']) ?? value.localDate;
  return DailyRitual(
    assignmentId: value.id,
    date: value.localDate,
    mode: switch (value.mode) {
      DailyRitualAssignmentModeEnum.tarot => DailyRitualMode.tarot,
      DailyRitualAssignmentModeEnum.astrology => DailyRitualMode.astrology,
      DailyRitualAssignmentModeEnum.unknownDefaultOpenApi =>
        DailyRitualMode.unknown,
    },
    revision: RitualRevision(
      id: value.revisionId,
      number: _integer(payload['revision_number']) ?? 1,
    ),
    title: title,
    art: RitualArt(
      key: _optionalString(payload, 'art_key') ?? 'the-fool',
      alt: _optionalString(payload, 'art_alt') ?? title,
    ),
    interpretation: _string(payload, 'interpretation'),
    guidance: _string(payload, 'guidance'),
    marketLabel: _string(payload, 'market_label'),
    ideas: _objects(payload['ideas']).map(_idea).toList(growable: false),
    evidence: _objects(payload['evidence'])
        .map(_evidence)
        .toList(growable: false),
    rowan: RitualCounsel(
      scriptRevisionId: value.rowanRevisionId ?? value.revisionId,
      surface: 'daily_ritual',
      body: value.bodyTemplate ?? _string(payload, 'guidance'),
      riskFooter: value.riskFooter ?? _string(payload, 'uncertainty'),
    ),
    version: value.version,
    state: switch (value.state) {
      DailyRitualAssignmentStateEnum.assigned => DailyRitualState.assigned,
      DailyRitualAssignmentStateEnum.revealed => DailyRitualState.revealed,
      DailyRitualAssignmentStateEnum.completed => DailyRitualState.completed,
      DailyRitualAssignmentStateEnum.unknownDefaultOpenApi =>
        DailyRitualState.unknown,
    },
    revealedAt: value.revealedAt?.toUtc(),
    completedAt: value.completedAt?.toUtc(),
    demo: RitualDisclosure(
      isDemo: false,
      observedAt: observedAt.toUtc(),
      sourceLabel: 'Leo editorial',
      limitations: const ['Educational context only.'],
    ),
  );
}

RitualIdea _idea(Map<String, Object?> value) => RitualIdea(
  assetId: _string(value, 'asset_id'),
  symbol: _string(value, 'symbol'),
  name: _string(value, 'name'),
  appearanceReason: _string(value, 'appearance_reason'),
  riskSummary: _string(value, 'risk_summary'),
);

RitualEvidence _evidence(Map<String, Object?> value) => RitualEvidence(
  claimId: _string(value, 'claim_id'),
  factorLabel: _string(value, 'factor_label'),
  observedAt:
      _timestamp(value['observed_at']) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  summary: _string(value, 'summary'),
  uncertainty: _string(value, 'uncertainty'),
);

String _string(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  return field;
}

String? _optionalString(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is String && field.trim().isNotEmpty ? field : null;
}

int? _integer(Object? value) => value is int ? value : null;

DateTime? _timestamp(Object? value) => value is String
    ? DateTime.tryParse(value)?.toUtc()
    : value is DateTime
    ? value.toUtc()
    : null;

List<Map<String, Object?>> _objects(Object? value) {
  if (value == null) return const [];
  if (value is! List) throw const LoadFailure(LoadPhase.terminalFailure);
  return value
      .map((entry) {
        if (entry is! Map) throw const LoadFailure(LoadPhase.terminalFailure);
        return Map<String, Object?>.from(entry);
      })
      .toList(growable: false);
}
