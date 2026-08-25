import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/view_state.dart';
import '../domain/model.dart' as coven_domain;
import 'repository.dart';

class GeneratedCovenApiService implements CovenService {
  GeneratedCovenApiService(RitualInvestingApiClient client)
    : _api = FoundersCovenApi(client.dio),
      _saves = SavesApi(client.dio);
  final FoundersCovenApi _api;
  final SavesApi _saves;
  @override
  Future<coven_domain.CovenModel> fetch() async {
    try {
      final values = (await _api.listCoven(limit: 4)).data!.data;
      return coven_domain.CovenModel(
        entries: values
            .map(
              (item) => coven_domain.CovenEntry(
                id: item.id,
                revisionId: item.revisionId,
                slug: item.slug,
                name: item.company,
                symbol: item.symbol,
                category: _covenQualificationCategory(item.category),
                focus: item.focus,
                teaser: item.teaser,
                effectiveDate: item.effectiveDate,
                verifiedAsOf: item.verifiedAsOf,
                demo: _mapCovenDemo(item.demo),
              ),
            )
            .toList(growable: false),
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<coven_domain.CovenDetail> fetchDetail(String entryId) async {
    try {
      final value = (await _api.getCovenEntry(entryId: entryId)).data!.data;
      return coven_domain.CovenDetail(
        id: value.id,
        revisionId: value.revisionId,
        slug: value.slug,
        company: value.company,
        symbol: value.symbol,
        focus: value.focus,
        summary: value.summary,
        inclusionRationale: value.inclusionRationale,
        limitations: value.limitations,
        qualifications: value.qualifications
            .map(
              (qualification) => coven_domain.CovenQualification(
                category: _covenQualificationCategory(qualification.category),
                personName: qualification.personName,
                effectiveDate: qualification.effectiveDate,
                verifiedAsOf: qualification.verifiedAsOf,
                validTo: qualification.validTo,
                evidence: qualification.evidence
                    .map(_mapCovenEvidenceSummary)
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        evidence: const [],
        saved: value.saved,
        demo: _mapCovenDemo(value.demo),
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    } on LoadFailure {
      rethrow;
    } on Object {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
  }

  @override
  Future<List<coven_domain.CovenEvidenceDetail>> fetchEvidence(
    String entryId,
  ) async {
    try {
      final values = (await _api.getCovenEvidence(entryId: entryId)).data!.data;
      return values
          .map(
            (value) => coven_domain.CovenEvidenceDetail(
              claimId: value.claimId,
              factorLabel: value.factorLabel,
              observedAt: value.observedAt,
              summary: value.summary,
              uncertainty: value.uncertainty,
              publisher: value.source_.publisher,
              sourceTitle: value.source_.title,
              sourceUrl: Uri.parse(value.source_.url),
              publishedAt: value.source_.publishedAt,
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
  Future<void> save(String entryId) async {
    try {
      await _saves.saveCoven(id: entryId, saveAssetRequest: SaveAssetRequest());
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const CovenAmbiguousMutation();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<void> unsave(String entryId) async {
    try {
      await _saves.unsaveCoven(id: entryId);
    } on DioException catch (error) {
      if (ApiFailureMapper.isTransportFailure(error)) {
        throw const CovenAmbiguousMutation();
      }
      ApiFailureMapper.throwFailure(error);
    }
  }
}

coven_domain.CovenQualificationCategory _covenQualificationCategory(
  Object category,
) => switch (category) {
  CovenSummaryCategoryEnum.founder || CovenQualificationCategoryEnum.founder =>
    coven_domain.CovenQualificationCategory.founder,
  CovenSummaryCategoryEnum.owner || CovenQualificationCategoryEnum.owner =>
    coven_domain.CovenQualificationCategory.owner,
  CovenSummaryCategoryEnum.chiefExecutive ||
  CovenQualificationCategoryEnum.chiefExecutive =>
    coven_domain.CovenQualificationCategory.chiefExecutive,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

coven_domain.CovenEvidenceSummary _mapCovenEvidenceSummary(
  EvidenceSummary value,
) => coven_domain.CovenEvidenceSummary(
  claimId: value.claimId,
  factorLabel: value.factorLabel,
  observedAt: value.observedAt,
  summary: value.summary,
  uncertainty: value.uncertainty,
);

coven_domain.CovenDemoDisclosure _mapCovenDemo(DemoDisclosure value) =>
    coven_domain.CovenDemoDisclosure(
      isDemo: value.isDemo,
      observedAt: value.observedAt,
      sourceLabel: value.sourceLabel,
      limitations: value.limitations,
    );
