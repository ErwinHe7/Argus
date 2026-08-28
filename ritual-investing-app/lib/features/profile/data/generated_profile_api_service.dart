import 'package:dio/dio.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/api_failure_mapper.dart';
import '../../../core/api/date_only_request_interceptor.dart';
import '../../../core/api/view_state.dart';
import '../../onboarding/domain/onboarding_draft.dart' as onboarding;
import '../domain/model.dart';
import 'repository.dart';

class GeneratedProfileApiService implements ProfileService {
  GeneratedProfileApiService(RitualInvestingApiClient client)
    : _api = AccountApi(client.dio) {
    ensureDateOnlyRequestSerialization(client.dio);
  }

  final AccountApi _api;

  @override
  Future<ProfileModel> fetch() async {
    try {
      final account = (await _api.getAccount()).data?.data;
      final profile = account?.profile;
      final preferences = account?.preferences;
      if (account == null ||
          account.status != MemberAccountStatusEnum.active ||
          profile == null ||
          preferences == null) {
        throw const LoadFailure(LoadPhase.terminalFailure);
      }
      return ProfileModel(
        displayName: profile.displayName,
        profileVersion: preferences.version,
        preferences: _mapPreferences(preferences),
        investor: account.investorProfile == null
            ? null
            : _mapInvestor(account.investorProfile!),
        astrology: account.astrologyProfile == null
            ? null
            : _mapAstrology(account.astrologyProfile!),
        astrologyDecision: account.astrologyProfile == null
            ? ProfileConsentDecision.unknown
            : ProfileConsentDecision.accepted,
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
  Future<void> patchPreferences(ProfilePreferencesUpdate update) async {
    if (update.ritualFamiliarity != null ||
        update.ritualLanguage != null ||
        update.ritualInterests != null) {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    try {
      await _api.updatePreferences(
        ifMatch: _etag(update.expectedVersion),
        updatePreferencesRequest: UpdatePreferencesRequest(
          ritualMode: _requestRitualMode(update.ritualMode),
          themeMode: _requestTheme(update.theme),
        ),
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<void> putInvestor(ProfileInvestorUpdate update) async {
    if (update.experience != null || update.contributionRhythm != null) {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    try {
      await _api.updateInvestorProfile(
        ifMatch: update.expectedVersion == null
            ? null
            : _etag(update.expectedVersion!),
        updateInvestorProfileRequest: UpdateInvestorProfileRequest(
          goalType: _requestGoal(update.goal),
          timeHorizon: _requestHorizon(update.horizon),
          riskComfort: _requestRisk(update.risk),
        ),
      );
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<ProfileConsentReceipt> putAstrology(
    ProfileAstrologyUpdate update,
  ) async {
    try {
      final receipt = await _writeAstrologyConsent(
        RecordConsentRequestDecisionEnum.accepted,
      );
      await _api.updateAstrologyProfile(
        ifMatch: update.expectedVersion == null
            ? null
            : _etag(update.expectedVersion!),
        updateAstrologyProfileRequest: UpdateAstrologyProfileRequest(
          birthDate: update.birthDate.toUtc(),
        ),
      );
      return receipt;
    } on DioException catch (error) {
      ApiFailureMapper.throwFailure(error);
    }
  }

  @override
  Future<ProfileConsentReceipt> deleteAstrology({
    required int expectedVersion,
  }) async {
    try {
      await _api.deleteAstrologyProfile(ifMatch: _etag(expectedVersion));
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) {
        ApiFailureMapper.throwFailure(error);
      }
    }
    try {
      return await _writeAstrologyConsent(
        RecordConsentRequestDecisionEnum.withdrawn,
      );
    } on DioException catch (error) {
      throw AstrologyDeletionPartialFailure(_failurePhase(error));
    } on LoadFailure catch (failure) {
      throw AstrologyDeletionPartialFailure(failure.phase);
    } on Object {
      throw const AstrologyDeletionPartialFailure(LoadPhase.terminalFailure);
    }
  }

  Future<ProfileConsentReceipt> _writeAstrologyConsent(
    RecordConsentRequestDecisionEnum decision,
  ) async {
    final receipt = (await _api.recordConsent(
      recordConsentRequest: RecordConsentRequest(
        decision: decision,
        policyCode: 'astrology',
        policyVersion: '2026-08',
      ),
    )).data?.data;
    if (receipt == null || receipt.policyCode != 'astrology') {
      throw const LoadFailure(LoadPhase.terminalFailure);
    }
    return ProfileConsentReceipt(
      id: receipt.id,
      decision: _consentDecision(receipt.decision.value),
      policyVersion: receipt.policyVersion,
      recordedAt: receipt.recordedAt.toUtc(),
    );
  }
}

String _etag(int version) => '"v$version"';

LoadPhase _failurePhase(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return LoadPhase.retryableFailure;
  }
  return ApiFailureMapper.map(error).phase;
}

SavedRitualPreferences _mapPreferences(MemberPreferences value) =>
    SavedRitualPreferences(
      locale: value.locale,
      timezone: value.timezone,
      ritualMode: switch (value.ritualMode) {
        MemberPreferencesRitualModeEnum.tarot => ProfileRitualMode.tarot,
        MemberPreferencesRitualModeEnum.astrology =>
          ProfileRitualMode.astrology,
        _ => throw const LoadFailure(LoadPhase.terminalFailure),
      },
      theme: switch (value.themeMode) {
        MemberPreferencesThemeModeEnum.system => ProfileTheme.system,
        MemberPreferencesThemeModeEnum.light => ProfileTheme.light,
        MemberPreferencesThemeModeEnum.dark => ProfileTheme.dark,
        _ => throw const LoadFailure(LoadPhase.terminalFailure),
      },
      version: value.version,
    );

SavedInvestorProfile _mapInvestor(InvestorProfile value) =>
    SavedInvestorProfile(
      goal: _investmentGoal(value.goalType.value),
      horizon: _investmentHorizon(value.timeHorizon.value),
      risk: _riskComfort(value.riskComfort.value),
      isDemo: false,
      version: value.version,
    );

SavedAstrologyProfile _mapAstrology(AstrologyProfile value) {
  if (value.algorithmVersion ==
          AstrologyProfileAlgorithmVersionEnum.unknownDefaultOpenApi ||
      value.derivedProfileCode ==
          AstrologyProfileDerivedProfileCodeEnum.unknownDefaultOpenApi) {
    throw const LoadFailure(LoadPhase.terminalFailure);
  }
  final birthDate = ProfileDate(
    value.birthDate.year,
    value.birthDate.month,
    value.birthDate.day,
  );
  birthDate.toUtc();
  return SavedAstrologyProfile(
    birthDate: birthDate,
    serverDerivedProfile: value.derivedProfileCode.value,
    algorithmVersion: value.algorithmVersion.value,
    version: value.version,
  );
}

onboarding.InvestmentGoal _investmentGoal(String value) => switch (value) {
  'calm_fund' => onboarding.InvestmentGoal.calmFund,
  'long_term_growth' => onboarding.InvestmentGoal.longTermGrowth,
  'income' => onboarding.InvestmentGoal.income,
  'exploration' => onboarding.InvestmentGoal.exploration,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

onboarding.InvestmentHorizon _investmentHorizon(String value) =>
    switch (value) {
      'short' => onboarding.InvestmentHorizon.short,
      'medium' => onboarding.InvestmentHorizon.medium,
      'long' => onboarding.InvestmentHorizon.long,
      _ => throw const LoadFailure(LoadPhase.terminalFailure),
    };

onboarding.RiskComfort _riskComfort(String value) => switch (value) {
  'low' => onboarding.RiskComfort.low,
  'moderate' => onboarding.RiskComfort.moderate,
  'high' => onboarding.RiskComfort.high,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

ProfileConsentDecision _consentDecision(String value) => switch (value) {
  'accepted' => ProfileConsentDecision.accepted,
  'declined' => ProfileConsentDecision.declined,
  'withdrawn' => ProfileConsentDecision.withdrawn,
  _ => throw const LoadFailure(LoadPhase.terminalFailure),
};

UpdatePreferencesRequestRitualModeEnum? _requestRitualMode(
  ProfileRitualMode? value,
) => switch (value) {
  ProfileRitualMode.tarot => UpdatePreferencesRequestRitualModeEnum.tarot,
  ProfileRitualMode.astrology =>
    UpdatePreferencesRequestRitualModeEnum.astrology,
  null => null,
};

UpdatePreferencesRequestThemeModeEnum? _requestTheme(ProfileTheme? value) =>
    switch (value) {
      ProfileTheme.system => UpdatePreferencesRequestThemeModeEnum.system,
      ProfileTheme.light => UpdatePreferencesRequestThemeModeEnum.light,
      ProfileTheme.dark => UpdatePreferencesRequestThemeModeEnum.dark,
      null => null,
    };

UpdateInvestorProfileRequestGoalTypeEnum _requestGoal(
  onboarding.InvestmentGoal value,
) => switch (value) {
  onboarding.InvestmentGoal.calmFund =>
    UpdateInvestorProfileRequestGoalTypeEnum.calmFund,
  onboarding.InvestmentGoal.longTermGrowth =>
    UpdateInvestorProfileRequestGoalTypeEnum.longTermGrowth,
  onboarding.InvestmentGoal.income =>
    UpdateInvestorProfileRequestGoalTypeEnum.income,
  onboarding.InvestmentGoal.exploration =>
    UpdateInvestorProfileRequestGoalTypeEnum.exploration,
};

UpdateInvestorProfileRequestRiskComfortEnum _requestRisk(
  onboarding.RiskComfort value,
) => switch (value) {
  onboarding.RiskComfort.low => UpdateInvestorProfileRequestRiskComfortEnum.low,
  onboarding.RiskComfort.moderate =>
    UpdateInvestorProfileRequestRiskComfortEnum.moderate,
  onboarding.RiskComfort.high =>
    UpdateInvestorProfileRequestRiskComfortEnum.high,
};

UpdateInvestorProfileRequestTimeHorizonEnum _requestHorizon(
  onboarding.InvestmentHorizon value,
) => switch (value) {
  onboarding.InvestmentHorizon.short =>
    UpdateInvestorProfileRequestTimeHorizonEnum.short,
  onboarding.InvestmentHorizon.medium =>
    UpdateInvestorProfileRequestTimeHorizonEnum.medium,
  onboarding.InvestmentHorizon.long =>
    UpdateInvestorProfileRequestTimeHorizonEnum.long,
};
