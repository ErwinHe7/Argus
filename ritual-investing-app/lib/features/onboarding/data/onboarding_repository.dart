import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ritual_investing_api_client/ritual_investing_api_client.dart';

import '../../../core/api/date_only_request_interceptor.dart';
import '../../../core/bootstrap/generated_member_bootstrap_mapper.dart';
import '../../../core/bootstrap/member_bootstrap.dart';
import '../../brokerage_connection/domain/model.dart';
import '../domain/onboarding_draft.dart';

enum OnboardingFailureKind {
  conflict,
  retryable,
  forbidden,
  validation,
  throttled,
  terminal,
}

class OnboardingFinalizationException implements Exception {
  const OnboardingFinalizationException(this.kind);

  final OnboardingFailureKind kind;
}

@immutable
class OnboardingFinalizationCommand {
  const OnboardingFinalizationCommand._({
    required this.payload,
    required this.canonicalPayloadHash,
  }) : idempotencyKey = canonicalPayloadHash;

  final Map<String, Object?> payload;
  final String canonicalPayloadHash;
  final String idempotencyKey;

  factory OnboardingFinalizationCommand.fromDraft(
    OnboardingDraft draft, {
    required int expectedOnboardingVersion,
    DateTime Function()? now,
  }) {
    if (expectedOnboardingVersion < 1 ||
        !_isComplete(draft, (now ?? DateTime.now)())) {
      throw ArgumentError(
        'A complete reviewed draft and version are required.',
      );
    }
    final payload = _payload(draft, expectedOnboardingVersion);
    final canonicalPayloadHash = sha256
        .convert(utf8.encode(_canonical(payload)))
        .toString();
    return OnboardingFinalizationCommand._(
      payload: Map.unmodifiable(payload),
      canonicalPayloadHash: canonicalPayloadHash,
    );
  }
}

abstract interface class OnboardingRepository {
  Future<MemberBootstrap> finalize(OnboardingFinalizationCommand command);
}

class GeneratedOnboardingRepository implements OnboardingRepository {
  GeneratedOnboardingRepository(RitualInvestingApiClient client)
    : _api = client.getSessionApi() {
    ensureDateOnlyRequestSerialization(client.dio);
  }

  final SessionApi _api;

  @override
  Future<MemberBootstrap> finalize(
    OnboardingFinalizationCommand command,
  ) async {
    try {
      final response = await _api.finalizeOnboarding(
        idempotencyKey: command.idempotencyKey,
        finalizeOnboardingRequest: FinalizeOnboardingRequest.fromJson(
          _generatedFinalizationPayload(command.payload),
        ),
      );
      final data = response.data?.data;
      if (data == null) {
        throw const OnboardingFinalizationException(
          OnboardingFailureKind.terminal,
        );
      }
      return mapSupabaseSessionBootstrap(
        data.toJson(),
        const BrokerageConnectionSnapshot.disconnected(),
      );
    } on DioException catch (error) {
      throw OnboardingFinalizationException(_failureKind(error));
    }
  }
}

Map<String, dynamic> _generatedFinalizationPayload(
  Map<String, Object?> canonicalPayload,
) {
  final generatedPayload =
      jsonDecode(jsonEncode(canonicalPayload)) as Map<String, dynamic>;
  final astrology = generatedPayload['astrology'] as Map<String, dynamic>;
  final birthDate = astrology['birth_date'];
  if (birthDate is String) {
    astrology['birth_date'] = '${birthDate}T00:00:00.000Z';
  }
  return generatedPayload;
}

Map<String, Object?> _payload(OnboardingDraft draft, int expectedVersion) => {
  'schema_version': 2,
  'expected_onboarding_version': expectedVersion,
  'investing': {
    'experience': _experience(draft.experience!),
    'goal_type': _goal(draft.goal!),
    'time_horizon': draft.horizon!.name,
    'risk_comfort': draft.risk!.name,
    'contribution_rhythm': _contribution(draft.contributionRhythm!),
  },
  'ritual': {
    'familiarity': _familiarity(draft.ritualFamiliarity!),
    'language_preference': _ritualLanguage(draft.ritualLanguage!),
    'interests': draft.ritualInterests.map(_ritualInterest).toList()..sort(),
  },
  'astrology': {
    'enabled': draft.astrologyEnabled!,
    if (draft.astrologyEnabled == true)
      'birth_date': onboardingDateOnly(draft.birthDate!),
  },
  'consents': {
    'terms': const {'policy_version': '2026-08', 'decision': 'accepted'},
    'privacy': const {'policy_version': '2026-08', 'decision': 'accepted'},
    'demo_disclosure': const {
      'policy_version': '2026-08',
      'decision': 'accepted',
    },
    'astrology': {
      'policy_version': '2026-08',
      'decision': draft.astrologyEnabled == true ? 'accepted' : 'declined',
    },
  },
};

bool _isComplete(OnboardingDraft draft, DateTime today) =>
    draft.experience != null &&
    draft.goal != null &&
    draft.horizon != null &&
    draft.risk != null &&
    draft.contributionRhythm != null &&
    draft.ritualLanguage != null &&
    draft.ritualFamiliarity != null &&
    draft.ritualInterests.isNotEmpty &&
    draft.astrologyEnabled != null &&
    ((draft.astrologyEnabled == false && draft.birthDate == null) ||
        (draft.astrologyEnabled == true &&
            draft.birthDate != null &&
            isValidOnboardingBirthDate(draft.birthDate!, today: today))) &&
    draft.termsAccepted &&
    draft.privacyAccepted &&
    draft.demoAccepted;

String _canonical(Object? value) {
  if (value is List) return '[${value.map(_canonical).join(',')}]';
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>.from(
      value.map((key, nested) => MapEntry(key as String, nested)),
    );
    return '{${sorted.entries.map((entry) => '${jsonEncode(entry.key)}:${_canonical(entry.value)}').join(',')}}';
  }
  return jsonEncode(value);
}

String _experience(InvestingExperience value) => switch (value) {
  InvestingExperience.newToInvesting => 'new',
  InvestingExperience.someExperience => 'some_experience',
  InvestingExperience.experienced => 'experienced',
};

String _goal(InvestmentGoal value) => switch (value) {
  InvestmentGoal.calmFund => 'calm_fund',
  InvestmentGoal.longTermGrowth => 'long_term_growth',
  InvestmentGoal.income => 'income',
  InvestmentGoal.exploration => 'exploration',
};

String _contribution(ContributionRhythm value) => switch (value) {
  ContributionRhythm.weekly => 'weekly',
  ContributionRhythm.biweekly => 'biweekly',
  ContributionRhythm.monthly => 'monthly',
  ContributionRhythm.irregular => 'irregular',
  ContributionRhythm.notSure => 'not_sure',
};

String _familiarity(RitualFamiliarity value) => switch (value) {
  RitualFamiliarity.newToRitual => 'new',
  RitualFamiliarity.curious => 'curious',
  RitualFamiliarity.familiar => 'familiar',
  RitualFamiliarity.practiced => 'practiced',
  RitualFamiliarity.preferNotToSay => 'prefer_not_to_say',
};

String _ritualLanguage(RitualLanguage value) => switch (value) {
  RitualLanguage.practical => 'practical',
  RitualLanguage.balanced => 'balanced',
  RitualLanguage.mystical => 'mystical',
  RitualLanguage.preferNotToSay => 'prefer_not_to_say',
};

String _ritualInterest(RitualInterest value) => switch (value) {
  RitualInterest.practicalResearch => 'practical_research',
  RitualInterest.tarot => 'tarot',
  RitualInterest.astrology => 'astrology',
  RitualInterest.moonCycles => 'moon_cycles',
  RitualInterest.reflection => 'reflection',
};

OnboardingFailureKind _failureKind(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return OnboardingFailureKind.retryable;
  }
  final code = _errorCode(error.response?.data);
  if (code != null) {
    return switch (code) {
      'onboarding_version_conflict' ||
      'onboarding_already_complete' ||
      'idempotency_conflict' => OnboardingFailureKind.conflict,
      'service_unavailable' ||
      'temporarily_unavailable' => OnboardingFailureKind.retryable,
      'forbidden' ||
      'insufficient_scope' ||
      'account_inactive' => OnboardingFailureKind.forbidden,
      'rate_limited' || 'throttled' => OnboardingFailureKind.throttled,
      'validation_error' ||
      'invalid_request' => OnboardingFailureKind.validation,
      _ => OnboardingFailureKind.terminal,
    };
  }
  return switch (error.response?.statusCode) {
    403 => OnboardingFailureKind.forbidden,
    409 => OnboardingFailureKind.conflict,
    422 => OnboardingFailureKind.validation,
    429 => OnboardingFailureKind.throttled,
    final status when status != null && status >= 500 =>
      OnboardingFailureKind.retryable,
    _ => OnboardingFailureKind.terminal,
  };
}

String? _errorCode(Object? data) {
  if (data is! Map) return null;
  final envelope = data['error'];
  if (envelope is! Map) return null;
  final code = envelope['code'];
  return code is String ? code : null;
}
